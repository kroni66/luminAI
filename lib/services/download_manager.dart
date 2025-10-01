import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import '../models/download_info.dart';
import '../database_helper.dart';
import 'settings_manager.dart';

class DownloadManager {
  static const Duration progressUpdateInterval = Duration(milliseconds: 500);

  final DatabaseHelper _databaseHelper;
  final SettingsManager _settingsManager;
  final http.Client _httpClient = http.Client();

  // Active downloads
  final Map<String, DownloadInfo> _activeDownloads = {};
  final Map<String, StreamSubscription> _progressSubscriptions = {};
  final Map<String, Isolate> _downloadIsolates = {};

  // Download queue for managing concurrent downloads
  final List<DownloadInfo> _downloadQueue = [];

  // All downloads (including completed ones for UI)
  final List<DownloadInfo> _allDownloads = [];

  // Callbacks
  VoidCallback? onDownloadListChanged;
  VoidCallback? onDownloadProgressChanged;

  DownloadManager(this._databaseHelper, this._settingsManager);

  // Getters
  Map<String, DownloadInfo> get activeDownloads => Map.unmodifiable(_activeDownloads);
  List<DownloadInfo> get downloadQueue => List.unmodifiable(_downloadQueue);
  List<DownloadInfo> get allDownloads => _allDownloads;

  int get maxConcurrentDownloads => _settingsManager.maxConcurrentDownloads;

  Future<void> initialize() async {
    await _loadPersistedDownloads();
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await Permission.storage.request();
    }
  }

  Future<void> _loadPersistedDownloads() async {
    try {
      final downloads = await _databaseHelper.getAllDownloads();
      _allDownloads.clear();

      for (final download in downloads) {
        if (download.status == DownloadStatus.downloading ||
            download.status == DownloadStatus.queued) {
          // Reset incomplete downloads to failed status
          final updatedDownload = download.copyWith(
            status: DownloadStatus.failed,
            errorMessage: 'Download was interrupted',
          );
          await _databaseHelper.updateDownload(updatedDownload);
          _allDownloads.add(updatedDownload);
        } else {
          // Add completed/failed downloads as-is
          _allDownloads.add(download);
        }
      }

      debugPrint('Loaded ${_allDownloads.length} downloads from database');
    } catch (e) {
      debugPrint('Error loading persisted downloads: $e');
    }
  }

  Future<String> _getDefaultDownloadDirectory() async {
    // Use custom directory if set in settings
    if (_settingsManager.defaultDownloadDirectory != null) {
      final customDir = Directory(_settingsManager.defaultDownloadDirectory!);
      if (await customDir.exists()) {
        return customDir.path;
      }
    }

    // Fallback to platform-specific default directories
    if (Platform.isWindows) {
      final directory = await getDownloadsDirectory();
      return directory?.path ?? Directory.current.path;
    } else if (Platform.isAndroid) {
      final directory = Directory('/storage/emulated/0/Download');
      if (await directory.exists()) {
        return directory.path;
      }
      final appDir = await getExternalStorageDirectory();
      return appDir?.path ?? Directory.current.path;
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } else {
      final directory = await getDownloadsDirectory();
      return directory?.path ?? Directory.current.path;
    }
  }

  Future<String> _generateUniqueFilename(String directory, String filename) async {
    final file = File(path.join(directory, filename));
    if (!await file.exists()) {
      return filename;
    }

    final extension = path.extension(filename);
    final nameWithoutExtension = path.basenameWithoutExtension(filename);

    int counter = 1;
    while (true) {
      final newFilename = '$nameWithoutExtension ($counter)$extension';
      final newFile = File(path.join(directory, newFilename));
      if (!await newFile.exists()) {
        return newFilename;
      }
      counter++;
    }
  }

  Future<String> _extractFilenameFromUrl(String url, String? contentDisposition) async {
    // Try to extract filename from Content-Disposition header
    if (contentDisposition != null) {
      final regExp = RegExp('filename[^;=\\n]*=(([\'"]).*?\\2|[^;\\n]*)');
      final filenameMatch = regExp.firstMatch(contentDisposition);
      if (filenameMatch != null) {
        var filename = filenameMatch.group(1)?.replaceAll(RegExp('[\'"]'), '');
        if (filename != null && filename.isNotEmpty) {
          // Decode URL encoding
          filename = Uri.decodeComponent(filename);

          // Handle RFC 2047 encoded filenames (e.g., =?UTF-8?Q?...?=)
          if (filename.startsWith('=?') && filename.endsWith('?=')) {
            filename = _decodeRfc2047(filename);
          }

          // Clean up any remaining invalid characters
          filename = _sanitizeFilename(filename);

          if (filename.isNotEmpty) {
            return filename;
          }
        }
      }
    }

    // Extract from URL path
    final uri = Uri.parse(url);
    final pathname = uri.path;
    if (pathname.isNotEmpty && !pathname.endsWith('/')) {
      return path.basename(pathname);
    }

    // Fallback
    return 'download_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _decodeRfc2047(String encoded) {
    // Basic RFC 2047 decoding for =?charset?encoding?text?= format
    try {
      // Handle the =_UTF-8_Q_..._= format (without the ? separators)
      if (encoded.startsWith('=_') && encoded.endsWith('_=')) {
        final inner = encoded.substring(2, encoded.length - 2); // Remove =_ and _=
        final parts = inner.split('_');
        if (parts.length >= 3) {
          final charset = parts[0];
          final encoding = parts[1];
          final text = parts.sublist(2).join('_'); // Join remaining parts

          if (encoding.toUpperCase() == 'Q') {
            // Quoted-printable decoding
            return _decodeQuotedPrintable(text);
          } else if (encoding.toUpperCase() == 'B') {
            // Base64 decoding - for now just return as-is since we don't have base64 decode
            return text;
          }
        }
      }

      // Handle standard =?charset?encoding?text?= format
      final parts = encoded.split('?');
      if (parts.length >= 4 && parts[0] == '=' && parts[3].endsWith('=')) {
        final charset = parts[1];
        final encoding = parts[2];
        final text = parts[3].substring(0, parts[3].length - 1);

        if (encoding.toUpperCase() == 'Q') {
          // Quoted-printable decoding
          return _decodeQuotedPrintable(text);
        } else if (encoding.toUpperCase() == 'B') {
          // Base64 decoding - for now just return as-is since we don't have base64 decode
          return text;
        }
      }
    } catch (e) {
      debugPrint('Failed to decode RFC 2047: $e');
    }
    return encoded;
  }

  String _decodeQuotedPrintable(String text) {
    // Basic quoted-printable decoding for UTF-8
    try {
      // Handle common escape sequences
      String decoded = text
          .replaceAll('=5F', '_')
          .replaceAll('=2D', '-')
          .replaceAll('=3D', '=')
          .replaceAll('=20', ' ')
          .replaceAll('=0A', '\n')
          .replaceAll('=0D', '\r');

      // Handle UTF-8 byte sequences
      decoded = decoded.replaceAllMapped(RegExp('=([0-9A-F]{2})'), (match) {
        final hex = match.group(1)!;
        final byte = int.parse(hex, radix: 16);
        return String.fromCharCode(byte);
      });

      // Handle multi-byte UTF-8 sequences (like =C4=8D for č)
      decoded = decoded.replaceAllMapped(RegExp('=([0-9A-F]{2})=([0-9A-F]{2})'), (match) {
        final byte1 = int.parse(match.group(1)!, radix: 16);
        final byte2 = int.parse(match.group(2)!, radix: 16);
        try {
          // Try to decode as UTF-8
          final bytes = [byte1, byte2];
          return utf8.decode(bytes);
        } catch (e) {
          // If UTF-8 decoding fails, return the original
          return match.group(0)!;
        }
      });

      return decoded;
    } catch (e) {
      debugPrint('Error decoding quoted printable: $e');
      return text;
    }
  }

  String _sanitizeFilename(String filename) {
    // Remove or replace invalid characters for filenames
    return filename
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> startDownload(String url, {
    String? customFilename,
    String? saveDirectory,
    String? referrer,
  }) async {
    try {
      final directory = saveDirectory ?? await _getDefaultDownloadDirectory();

      // Create download directory if it doesn't exist
      final dir = Directory(directory);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // Get download info from server (try HEAD first, fallback to GET)
      var response = await _httpClient.head(Uri.parse(url));
      if (response.statusCode != 200) {
        // Fallback to GET request if HEAD is not supported
        response = await _httpClient.get(Uri.parse(url));
        if (response.statusCode != 200) {
          throw Exception('Failed to get download info: ${response.statusCode}');
        }
      }

      final contentLength = int.tryParse(response.headers['content-length'] ?? '0') ?? 0;
      final contentDisposition = response.headers['content-disposition'];
      final contentType = response.headers['content-type'];

      // Generate filename
      final urlFilename = await _extractFilenameFromUrl(url, contentDisposition);
      final filename = customFilename ?? await _generateUniqueFilename(directory, urlFilename);
      final savePath = path.join(directory, filename);

      final downloadInfo = DownloadInfo(
        url: url,
        filename: filename,
        savePath: savePath,
        totalBytes: contentLength,
        mimeType: contentType,
        referrer: referrer,
      );

      // Save to database
      await _databaseHelper.insertDownload(downloadInfo);

      // Add to all downloads list
      _allDownloads.insert(0, downloadInfo); // Add at beginning for newest first

  // Add to queue or start immediately
  await _addToQueue(downloadInfo);

    } catch (e) {
      debugPrint('Error starting download: $e');
      // Could show error notification here
    }
  }

  Future<void> _addToQueue(DownloadInfo downloadInfo) async {
    _downloadQueue.add(downloadInfo);
    debugPrint('Download added to queue: ${downloadInfo.filename}');
    debugPrint('Total downloads in queue: ${_downloadQueue.length}');

    // Start download if we have capacity
    if (_activeDownloads.length < maxConcurrentDownloads) {
      await _startNextDownload();
    }

    debugPrint('Calling onDownloadListChanged callback');
    if (onDownloadListChanged != null) {
      debugPrint('  - onDownloadListChanged callback exists, calling it');
      onDownloadListChanged!.call();
    } else {
      debugPrint('  - onDownloadListChanged callback is null!');
    }
  }

  Future<void> _startNextDownload() async {
    if (_downloadQueue.isEmpty || _activeDownloads.length >= maxConcurrentDownloads) {
      return;
    }

    final downloadInfo = _downloadQueue.removeAt(0);
    await _startDownloadInternal(downloadInfo);
  }

  Future<void> _startDownloadInternal(DownloadInfo downloadInfo) async {
    final updatedDownload = downloadInfo.copyWith(
      status: DownloadStatus.downloading,
      startTime: DateTime.now(),
    );

    _activeDownloads[downloadInfo.id] = updatedDownload;

    // Update in all downloads list
    final index = _allDownloads.indexWhere((d) => d.id == downloadInfo.id);
    if (index != -1) {
      _allDownloads[index] = updatedDownload;
    }

    debugPrint('Starting download: ${downloadInfo.filename}');
    onDownloadListChanged?.call();

    try {
      // Create download isolate for background processing
      final receivePort = ReceivePort();
      final isolate = await Isolate.spawn(
        _downloadIsolate,
        _DownloadIsolateData(
          downloadInfo: downloadInfo,
          sendPort: receivePort.sendPort,
        ),
      );

      _downloadIsolates[downloadInfo.id] = isolate;

      // Listen for progress updates
      final subscription = receivePort.listen((message) {
        if (message is _DownloadProgress) {
          _updateDownloadProgress(message);
        } else if (message is _DownloadComplete) {
          _handleDownloadComplete(message);
        } else if (message is _DownloadError) {
          _handleDownloadError(message);
        }
      });

      _progressSubscriptions[downloadInfo.id] = subscription;

    } catch (e) {
      debugPrint('Error starting download isolate: $e');
      await _handleDownloadError(_DownloadError(
        downloadId: downloadInfo.id,
        error: e.toString(),
      ));
    }
  }

  void _updateDownloadProgress(_DownloadProgress progress) {
    final download = _activeDownloads[progress.downloadId];
    if (download != null) {
      final updatedDownload = download.copyWith(
        downloadedBytes: progress.downloadedBytes,
      );

      _activeDownloads[progress.downloadId] = updatedDownload;

      // Update in all downloads list
      final index = _allDownloads.indexWhere((d) => d.id == progress.downloadId);
      if (index != -1) {
        _allDownloads[index] = updatedDownload;
      }

      // Update in database periodically
      if (progress.downloadedBytes % (1024 * 100) == 0) { // Every 100KB
        _databaseHelper.updateDownload(updatedDownload);
      }

      if (onDownloadProgressChanged != null) {
        debugPrint('Calling onDownloadProgressChanged for ${updatedDownload.filename}');
        onDownloadProgressChanged!.call();
      } else {
        debugPrint('onDownloadProgressChanged callback is null!');
      }
    }
  }

  Future<void> _handleDownloadComplete(_DownloadComplete complete) async {
    final download = _activeDownloads[complete.downloadId];
    if (download != null) {
      final completedDownload = download.copyWith(
        status: DownloadStatus.completed,
        downloadedBytes: download.totalBytes,
        endTime: DateTime.now(),
      );

      debugPrint('Download completed in UI: ${completedDownload.filename}');
      _activeDownloads.remove(complete.downloadId);
      await _databaseHelper.updateDownload(completedDownload);

      // Update in all downloads list
      final index = _allDownloads.indexWhere((d) => d.id == complete.downloadId);
      if (index != -1) {
        _allDownloads[index] = completedDownload;
      }

      _progressSubscriptions[complete.downloadId]?.cancel();
      _progressSubscriptions.remove(complete.downloadId);
      _downloadIsolates[complete.downloadId]?.kill();
      _downloadIsolates.remove(complete.downloadId);
    }

    // Start next download
    await _startNextDownload();

    if (onDownloadListChanged != null) {
      debugPrint('Calling onDownloadListChanged after completion');
      onDownloadListChanged!.call();
    } else {
      debugPrint('onDownloadListChanged callback is null after completion!');
    }
  }

  Future<void> _handleDownloadError(_DownloadError error) async {
    final download = _activeDownloads[error.downloadId];
    if (download != null) {
      final failedDownload = download.copyWith(
        status: DownloadStatus.failed,
        errorMessage: error.error,
        endTime: DateTime.now(),
      );

      _activeDownloads.remove(error.downloadId);
      await _databaseHelper.updateDownload(failedDownload);

      // Update in all downloads list
      final index = _allDownloads.indexWhere((d) => d.id == error.downloadId);
      if (index != -1) {
        _allDownloads[index] = failedDownload;
      }

      _progressSubscriptions[error.downloadId]?.cancel();
      _progressSubscriptions.remove(error.downloadId);
      _downloadIsolates[error.downloadId]?.kill();
      _downloadIsolates.remove(error.downloadId);
    }

    // Start next download
    await _startNextDownload();
    onDownloadListChanged?.call();
  }

  Future<void> pauseDownload(String downloadId) async {
    final download = _activeDownloads[downloadId];
    if (download != null && download.status == DownloadStatus.downloading) {
      // Kill the isolate to pause download
      _downloadIsolates[downloadId]?.kill();
      _downloadIsolates.remove(downloadId);
      _progressSubscriptions[downloadId]?.cancel();
      _progressSubscriptions.remove(downloadId);

      final pausedDownload = download.copyWith(
        status: DownloadStatus.paused,
      );

      _activeDownloads[downloadId] = pausedDownload;
      await _databaseHelper.updateDownload(pausedDownload);

      // Move to queue for later resumption
      _downloadQueue.insert(0, pausedDownload);
      _activeDownloads.remove(downloadId);

      onDownloadListChanged?.call();
    }
  }

  Future<void> resumeDownload(String downloadId) async {
    // Find download in queue
    final index = _downloadQueue.indexWhere((d) => d.id == downloadId);
    if (index != -1) {
      final download = _downloadQueue[index];
      _downloadQueue.removeAt(index);

      if (_activeDownloads.length < maxConcurrentDownloads) {
        await _startDownloadInternal(download);
      } else {
        _downloadQueue.insert(0, download);
      }
    }
  }

  Future<void> cancelDownload(String downloadId) async {
    final download = _activeDownloads[downloadId] ??
        (_downloadQueue.where((d) => d.id == downloadId).isNotEmpty
            ? _downloadQueue.firstWhere((d) => d.id == downloadId)
            : null);

    if (download != null) {
      // Kill isolate if running
      _downloadIsolates[downloadId]?.kill();
      _downloadIsolates.remove(downloadId);
      _progressSubscriptions[downloadId]?.cancel();
      _progressSubscriptions.remove(downloadId);

      // Remove from collections
      _activeDownloads.remove(downloadId);
      _downloadQueue.removeWhere((d) => d.id == downloadId);

      // Update database
      final cancelledDownload = download.copyWith(
        status: DownloadStatus.cancelled,
        endTime: DateTime.now(),
      );
      await _databaseHelper.updateDownload(cancelledDownload);

      // Delete partial file if it exists
      final file = File(download.savePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Start next download
      await _startNextDownload();
      onDownloadListChanged?.call();
    }
  }

  Future<void> retryDownload(String downloadId) async {
    try {
      final download = await _databaseHelper.getDownload(downloadId);
      if (download != null && download.status == DownloadStatus.failed) {
        final retryDownload = download.copyWith(
          status: DownloadStatus.queued,
          errorMessage: null,
          downloadedBytes: 0,
          startTime: DateTime.now(),
          endTime: null,
        );

        await _databaseHelper.updateDownload(retryDownload);
        await _addToQueue(retryDownload);
      }
    } catch (e) {
      debugPrint('Error retrying download: $e');
    }
  }

  Future<void> clearCompletedDownloads() async {
    await _databaseHelper.clearCompletedDownloads();
    _allDownloads.removeWhere((download) => download.status == DownloadStatus.completed);
    onDownloadListChanged?.call();
  }

  void dispose() {
    _httpClient.close();

    // Cancel all subscriptions and kill isolates
    for (final subscription in _progressSubscriptions.values) {
      subscription.cancel();
    }
    _progressSubscriptions.clear();

    for (final isolate in _downloadIsolates.values) {
      isolate.kill();
    }
    _downloadIsolates.clear();
  }
}

// Isolate communication classes
class _DownloadIsolateData {
  final DownloadInfo downloadInfo;
  final SendPort sendPort;

  _DownloadIsolateData({
    required this.downloadInfo,
    required this.sendPort,
  });
}

class _DownloadProgress {
  final String downloadId;
  final int downloadedBytes;

  _DownloadProgress({
    required this.downloadId,
    required this.downloadedBytes,
  });
}

class _DownloadComplete {
  final String downloadId;

  _DownloadComplete({required this.downloadId});
}

class _DownloadError {
  final String downloadId;
  final String error;

  _DownloadError({
    required this.downloadId,
    required this.error,
  });
}

// Download isolate function
void _downloadIsolate(_DownloadIsolateData data) async {
  final downloadInfo = data.downloadInfo;
  final sendPort = data.sendPort;

  debugPrint('Download isolate started for: ${downloadInfo.filename}');
  debugPrint('Download URL: ${downloadInfo.url}');
  debugPrint('Save path: ${downloadInfo.savePath}');

  try {
    final client = http.Client();
    final request = http.Request('GET', Uri.parse(downloadInfo.url));

    // Add referrer header if provided
    if (downloadInfo.referrer != null) {
      request.headers['Referer'] = downloadInfo.referrer!;
    }

    debugPrint('Sending GET request to: ${downloadInfo.url}');
    final response = await client.send(request);

    debugPrint('Response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.reasonPhrase}');
    }

    debugPrint('Creating file: ${downloadInfo.savePath}');
    final file = File(downloadInfo.savePath);
    final sink = file.openWrite();
    int downloaded = 0;

    debugPrint('Starting download loop for: ${downloadInfo.filename}');
    await for (final chunk in response.stream) {
      sink.add(chunk);
      downloaded += chunk.length;

      // Send progress update more frequently for better UI feedback
      if (downloaded % (1024) == 0 || downloaded < 10240) { // Every 1KB or for first 10KB
        debugPrint('Download progress: ${downloadInfo.filename} - ${downloaded} bytes');
        sendPort.send(_DownloadProgress(
          downloadId: downloadInfo.id,
          downloadedBytes: downloaded,
        ));
      }
    }

    await sink.close();
    client.close();

    debugPrint('Download completed: ${downloadInfo.filename}');

    // Verify the file was actually downloaded
    final downloadedFile = File(downloadInfo.savePath);
    final exists = await downloadedFile.exists();
    final length = exists ? await downloadedFile.length() : 0;
    debugPrint('File verification - exists: $exists, size: $length bytes');

    // Send completion message
    sendPort.send(_DownloadComplete(downloadId: downloadInfo.id));

  } catch (e) {
    debugPrint('Download error for ${downloadInfo.filename}: $e');
    // Send error message
    sendPort.send(_DownloadError(
      downloadId: downloadInfo.id,
      error: e.toString(),
    ));
  }
}

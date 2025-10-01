import 'package:uuid/uuid.dart';

enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled
}

class DownloadInfo {
  final String id;
  final String url;
  final String filename;
  final String savePath;
  final int totalBytes;
  int downloadedBytes;
  final DateTime startTime;
  DateTime? endTime;
  DownloadStatus status;
  String? errorMessage;
  final String? mimeType;
  final String? referrer;

  DownloadInfo({
    String? id,
    required this.url,
    required this.filename,
    required this.savePath,
    required this.totalBytes,
    this.downloadedBytes = 0,
    DateTime? startTime,
    this.endTime,
    this.status = DownloadStatus.queued,
    this.errorMessage,
    this.mimeType,
    this.referrer,
  }) :
    id = id ?? const Uuid().v4(),
    startTime = startTime ?? DateTime.now();

  // Calculate download progress as percentage
  double get progressPercentage {
    if (totalBytes <= 0) return 0.0;
    return (downloadedBytes / totalBytes) * 100.0;
  }

  // Calculate download speed (bytes per second)
  double get downloadSpeed {
    if (status != DownloadStatus.downloading || downloadedBytes == 0) return 0.0;

    final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
    if (elapsedSeconds <= 0) return 0.0;

    return downloadedBytes / elapsedSeconds;
  }

  // Calculate estimated time remaining
  Duration get estimatedTimeRemaining {
    final speed = downloadSpeed;
    if (speed <= 0 || totalBytes <= downloadedBytes) {
      return Duration.zero;
    }

    final remainingBytes = totalBytes - downloadedBytes;
    final secondsRemaining = remainingBytes / speed;

    return Duration(seconds: secondsRemaining.toInt());
  }

  // Format file size for display
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // Convert DownloadInfo to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'filename': filename,
      'save_path': savePath,
      'total_bytes': totalBytes,
      'downloaded_bytes': downloadedBytes,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'status': status.index,
      'error_message': errorMessage,
      'mime_type': mimeType,
      'referrer': referrer,
    };
  }

  // Create DownloadInfo from database Map
  static DownloadInfo fromMap(Map<String, dynamic> map) {
    return DownloadInfo(
      id: map['id'] as String,
      url: map['url'] as String,
      filename: map['filename'] as String,
      savePath: map['save_path'] as String,
      totalBytes: map['total_bytes'] as int,
      downloadedBytes: map['downloaded_bytes'] as int,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time'] as String) : null,
      status: DownloadStatus.values[map['status'] as int],
      errorMessage: map['error_message'] as String?,
      mimeType: map['mime_type'] as String?,
      referrer: map['referrer'] as String?,
    );
  }

  // Create a copy of this DownloadInfo with updated values
  DownloadInfo copyWith({
    String? url,
    String? filename,
    String? savePath,
    int? totalBytes,
    int? downloadedBytes,
    DateTime? startTime,
    DateTime? endTime,
    DownloadStatus? status,
    String? errorMessage,
    String? mimeType,
    String? referrer,
  }) {
    return DownloadInfo(
      id: id,
      url: url ?? this.url,
      filename: filename ?? this.filename,
      savePath: savePath ?? this.savePath,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      mimeType: mimeType ?? this.mimeType,
      referrer: referrer ?? this.referrer,
    );
  }
}

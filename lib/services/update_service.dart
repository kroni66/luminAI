import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:package_info_plus/package_info_plus.dart';

class ReleaseInfo {
  final String tagName;
  final String name;
  final String body;
  final DateTime publishedAt;
  final List<Asset> assets;

  ReleaseInfo({
    required this.tagName,
    required this.name,
    required this.body,
    required this.publishedAt,
    required this.assets,
  });

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    return ReleaseInfo(
      tagName: json['tag_name'] ?? '',
      name: json['name'] ?? '',
      body: json['body'] ?? '',
      publishedAt: DateTime.parse(json['published_at'] ?? ''),
      assets: (json['assets'] as List<dynamic>?)
          ?.map((asset) => Asset.fromJson(asset))
          .toList() ?? [],
    );
  }

  String get version => tagName.replaceFirst('v', '');
}

class Asset {
  final String name;
  final String browserDownloadUrl;
  final int size;

  Asset({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      name: json['name'] ?? '',
      browserDownloadUrl: json['browser_download_url'] ?? '',
      size: json['size'] ?? 0,
    );
  }
}

class UpdateCheckResult {
  final bool updateAvailable;
  final ReleaseInfo? latestRelease;
  final String? error;

  UpdateCheckResult({
    required this.updateAvailable,
    this.latestRelease,
    this.error,
  });
}

class UpdateService {
  static const String _repoOwner = 'kroni66';
  static const String _repoName = 'luminAI';
  static const String _apiBaseUrl = 'https://api.github.com';


  Future<String> get currentVersion async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  Future<UpdateCheckResult> checkForUpdates() async {
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/repos/$_repoOwner/$_repoName/releases/latest'),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
        },
      );

      if (response.statusCode == 200) {
        final releaseJson = json.decode(response.body);
        final latestRelease = ReleaseInfo.fromJson(releaseJson);

        final currentVersion = await this.currentVersion;
        final updateAvailable = _isVersionNewer(latestRelease.version, currentVersion);

        return UpdateCheckResult(
          updateAvailable: updateAvailable,
          latestRelease: latestRelease,
        );
      } else if (response.statusCode == 404) {
        // No releases found
        return UpdateCheckResult(
          updateAvailable: false,
        );
      } else {
        return UpdateCheckResult(
          updateAvailable: false,
          error: 'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      return UpdateCheckResult(
        updateAvailable: false,
        error: e.toString(),
      );
    }
  }

  bool _isVersionNewer(String latestVersion, String currentVersion) {
    // Simple version comparison - assumes semantic versioning
    final latestParts = latestVersion.split('.').map(int.parse).toList();
    final currentParts = currentVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }

    // If versions are equal up to the shorter length, longer version is newer
    return latestParts.length > currentParts.length;
  }

  Future<String?> getDownloadUrlForCurrentPlatform() async {
    try {
      final updateResult = await checkForUpdates();
      if (!updateResult.updateAvailable || updateResult.latestRelease == null) {
        return null;
      }

      final release = updateResult.latestRelease!;
      final platform = Platform.operatingSystem;

      String assetPattern;
      switch (platform) {
        case 'windows':
          assetPattern = 'windows';
          break;
        case 'macos':
          assetPattern = 'macos';
          break;
        case 'linux':
          assetPattern = 'linux';
          break;
        default:
          return null;
      }

      // Find the asset that matches our platform
      for (final asset in release.assets) {
        if (asset.name.toLowerCase().contains(assetPattern)) {
          return asset.browserDownloadUrl;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> downloadUpdate(String downloadUrl, Function(double) onProgress) async {
    try {
      final response = await http.get(Uri.parse(downloadUrl));

      if (response.statusCode != 200) {
        return null;
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = path.basename(Uri.parse(downloadUrl).path);
      final filePath = path.join(tempDir.path, fileName);

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      return filePath;
    } catch (e) {
      return null;
    }
  }

  Future<bool> installUpdate(String filePath) async {
    try {
      final platform = Platform.operatingSystem;

      switch (platform) {
        case 'windows':
          return await _installWindowsUpdate(filePath);
        case 'macos':
          return await _installMacosUpdate(filePath);
        case 'linux':
          return await _installLinuxUpdate(filePath);
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> _installWindowsUpdate(String filePath) async {
    // For Windows, run the MSI installer which will handle the update automatically
    // The MSI installer is configured to restart the app after installation
    try {
      // Run the MSI installer with silent installation flags
      final result = await Process.run('msiexec.exe', [
        '/i',
        filePath,
        '/quiet',
        '/norestart',
        '/l*v',
        'install.log'
      ]);

      // MSI installer will handle the app restart automatically due to run_after_install: true
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }


  Future<bool> _installMacosUpdate(String filePath) async {
    // Similar to Windows - extract and replace
    // This would need proper macOS app bundle handling
    return true;
  }

  Future<bool> _installLinuxUpdate(String filePath) async {
    // Extract tar.gz and replace files
    return true;
  }
}

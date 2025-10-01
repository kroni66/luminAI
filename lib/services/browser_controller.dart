import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';


abstract class BrowserController {
  Future<void> initialize();
  Future<void> loadUrl(String url);
  Future<void> goBack();
  Future<void> goForward();
  Future<void> reload();
  Future<String?> executeScript(String script);
  Future<bool> canGoBack();
  Future<bool> canGoForward();
  Stream<String> get urlStream;
  Stream<String> get titleStream;
  bool get isInitialized;
  void Function(String url)? onDownloadRequested;
  void dispose();

  // Factory method to create platform-specific controller
  static BrowserController create() {
    if (kIsWeb) {
      return WebBrowserController();
    } else if (Platform.isWindows) {
      return WindowsBrowserController();
    } else if (Platform.isAndroid || Platform.isIOS) {
      return MobileBrowserController();
    } else {
      return DesktopBrowserController();
    }
  }

  // Check if URL should trigger a download
  static bool shouldDownloadUrl(String url) {
    final uri = Uri.parse(url);
    final path = uri.path.toLowerCase();

    // Common downloadable file extensions
    final downloadableExtensions = {
      '.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx',
      '.txt', '.rtf', '.zip', '.rar', '.7z', '.tar', '.gz',
      '.exe', '.msi', '.dmg', '.pkg', '.deb', '.rpm',
      '.mp3', '.mp4', '.avi', '.mkv', '.mov', '.wmv',
      '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.svg',
      '.iso', '.torrent'
    };

    return downloadableExtensions.any((ext) => path.endsWith(ext));
  }
}

class WindowsBrowserController implements BrowserController {
  WebviewController? _controller;
  final StreamController<String> _urlController = StreamController<String>.broadcast();
  final StreamController<String> _titleController = StreamController<String>.broadcast();

  // Navigation history tracking
  final List<String> _history = [];
  int _currentIndex = -1;

  @override
  void Function(String url)? onDownloadRequested;

  @override
  Future<void> initialize() async {
    // Ensure window is ready before initializing webview
    if (Platform.isWindows) {
      // Wait for bitsdojo window to be ready
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _controller = WebviewController();
    await _controller!.initialize();

    // Set popup window policy to open links in the same window instead of new windows
    await _controller!.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);

    // Listen to URL changes and intercept downloads
    _controller!.url.listen((url) {
      // Check if this URL should trigger a download
      if (BrowserController.shouldDownloadUrl(url)) {
        debugPrint('Detected download URL via navigation: $url');
        onDownloadRequested?.call(url);
        // Don't navigate back - let the download proceed
        // The webview won't actually download the file since our manager handles it
      } else {
        // Track navigation history
        _addToHistory(url);
        _urlController.add(url);
      }
    });

    // Listen to title changes
    _controller!.title.listen((title) {
      _titleController.add(title);
    });
  }

  // Helper method to add URL to navigation history
  void _addToHistory(String url) {
    // Don't add duplicate consecutive URLs
    if (_currentIndex >= 0 && _currentIndex < _history.length && _history[_currentIndex] == url) {
      return;
    }

    // If we're not at the end of history, remove everything after current position
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }

    // Add new URL to history
    _history.add(url);
    _currentIndex = _history.length - 1;
  }

  @override
  Future<void> loadUrl(String url) async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.loadUrl(url);
    }
  }

  @override
  Future<void> goBack() async {
    if (await canGoBack()) {
      _currentIndex--;
      final url = _history[_currentIndex];
      await _controller!.loadUrl(url);
    }
  }

  @override
  Future<void> goForward() async {
    if (await canGoForward()) {
      _currentIndex++;
      final url = _history[_currentIndex];
      await _controller!.loadUrl(url);
    }
  }

  @override
  Future<void> reload() async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.reload();
    }
  }

  @override
  Future<String?> executeScript(String script) async {
    if (_controller != null && _controller!.value.isInitialized) {
      return await _controller!.executeScript(script);
    }
    return null;
  }

  @override
  Future<bool> canGoBack() async {
    return _currentIndex > 0;
  }

  @override
  Future<bool> canGoForward() async {
    return _currentIndex < _history.length - 1;
  }

  @override
  Stream<String> get urlStream => _urlController.stream;

  @override
  Stream<String> get titleStream => _titleController.stream;

  @override
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  @override
  void dispose() {
    _controller?.dispose();
    _urlController.close();
    _titleController.close();
  }

  WebviewController? get controller => _controller;
}

class MobileBrowserController implements BrowserController {
  dynamic _controller; // InAppWebViewController (commented out)
  final StreamController<String> _urlController = StreamController<String>.broadcast();
  final StreamController<String> _titleController = StreamController<String>.broadcast();

  @override
  void Function(String url)? onDownloadRequested;

  @override
  Future<void> initialize() async {
    // Mobile webview temporarily removed - flutter_inappwebview commented out
    debugPrint('Mobile webview not available - temporarily removed flutter_inappwebview');
  }

  @override
  Future<void> loadUrl(String url) async {
    // Mobile: flutter_inappwebview temporarily removed
    debugPrint('Mobile webview not available - temporarily removed flutter_inappwebview');
  }

  @override
  Future<void> goBack() async {
    // Mobile: flutter_inappwebview temporarily removed
    debugPrint('Mobile navigation not available - temporarily removed flutter_inappwebview');
  }

  @override
  Future<void> goForward() async {
    // Mobile: flutter_inappwebview temporarily removed
    debugPrint('Mobile navigation not available - temporarily removed flutter_inappwebview');
  }

  @override
  Future<void> reload() async {
    // Mobile: flutter_inappwebview temporarily removed
    debugPrint('Mobile refresh not available - temporarily removed flutter_inappwebview');
  }

  @override
  Future<String?> executeScript(String script) async {
    return null;
  }

  @override
  Future<bool> canGoBack() async {
    if (_controller != null) {
      return await _controller!.canGoBack();
    }
    return false;
  }

  @override
  Future<bool> canGoForward() async {
    if (_controller != null) {
      return await _controller!.canGoForward();
    }
    return false;
  }

  @override
  Stream<String> get urlStream => _urlController.stream;

  @override
  Stream<String> get titleStream => _titleController.stream;

  @override
  bool get isInitialized => false; // Mobile webview not available

  @override
  void dispose() {
    _urlController.close();
    _titleController.close();
  }
}

class DesktopBrowserController implements BrowserController {
  dynamic _controller;
  final StreamController<String> _urlController = StreamController<String>.broadcast();
  final StreamController<String> _titleController = StreamController<String>.broadcast();

  @override
  void Function(String url)? onDownloadRequested;

  @override
  Future<void> initialize() async {
    // Desktop webview not implemented
  }

  @override
  Future<void> loadUrl(String url) async {
    if (_controller != null) {
      await _controller.launch(url); // Note: This may reopen window
    }
  }

  @override
  Future<void> goBack() async {
    // Not supported for basic desktop implementation
  }

  @override
  Future<void> goForward() async {
    // Not supported for basic desktop implementation
  }

  @override
  Future<void> reload() async {
    // Reload current URL if available
    // Implementation would need current URL tracking
  }

  @override
  Future<String?> executeScript(String script) async {
    return null;
  }

  @override
  Future<bool> canGoBack() async {
    return false;
  }

  @override
  Future<bool> canGoForward() async {
    return false;
  }

  @override
  Stream<String> get urlStream => _urlController.stream;

  @override
  Stream<String> get titleStream => _titleController.stream;

  @override
  bool get isInitialized => false;

  @override
  void dispose() {
    _urlController.close();
    _titleController.close();
  }
}

class WebBrowserController implements BrowserController {
  final StreamController<String> _urlController = StreamController<String>.broadcast();
  final StreamController<String> _titleController = StreamController<String>.broadcast();

  @override
  void Function(String url)? onDownloadRequested;

  @override
  Future<void> initialize() async {
    // No webview for web platform
  }

  @override
  Future<void> loadUrl(String url) async {
    debugPrint('Open $url in external browser');
  }

  @override
  Future<void> goBack() async {
    // Not applicable for web
  }

  @override
  Future<void> goForward() async {
    // Not applicable for web
  }

  @override
  Future<void> reload() async {
    // Not applicable for web
  }

  @override
  Future<String?> executeScript(String script) async {
    return null;
  }

  @override
  Future<bool> canGoBack() async {
    return false;
  }

  @override
  Future<bool> canGoForward() async {
    return false;
  }

  @override
  Stream<String> get urlStream => _urlController.stream;

  @override
  Stream<String> get titleStream => _titleController.stream;

  @override
  bool get isInitialized => false;

  @override
  void dispose() {
    _urlController.close();
    _titleController.close();
  }
}

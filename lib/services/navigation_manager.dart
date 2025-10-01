import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'browser_controller.dart';

class NavigationManager {
  bool _canGoBack = false;
  bool _canGoForward = false;
  String _currentUrl = '';
  final String _homepageUrl = 'about:blank';

  // Platform-specific controllers (to be injected)
  dynamic _mobileController;
  dynamic _desktopController;
  dynamic _windowsController;
  BrowserController? _browserController;

  // Callbacks
  VoidCallback? onNavigationStateChanged;

  // Getters
  bool get canGoBack => _canGoBack;
  bool get canGoForward => _canGoForward;
  String get currentUrl => _currentUrl;
  String get homepageUrl => _homepageUrl;

  // Setters for controllers
  set mobileController(dynamic controller) => _mobileController = controller;
  set desktopController(dynamic controller) => _desktopController = controller;
  set windowsController(dynamic controller) => _windowsController = controller;
  set browserController(BrowserController? controller) => _browserController = controller;

  void updateCurrentUrl(String url) {
    _currentUrl = url;
  }

  Future<void> updateNavigationState() async {
    bool canGoBack = false;
    bool canGoForward = false;

    if (kIsWeb) {
      // No navigation for web placeholder
    } else if (Platform.isAndroid || Platform.isIOS) {
      if (_mobileController != null) {
        canGoBack = await _mobileController!.canGoBack();
        canGoForward = await _mobileController!.canGoForward();
      }
    } else if (Platform.isWindows) {
      if (_browserController != null) {
        canGoBack = await _browserController!.canGoBack();
        canGoForward = await _browserController!.canGoForward();
      } else {
        canGoBack = false;
        canGoForward = false;
      }
    } else {
      // Other Desktop: Basic package, disable navigation buttons
      canGoBack = false;
      canGoForward = false;
    }

    _canGoBack = canGoBack;
    _canGoForward = canGoForward;
    onNavigationStateChanged?.call();
  }

  Future<void> goBack() async {
    await _performGoBack();
    await updateNavigationState();
  }

  Future<void> goForward() async {
    await _performGoForward();
    await updateNavigationState();
  }

  Future<void> goHome() async {
    await navigateToUrl(_homepageUrl);
  }

  Future<void> refresh() async {
    if (kIsWeb) return;

    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: flutter_inappwebview temporarily removed
      // if (_mobileController != null) {
      //   await _mobileController!.reload();
      // }
      debugPrint('Mobile refresh not available - temporarily removed flutter_inappwebview');
    } else if (Platform.isWindows) {
      if (_windowsController != null && _windowsController!.value.isInitialized) {
        await _windowsController!.reload();
      }
    } else {
      // Other Desktop: Reload current URL
      if (_currentUrl.isNotEmpty && _currentUrl != 'about:blank') {
        await navigateToUrl(_currentUrl);
      }
    }
  }

  Future<void> navigateToUrl(String url) async {
    if (url.isEmpty) return;

    var uriString = url.startsWith('http') ? url : 'https://$url';

    if (kIsWeb) {
      debugPrint('Open $uriString in external browser');
      return;
    } else if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: flutter_inappwebview temporarily removed
      debugPrint('Mobile webview not available - temporarily removed flutter_inappwebview');
    } else if (Platform.isWindows) {
      if (_windowsController != null && _windowsController!.value.isInitialized) {
        await _windowsController!.loadUrl(uriString);
      }
    } else {
      // Other Desktop: Use reload or launch for new URL (basic API)
      if (_desktopController != null) {
        await _desktopController.launch(uriString); // Note: This may reopen window
      }
    }

    _currentUrl = uriString;
    await updateNavigationState();
  }

  Future<void> _performGoBack() async {
    if (kIsWeb) return;

    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: flutter_inappwebview temporarily removed
      // if (_mobileController != null) {
      //   await _mobileController!.goBack();
      // }
      debugPrint('Mobile navigation not available - temporarily removed flutter_inappwebview');
    } else if (Platform.isWindows) {
      if (_browserController != null) {
        await _browserController!.goBack();
      } else if (_windowsController != null && _windowsController!.value.isInitialized) {
        await _windowsController!.goBack();
      }
    } else {
      // Other Desktop: Not supported
    }
  }

  Future<void> _performGoForward() async {
    if (kIsWeb) return;

    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: flutter_inappwebview temporarily removed
      // if (_mobileController != null) {
      //   await _mobileController!.goForward();
      // }
      debugPrint('Mobile navigation not available - temporarily removed flutter_inappwebview');
    } else if (Platform.isWindows) {
      if (_browserController != null) {
        await _browserController!.goForward();
      } else if (_windowsController != null && _windowsController!.value.isInitialized) {
        await _windowsController!.goForward();
      }
    } else {
      // Other Desktop: Not supported
    }
  }
}

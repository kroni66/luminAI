import 'dart:async';
import 'package:webview_windows/webview_windows.dart';
import '../services/settings_manager.dart';
import '../widgets/web_view_constants.dart';

/// Manages JavaScript injection and execution for WebView
class WebViewJavaScriptManager {
  final WebviewController? controller;
  final SettingsManager? settingsManager;

  WebViewJavaScriptManager({
    required this.controller,
    this.settingsManager,
  });

  /// Initializes JavaScript tracking for the webview
  Future<void> initializeJavaScriptTracking() async {
    if (controller == null) return;

    try {
      // Inject smooth scrolling JavaScript if settings manager is available
      if (settingsManager != null) {
        final smoothScrollScript = settingsManager!.getWebViewSmoothScrollingJavaScript();
        if (smoothScrollScript.isNotEmpty) {
          await controller!.executeScript(smoothScrollScript);
        }

        // Inject mouse sensitivity JavaScript
        final mouseSensitivityScript = settingsManager!.getWebViewMouseSensitivityJavaScript();
        if (mouseSensitivityScript.isNotEmpty) {
          await controller!.executeScript(mouseSensitivityScript);
        }
      }

      // Inject link detection script
      await controller!.executeScript(WebViewConstants.linkDetectionScript);

    } catch (e) {
      // Log error but don't throw - JavaScript failures shouldn't break the app
      print('Error initializing JavaScript tracking: $e');
    }
  }

  /// Gets the current URL from the webview
  Future<String?> getCurrentUrl() async {
    if (controller == null) return null;

    try {
      final result = await controller!.executeScript('window.location.href;');
      return result?.toString();
    } catch (e) {
      print('Error getting current URL: $e');
      return null;
    }
  }

  /// Gets the URL of the right-clicked link
  Future<String?> getRightClickedLinkUrl() async {
    if (controller == null) return null;

    try {
      final result = await controller!.executeScript('window.rightClickedLinkUrl;');
      final url = result?.toString();
      return (url == 'null' || url == null) ? null : url;
    } catch (e) {
      print('Error getting right-clicked link URL: $e');
      return null;
    }
  }

  /// Executes a JavaScript script and returns the result
  Future<dynamic> executeScript(String script) async {
    if (controller == null) return null;

    try {
      return await controller!.executeScript(script);
    } catch (e) {
      print('Error executing script: $e');
      return null;
    }
  }

  /// Gets the currently selected text from the webview
  Future<String?> getSelectedText() async {
    if (controller == null) return null;

    try {
      final result = await controller!.executeScript('window.getSelection().toString();');
      final selectedText = result?.toString();
      return (selectedText == null || selectedText.isEmpty || selectedText == 'null') ? null : selectedText;
    } catch (e) {
      print('Error getting selected text: $e');
      return null;
    }
  }

  /// Checks if the webview is ready for JavaScript execution
  Future<bool> isWebViewReady() async {
    try {
      final result = await getCurrentUrl();
      return result != null && result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

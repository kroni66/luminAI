import 'dart:async';
import 'package:flutter/material.dart';
import '../services/web_scraping_service.dart';
import '../services/web_view_javascript_manager.dart';
import '../widgets/web_view_constants.dart';

/// Handler for link preview functionality
class LinkPreviewHandler {
  final WebScrapingService _webScrapingService;
  final WebViewJavaScriptManager _javascriptManager;
  final double sidebarWidth;

  LinkPreviewHandler({
    required WebScrapingService webScrapingService,
    required WebViewJavaScriptManager javascriptManager,
    required this.sidebarWidth,
  }) :
    _webScrapingService = webScrapingService,
    _javascriptManager = javascriptManager;

  /// Handles link preview action from context menu
  Future<void> handleLinkPreview({
    required Function(String, Offset)? onShowLinkPreview,
  }) async {
    try {
      print('=== PREVIEW LINK TRIGGERED ===');

      // Get the right-clicked link URL using JavaScript manager
      final linkUrl = await _javascriptManager.getRightClickedLinkUrl();
      if (linkUrl == null || linkUrl.isEmpty) {
        print('No right-clicked link URL available');
        return;
      }

      print('Hover preview triggered for: $linkUrl');

      // Skip if URL is same as current page
      final currentUrl = await _javascriptManager.getCurrentUrl();
      if (currentUrl != null && _isSameUrl(linkUrl, currentUrl)) {
        print('Skipping preview: URL is same as current page');
        return;
      }

      // Extract link information and show preview
      final linkInfo = await _extractLinkInfo(linkUrl);
      if (linkInfo != null) {
        _processAndShowLinkPreview(linkInfo, onShowLinkPreview);
      } else {
        print('No preview available: Could not extract link information');
      }
    } catch (e) {
      print('Error getting link info: $e');
    }
  }

  /// Handles link analysis action from context menu
  Future<void> handleLinkAnalysis({
    required Function(String)? onSendTextToChat,
  }) async {
    try {
      print('=== LINK ANALYSIS TRIGGERED ===');

      // Get the current URL from the webview
      final currentUrl = await _javascriptManager.getCurrentUrl();
      if (currentUrl == null) {
        print('No current URL available for analysis');
        onSendTextToChat?.call('No page loaded for analysis. Please load a webpage first.');
        return;
      }

      print('Analyzing current page: $currentUrl');
      await _performLinkAnalysis(currentUrl, onSendTextToChat);
    } catch (e) {
      print('Error getting page for analysis: $e');
      onSendTextToChat?.call('Error analyzing page. Please try again.');
    }
  }

  /// Extracts basic link information for preview
  Future<Map<String, dynamic>?> _extractLinkInfo(String linkUrl) async {
    try {
      // Return basic info about the link
      return {
        'url': linkUrl,
        'x': WebViewConstants.defaultPreviewX,
        'y': WebViewConstants.defaultPreviewY,
        'linkText': 'Link Preview',
        'elementType': 'a'
      };
    } catch (e) {
      print('Error extracting link info: $e');
      return null;
    }
  }

  /// Processes and shows link preview
  void _processAndShowLinkPreview(
    Object linkInfo,
    Function(String, Offset)? onShowLinkPreview,
  ) async {
    print('=== LINK PREVIEW DEBUG - PROCESSING ===');
    print('Raw linkInfo: $linkInfo');
    print('linkInfo type: ${linkInfo.runtimeType}');

    if (linkInfo is Map<String, dynamic>) {
      final url = linkInfo['url'] as String?;
      final x = (linkInfo['x'] as num?)?.toDouble() ?? WebViewConstants.defaultPreviewX;
      final y = (linkInfo['y'] as num?)?.toDouble() ?? WebViewConstants.defaultPreviewY;

      print('=== LINK PREVIEW DEBUG ===');
      print('Extracted URL: $url');
      print('Position: ($x, $y)');

      if (url != null && url.isNotEmpty) {
        // Fetch additional metadata for better preview
        final metadata = await _webScrapingService.fetchWebPageMetadata(url);

        if (metadata != null) {
          print('Fetched metadata: ${metadata['title']} ${metadata['fallback'] == true ? '(fallback)' : '(real)'}');
        }

        // Convert WebView coordinates to Flutter app coordinates
        final adjustedX = x + sidebarWidth;
        final adjustedY = y + WebViewConstants.appBarHeight;

        print('Calling onShowLinkPreview with URL: $url at position ($adjustedX, $adjustedY)');
        onShowLinkPreview?.call(url, Offset(adjustedX, adjustedY));
      } else {
        print('URL is null or empty - cannot show preview');
      }
    } else {
      print('linkInfo is not a Map - got: $linkInfo');
    }
  }

  /// Performs link analysis using web scraping service
  Future<void> _performLinkAnalysis(
    String url,
    Function(String)? onSendTextToChat,
  ) async {
    // Show loading message
    onSendTextToChat?.call('Analyzing website: $url\n\nPlease wait while I fetch and analyze the content...');

    try {
      final analysisResult = await _webScrapingService.fetchWebsiteContent(url);
      onSendTextToChat?.call(analysisResult);
    } catch (e) {
      print('Error fetching website for analysis: $e');
      onSendTextToChat?.call('Unable to fetch website content for analysis. Error: $e');
    }
  }

  /// Checks if two URLs are essentially the same
  bool _isSameUrl(String url1, String url2) {
    return url1 == url2 || url1 == url2 + '#' || url1 == url2.split('#')[0];
  }
}

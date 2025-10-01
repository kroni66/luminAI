import 'dart:async';
import 'package:flutter/material.dart';
import 'web_preview_service.dart';
import 'ai_service.dart';

class HoverPreviewManager {
  final AIService _aiService;

  bool _showHoverPreview = false;
  Offset _hoverPosition = Offset.zero;
  String _hoveredUrl = '';
  WebPreviewData? _previewData;

  // Callbacks
  VoidCallback? onPreviewStateChanged;

  HoverPreviewManager(this._aiService);

  // Getters
  bool get showHoverPreview => _showHoverPreview;
  Offset get hoverPosition => _hoverPosition;
  String get hoveredUrl => _hoveredUrl;
  WebPreviewData? get previewData => _previewData;

  /// Show hover preview for a URL at the given position
  Future<void> showHoverPreviewForUrl(String url, Offset position, String currentUrl) async {
    debugPrint('=== HOVER PREVIEW MANAGER DEBUG ===');
    debugPrint('Received URL: $url');
    debugPrint('Current page URL: $currentUrl');
    debugPrint('Position: $position');

    if (url.isEmpty || url == _hoveredUrl) {
      debugPrint('Skipping preview: URL is empty or same as previously hovered URL');
      return;
    }

    debugPrint('Hover preview triggered for: $url');

    // Ensure we're not previewing the current page
    if (url == currentUrl) {
      debugPrint('Skipping preview: URL is same as current page');
      return;
    }

    // Additional validation - check if URLs are similar (same domain)
    try {
      final currentUri = Uri.parse(currentUrl);
      final targetUri = Uri.parse(url);

      if (currentUri.host == targetUri.host && currentUri.path == targetUri.path) {
        debugPrint('Skipping preview: URLs are too similar');
        debugPrint('Current: ${currentUri.host}${currentUri.path}');
        debugPrint('Target: ${targetUri.host}${targetUri.path}');
        return;
      }

      debugPrint('URLs are different - proceeding with preview');
      debugPrint('Current domain: ${currentUri.host}');
      debugPrint('Target domain: ${targetUri.host}');
    } catch (e) {
      debugPrint('Error parsing URLs for comparison: $e');
    }

    _hoveredUrl = url;
    _hoverPosition = position;
    _showHoverPreview = true;
    _previewData = null; // Reset preview data
    onPreviewStateChanged?.call();

    try {
      debugPrint('Fetching preview data for hyperlink: $url');
      // Get basic preview data first (force fresh for hover previews)
      final previewData = await WebPreviewService.getWebsitePreview(url, forceFresh: true);

      // Generate AI summary
      String aiSummary = previewData.summary;
      try {
        final prompt = 'Please provide a concise summary of this website content in exactly 120 words or less:\n\n${previewData.summary}';
        String accumulatedResponse = '';

        await for (final chunk in _aiService.generateChatResponseStream(prompt, [])) {
          accumulatedResponse += chunk;
        }

        if (accumulatedResponse.isNotEmpty) {
          aiSummary = accumulatedResponse.trim();
        }
      } catch (e) {
        debugPrint('AI summary failed, using basic summary: $e');
      }

      // Create enhanced preview data with AI summary
      final enhancedPreviewData = WebPreviewData(
        url: previewData.url,
        summary: aiSummary,
        screenshotUrl: previewData.screenshotUrl,
        timestamp: previewData.timestamp,
      );

      if (_hoveredUrl == url && _showHoverPreview) {
        _previewData = enhancedPreviewData;
        onPreviewStateChanged?.call();
      }
    } catch (e) {
      debugPrint('Error loading hover preview: $e');
    }
  }

  /// Hide hover preview
  void hideHoverPreview() {
    if (_showHoverPreview) {
      _showHoverPreview = false;
      _hoveredUrl = '';
      _previewData = null;
      onPreviewStateChanged?.call();
    }
  }
}

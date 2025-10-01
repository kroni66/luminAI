import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class WebPreviewService {
  // Cache to avoid repeated requests
  static final Map<String, WebPreviewData> _cache = {};
  static const Duration _cacheExpiry = Duration(hours: 1);

  /// Get website preview data including summary and screenshot
  /// Set forceFresh to true to bypass cache (useful for hover previews)
  static Future<WebPreviewData> getWebsitePreview(String url, {bool forceFresh = false}) async {
    debugPrint('=== WEB PREVIEW SERVICE ===');
    debugPrint('Requested URL: $url');
    debugPrint('Force fresh: $forceFresh');
    debugPrint('This should be the HYPERLINK URL, not current page');

    // Validate URL
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      debugPrint('Invalid URL format: $url');
      return WebPreviewData(
        url: url,
        summary: 'Invalid URL format. Please provide a complete URL starting with http:// or https://',
        screenshotUrl: null,
        timestamp: DateTime.now(),
      );
    }

    // Skip search engine URLs
    if (url.contains('google.com') ||
        url.contains('bing.com') ||
        url.contains('yahoo.com') ||
        url.contains('duckduckgo.com')) {
      debugPrint('Skipping search engine URL: $url');
      return WebPreviewData(
        url: url,
        summary: 'Search engine URLs are not supported. Please use direct website links.',
        screenshotUrl: null,
        timestamp: DateTime.now(),
      );
    }

    // Check cache first (unless forceFresh is true)
    final cacheKey = url.toLowerCase();
    if (!forceFresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheExpiry) {
        debugPrint('Using cached preview for: $url');
        return cached;
      }
    }

    try {
      // Get website content and generate summary
      final result = await _getWebsiteSummary(url);
      final summary = result['summary']!;
      final title = result['title']!;

      // Get screenshot URL
      final screenshotUrl = _getScreenshotUrl(url);

      final previewData = WebPreviewData(
        url: url,
        summary: summary,
        title: title,
        screenshotUrl: screenshotUrl,
        timestamp: DateTime.now(),
      );
      
      // Cache the result
      _cache[cacheKey] = previewData;
      debugPrint('Successfully created preview for: $url');
      
      return previewData;
    } catch (e) {
      debugPrint('Error getting website preview: $e');
      return WebPreviewData(
        url: url,
        summary: 'Unable to load preview for this website. The site may be unavailable or blocked.',
        screenshotUrl: null,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Extract and summarize website content
  static Future<Map<String, String>> _getWebsiteSummary(String url) async {
    try {
      debugPrint('=== FETCHING HYPERLINK CONTENT ===');
      debugPrint('Target hyperlink URL: $url');
      debugPrint('About to make HTTP request to: $url');
      
      // Validate that we have the correct URL
      if (url.contains('localhost') || url.contains('127.0.0.1')) {
        debugPrint('ERROR: Trying to fetch localhost URL, this is wrong!');
        return {
          'summary': 'Error: Cannot fetch localhost URLs. Please ensure you are fetching the actual hyperlink URL.',
          'title': _extractFallbackTitle(url),
        };
      }
      
      // Create HTTP client with redirect handling
      final client = http.Client();
      
      try {
        final response = await client.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Accept-Encoding': 'gzip, deflate, br',
            'DNT': '1',
            'Connection': 'keep-alive',
            'Upgrade-Insecure-Requests': '1',
          },
        ).timeout(const Duration(seconds: 15));

        debugPrint('Response status: ${response.statusCode}');
        debugPrint('Final URL after redirects: ${response.request?.url}');
        debugPrint('Response content length: ${response.body.length}');
        
        // Check if we got redirected to a different domain
        final finalUrl = response.request?.url.toString() ?? url;
        if (finalUrl != url) {
          debugPrint('REDIRECT DETECTED: $url -> $finalUrl');
        }

        if (response.statusCode == 200) {
          final content = response.body;
          
          // Quick check to see if we got the right content
          if (content.contains('<title>')) {
            final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(content);
            final title = titleMatch?.group(1)?.trim() ?? 'No title';
            debugPrint('Page title found: $title');
          }
          
          return _extractSummaryFromHtml(content, finalUrl);
        } else if (response.statusCode >= 300 && response.statusCode < 400) {
          // Handle redirects manually if needed
          final location = response.headers['location'];
          if (location != null) {
            debugPrint('Redirect to: $location');
            return _getWebsiteSummary(location);
          }
        }
        
        return {
          'summary': 'Unable to access this website (HTTP ${response.statusCode}). The site may be blocking automated requests.',
          'title': _extractFallbackTitle(url),
        };
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Error fetching website content: $e');
      return {
        'summary': _getFallbackSummary(url),
        'title': _extractFallbackTitle(url),
      };
    }
  }

  /// Extract summary from HTML content
  static Map<String, String> _extractSummaryFromHtml(String html, String url) {
    try {
      debugPrint('Parsing HTML content for URL: $url');
      
      // Remove script, style, and other non-content tags
      String cleanHtml = html.replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '');
      cleanHtml = cleanHtml.replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '');
      cleanHtml = cleanHtml.replaceAll(RegExp(r'<nav[^>]*>.*?</nav>', caseSensitive: false, dotAll: true), '');
      cleanHtml = cleanHtml.replaceAll(RegExp(r'<header[^>]*>.*?</header>', caseSensitive: false, dotAll: true), '');
      cleanHtml = cleanHtml.replaceAll(RegExp(r'<footer[^>]*>.*?</footer>', caseSensitive: false, dotAll: true), '');
      
      // Extract title
      final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(cleanHtml);
      String title = titleMatch?.group(1)?.trim() ?? '';
      title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      // Extract meta description with simpler regex
      String metaDesc = '';
      
      // Try different meta description patterns
      var match = RegExp(r'<meta[^>]*name=.description.[^>]*content=.([^>]*).>', caseSensitive: false).firstMatch(cleanHtml);
      if (match != null && match.group(1) != null) {
        metaDesc = match.group(1)!.replaceAll('"', '').replaceAll("'", '').trim();
      } else {
        match = RegExp(r'<meta[^>]*property=.og:description.[^>]*content=.([^>]*).>', caseSensitive: false).firstMatch(cleanHtml);
        if (match != null && match.group(1) != null) {
          metaDesc = match.group(1)!.replaceAll('"', '').replaceAll("'", '').trim();
        }
      }
      
      // Extract main content from common content containers
      String mainContent = '';

      // Try multiple selectors for main content, prioritizing page-specific content
      final contentSelectors = [
        // Most specific - look for content areas that are likely page-specific
        r'<div[^>]*class=.*(?:post-content|entry-content|article-content|page-content).*[^>]*>(.*?)</div>',
        r'<div[^>]*id=.*(?:post-content|entry-content|article-content|page-content).*[^>]*>(.*?)</div>',
        r'<article[^>]*class=.*(?:post|entry).*[^>]*>(.*?)</article>',
        r'<main[^>]*class=.*(?:content|main).*[^>]*>(.*?)</main>',
        // Medium specific
        r'<main[^>]*>(.*?)</main>',
        r'<article[^>]*>(.*?)</article>',
        // General content areas (but avoid common site-wide elements)
        r'<div[^>]*class=.*(?:content|post|entry|article)(?!.*(?:nav|header|footer|sidebar|menu|widget)).*[^>]*>(.*?)</div>',
        r'<section[^>]*class=.*(?:content|post|entry|article).*[^>]*>(.*?)</section>',
      ];

      for (final selector in contentSelectors) {
        final contentMatch = RegExp(selector, caseSensitive: false, dotAll: true).firstMatch(cleanHtml);
        if (contentMatch != null && contentMatch.group(1) != null) {
          mainContent = contentMatch.group(1)!;
          // Clean the content to remove nested tags we don't want
          mainContent = mainContent.replaceAll(RegExp(r'<nav[^>]*>.*?</nav>', caseSensitive: false, dotAll: true), '');
          mainContent = mainContent.replaceAll(RegExp(r'<header[^>]*>.*?</header>', caseSensitive: false, dotAll: true), '');
          mainContent = mainContent.replaceAll(RegExp(r'<footer[^>]*>.*?</footer>', caseSensitive: false, dotAll: true), '');
          mainContent = mainContent.replaceAll(RegExp(r'<aside[^>]*>.*?</aside>', caseSensitive: false, dotAll: true), '');
          mainContent = mainContent.replaceAll(RegExp(r'<div[^>]*class=.*(?:sidebar|widget|menu|nav).*?>.*?</div>', caseSensitive: false, dotAll: true), '');

          if (mainContent.length > 200) { // Need substantial content
            // Additional filtering: avoid content that looks like general site navigation/info
            final lowerContent = mainContent.toLowerCase();
            final isLikelyPageContent = !lowerContent.contains('© copyright') &&
                                       !lowerContent.contains('all rights reserved') &&
                                       !lowerContent.contains('privacy policy') &&
                                       !lowerContent.contains('terms of service') &&
                                       !lowerContent.contains('contact us') &&
                                       !lowerContent.contains('about us') &&
                                       !(lowerContent.contains('home') && lowerContent.contains('blog') && lowerContent.contains('contact'));

            if (isLikelyPageContent) {
              debugPrint('Found content using selector: $selector (length: ${mainContent.length})');
              break;
            } else {
              debugPrint('Rejected content (appears to be general site content): $selector');
              mainContent = ''; // Reset to try next selector
            }
          }
        }
      }
      
      // If no main content found, use body
      if (mainContent.isEmpty) {
        final bodyMatch = RegExp(r'<body[^>]*>(.*?)</body>', caseSensitive: false, dotAll: true).firstMatch(cleanHtml);
        mainContent = bodyMatch?.group(1) ?? cleanHtml;
      }
      
      // Extract text from main content
      String bodyText = mainContent.replaceAll(RegExp(r'<[^>]*>'), ' ');
      bodyText = bodyText.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      // Build comprehensive summary
      String summary = '';

      if (title.isNotEmpty &&
          !title.toLowerCase().contains('google') &&
          !title.toLowerCase().contains('search') &&
          !title.toLowerCase().contains('bing') &&
          !title.toLowerCase().contains('yahoo')) {
        summary += title;
        debugPrint('Extracted title: $title');
      }

      if (metaDesc.isNotEmpty &&
          !metaDesc.toLowerCase().contains('google') &&
          !metaDesc.toLowerCase().contains('search') &&
          !metaDesc.toLowerCase().contains('bing') &&
          !metaDesc.toLowerCase().contains('yahoo')) {
        if (summary.isNotEmpty) summary += '\n\n';
        summary += metaDesc;
        debugPrint('Extracted meta description: $metaDesc');
      }

      // Debug: Log what we're extracting
      debugPrint('=== CONTENT EXTRACTION DEBUG ===');
      debugPrint('URL: $url');
      debugPrint('Title: $title');
      debugPrint('Meta desc: $metaDesc');
      debugPrint('Body text length: ${bodyText.length}');
      debugPrint('Body text preview: ${bodyText.substring(0, min(200, bodyText.length))}');
      
      // Add body content if we need more
      if (summary.length < 100 && bodyText.isNotEmpty) {
        // Take first few sentences from body text
        final sentences = bodyText.split(RegExp(r'[.!?]+'));
        String additionalText = '';
        for (final sentence in sentences) {
          final cleanSentence = sentence.trim();
          if (cleanSentence.length > 10 && 
              !cleanSentence.toLowerCase().contains('google') && 
              !cleanSentence.toLowerCase().contains('search') &&
              !cleanSentence.toLowerCase().contains('bing') &&
              !cleanSentence.toLowerCase().contains('yahoo') &&
              !cleanSentence.toLowerCase().contains('cookie') &&
              !cleanSentence.toLowerCase().contains('privacy policy')) {
            additionalText += '$cleanSentence. ';
            if (additionalText.length > 300) break;
          }
        }
        
        if (additionalText.isNotEmpty) {
          if (summary.isNotEmpty) summary += '\n\n';
          summary += additionalText.trim();
        }
      }
      
      // Clean up and limit to 120 words
      summary = summary.replaceAll(RegExp(r'\s+'), ' ').trim();
      final words = summary.split(RegExp(r'\s+'));
      if (words.length > 120) {
        summary = '${words.take(120).join(' ')}...';
      }
      
      debugPrint('Final summary length: ${summary.length} characters, ${words.length} words');
      
      return {
        'summary': summary.isNotEmpty ? summary : _getFallbackSummary(url),
        'title': title.isNotEmpty ? title : _extractFallbackTitle(url),
      };
    } catch (e) {
      debugPrint('Error parsing HTML: $e');
      return {
        'summary': _getFallbackSummary(url),
        'title': _extractFallbackTitle(url),
      };
    }
  }

  /// Generate screenshot URL using reliable screenshot service
  static String _getScreenshotUrl(String url) {
    try {
      final cleanUrl = url.startsWith('http') ? url : 'https://$url';

      // Use S-Shot.ru as primary service - it's more reliable for most sites
      final screenshotUrl = 'https://mini.s-shot.ru/1024x768/JPEG/1024/Z100/?${Uri.encodeComponent(cleanUrl)}';

      debugPrint('Generated screenshot URL: $screenshotUrl');
      return screenshotUrl;

    } catch (e) {
      debugPrint('Error generating screenshot URL: $e');
      // Return a placeholder
      return 'https://via.placeholder.com/1024x768/f0f0f0/666666?text=Screenshot+Service+Unavailable';
    }
  }

  /// Get fallback summary when content extraction fails
  static String _getFallbackSummary(String url) {
    try {
      final uri = Uri.parse(url);
      final domain = uri.host;
      return 'This link leads to $domain. Click to visit the website and explore its content.';
    } catch (e) {
      return 'This is a web link. Click to visit the website and explore its content.';
    }
  }

  /// Get fallback title when extraction fails
  static String _extractFallbackTitle(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.path.isNotEmpty && uri.path != '/') {
        final pathParts = uri.path.split('/').where((part) => part.isNotEmpty);
        if (pathParts.isNotEmpty) {
          final lastPart = pathParts.last;
          final readableName = lastPart
              .replaceAll('-', ' ')
              .replaceAll('_', ' ')
              .split(' ')
              .map((word) => word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1)}' : '')
              .join(' ');
          return '$readableName - ${uri.host}';
        }
      }
      return uri.host;
    } catch (e) {
      return url;
    }
  }

  /// Clear cache
  static void clearCache() {
    _cache.clear();
  }

  /// Clear cache for specific URL
  static void clearCacheForUrl(String url) {
    final cacheKey = url.toLowerCase();
    _cache.remove(cacheKey);
    debugPrint('Cleared cache for URL: $url');
  }
}

class WebPreviewData {
  final String url;
  final String summary;
  final String? title;
  final String? screenshotUrl;
  final DateTime timestamp;

  WebPreviewData({
    required this.url,
    required this.summary,
    this.title,
    this.screenshotUrl,
    required this.timestamp,
  });
}

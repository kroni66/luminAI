import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../widgets/web_view_constants.dart';

/// Service for web scraping and metadata extraction
class WebScrapingService {
  final http.Client _client = http.Client();

  /// Fetches webpage metadata including title, description, and images
  Future<Map<String, dynamic>?> fetchWebPageMetadata(String url) async {
    try {
      // Add small random delay to appear less automated
      final randomDelay = WebViewConstants.randomDelayMin.inMilliseconds +
                         (DateTime.now().millisecondsSinceEpoch % WebViewConstants.randomDelayMax.inMilliseconds);
      await Future.delayed(Duration(milliseconds: randomDelay));

      // Rotate User-Agents to avoid detection
      final selectedUserAgent = WebViewConstants.userAgents[
        DateTime.now().millisecondsSinceEpoch % WebViewConstants.userAgents.length
      ];

      final headers = _buildStandardHeaders(selectedUserAgent);

      final response = await _client.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(WebViewConstants.httpTimeout);

      if (response.statusCode == 200) {
        return _parseHtmlMetadata(response.body, url);
      } else if (response.statusCode == 403) {
        // Try with alternative headers
        return await _fetchWithAlternativeHeaders(url);
      } else {
        return _createBasicLinkInfo(url);
      }
    } catch (e) {
      return _createBasicLinkInfo(url);
    }
  }

  /// Fetches website content for analysis
  Future<String> fetchWebsiteContent(String url) async {
    try {
      final response = await _client.get(
        Uri.parse(url),
        headers: _buildAnalysisHeaders(),
      ).timeout(WebViewConstants.httpTimeout);

      if (response.statusCode == 200) {
        return _extractWebsiteInfo(response.body, url);
      } else {
        return '${WebViewConstants.websiteUnavailable} at $url (HTTP ${response.statusCode}). '
               'The site may be unavailable or blocking automated requests.';
      }
    } finally {
      _client.close();
    }
  }

  /// Checks if a URL is for a downloadable file
  bool isDownloadableUrl(String url) {
    final pathname = Uri.parse(url).path.toLowerCase();
    return WebViewConstants.downloadableExtensions
        .any((ext) => pathname.endsWith(ext));
  }

  /// Builds standard HTTP headers for web scraping
  Map<String, String> _buildStandardHeaders(String userAgent) {
    final headers = {
      'User-Agent': userAgent,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
      'Accept-Language': 'en-US,en;q=0.9',
      'Accept-Encoding': 'gzip, deflate, br',
      'Cache-Control': 'max-age=0',
      'DNT': '1',
      'Upgrade-Insecure-Requests': '1',
    };

    // Add browser-specific headers
    if (userAgent.contains('Chrome')) {
      headers.addAll({
        'Sec-Ch-Ua': '"Google Chrome";v="119", "Chromium";v="119", "Not?A_Brand";v="24"',
        'Sec-Ch-Ua-Mobile': '?0',
        'Sec-Ch-Ua-Platform': '"Windows"',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'cross-site',
        'Sec-Fetch-User': '?1',
      });
    } else if (userAgent.contains('Firefox')) {
      headers.addAll({
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'cross-site',
        'Sec-Fetch-User': '?1',
      });
    }

    return headers;
  }

  /// Builds headers for website analysis
  Map<String, String> _buildAnalysisHeaders() {
    return {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    };
  }

  /// Fetches with alternative headers when standard request fails
  Future<Map<String, dynamic>?> _fetchWithAlternativeHeaders(String url) async {
    try {
      await Future.delayed(WebViewConstants.alternativeRequestDelay);

      final selectedUserAgent = WebViewConstants.fallbackUserAgents[
        DateTime.now().millisecondsSinceEpoch % WebViewConstants.fallbackUserAgents.length
      ];

      final headers = {
        'User-Agent': selectedUserAgent,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'gzip, deflate',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Referer': 'https://www.bing.com/',
        'DNT': '1',
      };

      final response = await _client.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return _parseHtmlMetadata(response.body, url);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Creates basic link info when metadata cannot be fetched
  Map<String, dynamic> _createBasicLinkInfo(String url) {
    try {
      final uri = Uri.parse(url);
      final domain = uri.host;
      final pathSegments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();

      // Create readable title from URL
      String title = domain;
      if (pathSegments.isNotEmpty) {
        title = pathSegments.last.replaceAll('-', ' ').replaceAll('_', ' ');
        title = title.split(' ').map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : '').join(' ');
      }

      return {
        'title': title,
        'description': 'Link to ${domain} - Content preview not available',
        'image': null,
        'url': url,
        'timestamp': DateTime.now().toIso8601String(),
        'fallback': true,
      };
    } catch (e) {
      return {
        'title': 'Link Preview',
        'description': 'Content preview not available for this link',
        'image': null,
        'url': url,
        'timestamp': DateTime.now().toIso8601String(),
        'fallback': true,
      };
    }
  }

  /// Parses HTML to extract metadata
  Map<String, dynamic>? _parseHtmlMetadata(String html, String url) {
    try {
      final document = html_parser.parse(html);

      String? title = _extractMetaProperty(document, 'og:title') ??
                     _extractMetaName(document, 'title') ??
                     document.querySelector('title')?.text ??
                     'Unknown Title';

      String? description = _extractMetaProperty(document, 'og:description') ??
                           _extractMetaName(document, 'description') ??
                           _extractMetaProperty(document, 'description');

      String? image = _extractMetaProperty(document, 'og:image');

      return {
        'title': title,
        'description': description,
        'image': image,
        'url': url,
        'timestamp': DateTime.now().toIso8601String()
      };
    } catch (e) {
      return null;
    }
  }

  /// Extracts website information for analysis
  String _extractWebsiteInfo(String content, String url) {
    final title = _extractTitle(content);
    final description = _extractDescription(content);

    return '''
I've analyzed the website at: $url

Title: ${title.isNotEmpty ? title : 'Not available'}

${description.isNotEmpty ? 'Description: $description' : ''}

Please provide a detailed analysis of this website based on the information above. What type of website is this? What seems to be its main purpose? Any notable features or content?
''';
  }

  /// Extracts title from HTML content
  String _extractTitle(String content) {
    try {
      final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(content);
      return titleMatch?.group(1)?.trim() ?? '';
    } catch (e) {
      return 'Unknown title';
    }
  }

  /// Extracts description from HTML content
  String _extractDescription(String content) {
    try {
      final match = RegExp(r'<meta[^>]*name=.description.[^>]*content=.([^>]*).>', caseSensitive: false).firstMatch(content);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.replaceAll('"', '').replaceAll("'", '').trim();
      }
    } catch (e) {
      // Ignore errors
    }
    return '';
  }

  /// Extracts meta property from HTML document
  String? _extractMetaProperty(var document, String property) {
    final meta = document.querySelector('meta[property="$property"]');
    return meta?.attributes['content'];
  }

  /// Extracts meta name from HTML document
  String? _extractMetaName(var document, String name) {
    final meta = document.querySelector('meta[name="$name"]');
    return meta?.attributes['content'];
  }
}

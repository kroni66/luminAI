import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'ai_service.dart';

/// Manages contextual highlighting of key information on web pages.
/// Provides functionality to toggle highlighting mode, inject CSS/JavaScript for highlighting,
/// and track scroll position to continuously highlight relevant content.
class ContextualHighlightsManager {
  /// The AI service used for intelligent highlighting
  final AIService _aiService;

  /// Whether contextual highlighting is currently active
  bool _isActive = false;

  /// Callback when highlight state changes
  VoidCallback? onHighlightStateChanged;

  /// Stream controller for highlight state changes
  final StreamController<bool> _highlightStateController = StreamController<bool>.broadcast();

  /// Stream of highlight state changes
  Stream<bool> get highlightStateStream => _highlightStateController.stream;

  /// Get current highlight state
  bool get isActive => _isActive;

  /// Toggle contextual highlighting mode
  void toggleHighlights() {
    _isActive = !_isActive;
    _highlightStateController.add(_isActive);
    onHighlightStateChanged?.call();
    debugPrint('Contextual highlights ${_isActive ? 'enabled' : 'disabled'}');
  }

  /// Enable contextual highlighting
  void enableHighlights() {
    if (!_isActive) {
      _isActive = true;
      _highlightStateController.add(_isActive);
      onHighlightStateChanged?.call();
      debugPrint('Contextual highlights enabled');
    }
  }

  /// Disable contextual highlighting
  void disableHighlights() {
    if (_isActive) {
      _isActive = false;
      _highlightStateController.add(_isActive);
      onHighlightStateChanged?.call();
      debugPrint('Contextual highlights disabled');
    }
  }

  /// Inject CSS and JavaScript for contextual highlighting into the webview
  Future<void> injectHighlightingScript(WebviewController? controller) async {
    if (controller == null || !controller.value.isInitialized) {
      debugPrint('Webview controller not available for highlighting injection');
      return;
    }

    try {
      // Extract web page content with enhanced context
      final pageData = await _extractPageContent(controller);
      if (pageData == null || pageData.isEmpty) {
        debugPrint('No page content available for highlighting');
        return;
      }

      // Get AI-identified key information to highlight with context awareness
      final highlights = await _identifyKeyInformationWithAI(pageData);
      if (highlights.isEmpty) {
        debugPrint('No key information identified by AI');
        return;
      }

      // Inject CSS for highlighting styles
      await controller.executeScript(_getHighlightingCSS());

      // Inject JavaScript for highlighting identified elements
      await controller.executeScript(_generateAIHighlightingScript(highlights));

      debugPrint('AI-powered contextual highlighting scripts injected successfully');
    } catch (e) {
      debugPrint('Error injecting AI highlighting scripts: $e');
    }
  }

  /// Remove highlighting styles and scripts from the webview
  Future<void> removeHighlightingScript(WebviewController? controller) async {
    if (controller == null || !controller.value.isInitialized) {
      debugPrint('Webview controller not available for highlighting removal');
      return;
    }

    try {
      // Remove highlighting CSS and JavaScript
      await controller.executeScript('''
        // Remove highlight styles
        const highlightStyle = document.getElementById('contextual-highlight-style');
        if (highlightStyle) {
          highlightStyle.remove();
        }

        // Remove existing highlights by replacing spans with plain text
        const highlightSelectors = ['.contextual-highlight-word', '.contextual-highlight-phrase', '.contextual-highlight-sentence'];
        highlightSelectors.forEach(selector => {
          const highlights = document.querySelectorAll(selector);
          highlights.forEach(el => {
            const text = el.textContent;
            const textNode = document.createTextNode(text);
            el.parentNode.replaceChild(textNode, el);
          });
        });

        console.log('Contextual highlighting removed');
      ''');

      debugPrint('Contextual highlighting scripts removed successfully');
    } catch (e) {
      debugPrint('Error removing highlighting scripts: $e');
    }
  }

  /// Extract page content for AI analysis with enhanced context
  Future<Map<String, dynamic>?> _extractPageContent(WebviewController controller) async {
    try {
      final content = await controller.executeScript('''
        (function() {
          const result = {};

          // Get page title
          result.title = document.title || '';

          // Get meta description
          const metaDesc = document.querySelector('meta[name="description"]');
          result.description = metaDesc ? metaDesc.getAttribute('content') || '' : '';

          // Get URL
          result.url = window.location.href || '';

          // Get main content structure
          result.headings = [];
          ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'].forEach(tag => {
            const elements = document.querySelectorAll(tag);
            elements.forEach(el => {
              if (el.textContent && el.textContent.trim()) {
                result.headings.push({
                  level: tag,
                  text: el.textContent.trim(),
                  tagName: tag
                });
              }
            });
          });

          // Get main content text with structure preservation
          result.mainContent = '';
          const contentSelectors = [
            'main', 'article', '[role="main"]', '.content', '.main-content',
            '.post-content', '.entry-content', '.article-content'
          ];

          let mainElement = null;
          for (const selector of contentSelectors) {
            mainElement = document.querySelector(selector);
            if (mainElement) break;
          }

          if (!mainElement) {
            mainElement = document.body;
          }

          // Extract structured content
          result.structuredContent = [];
          const paragraphs = mainElement.querySelectorAll('p, li, blockquote, dd, dt');
          paragraphs.forEach((el, index) => {
            if (el.textContent && el.textContent.trim().length > 20) {
              result.structuredContent.push({
                type: el.tagName.toLowerCase(),
                text: el.textContent.trim(),
                index: index
              });
            }
          });

          // Get all visible text content as fallback
          result.fullText = document.body.innerText || document.body.textContent || '';

          // Clean up whitespace
          result.fullText = result.fullText.replace(/\\s+/g, ' ').trim();

          // Limit full text to avoid token limits
          if (result.fullText.length > 8000) {
            result.fullText = result.fullText.substring(0, 8000) + '...';
          }

          // Determine content type based on URL and content
          result.contentType = _determineContentType(result.url, result.headings, result.description);

          return JSON.stringify(result);
        })();

        function _determineContentType(url, headings, description) {
          const urlLower = url.toLowerCase();
          const descLower = description.toLowerCase();

          if (urlLower.includes('news') || urlLower.includes('article') ||
              headings.some(h => h.text.toLowerCase().includes('news') || h.text.toLowerCase().includes('breaking'))) {
            return 'news';
          }
          if (urlLower.includes('blog') || urlLower.includes('post') ||
              headings.some(h => h.level === 'h1' && h.text.length < 100)) {
            return 'blog';
          }
          if (urlLower.includes('docs') || urlLower.includes('documentation') ||
              urlLower.includes('api') || urlLower.includes('guide') ||
              headings.some(h => h.text.toLowerCase().includes('guide') || h.text.toLowerCase().includes('documentation'))) {
            return 'documentation';
          }
          if (urlLower.includes('edu') || urlLower.includes('course') ||
              urlLower.includes('learn') || urlLower.includes('tutorial') ||
              descLower.includes('learn') || descLower.includes('course')) {
            return 'educational';
          }
          if (urlLower.includes('wiki') || urlLower.includes('wikipedia')) {
            return 'encyclopedia';
          }
          if (headings.some(h => h.text.toLowerCase().includes('product') || h.text.toLowerCase().includes('price'))) {
            return 'ecommerce';
          }

          return 'general';
        }
      ''');

      if (content != null) {
        try {
          final String jsonString = content.toString();
          final Map<String, dynamic> contentData = jsonDecode(jsonString);
          return contentData;
        } catch (e) {
          debugPrint('Error parsing extracted content JSON: $e');
          return null;
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error extracting page content: $e');
      return null;
    }
  }

  /// Use AI to identify key information that should be highlighted with context awareness
  Future<List<Map<String, dynamic>>> _identifyKeyInformationWithAI(Map<String, dynamic> pageData) async {
    try {
      final title = pageData['title'] ?? '';
      final description = pageData['description'] ?? '';
      final url = pageData['url'] ?? '';
      final contentType = pageData['contentType'] ?? 'general';
      final headings = pageData['headings'] ?? [];
      final structuredContent = pageData['structuredContent'] ?? [];

      // Create content type specific highlighting strategy
      final contentTypeStrategy = _getContentTypeStrategy(contentType);

      final prompt = '''
You are an expert content analyst tasked with identifying the most important information that deserves highlighting based on the website's context and purpose.

WEBSITE CONTEXT:
- Title: $title
- Description: $description
- URL: $url
- Content Type: $contentType
- Headings: ${headings.map((h) => "${h['level']}: ${h['text']}").join(', ')}

CONTENT TYPE STRATEGY: $contentTypeStrategy

ANALYSIS INSTRUCTIONS:
1. Understand the website's primary purpose and audience
2. Identify information critical for the target audience to understand and remember
3. Consider the content type's specific reading patterns and importance criteria
4. Focus on both individual words/phrases AND complete sentences that are essential

HIGHLIGHTING RULES:
- Return a JSON array of highlight objects
- Each object should have: "text", "type" ("word", "phrase", or "sentence"), "importance" (1-5), "reason"
- Maximum 15-25 highlights total
- Prioritize based on content type and user reading goals
- Include both specific terms and complete sentences when they contain critical information

CONTENT TO ANALYZE:
${structuredContent.map((item) => "${item['type'].toUpperCase()}: ${item['text']}").join('\n\n')}

Return only a valid JSON array of highlight objects.
''';

      final response = await _aiService.generateChatResponse(prompt, []);

      // Parse the JSON response
      if (response.contains('[') && response.contains(']')) {
        final jsonStart = response.indexOf('[');
        final jsonEnd = response.lastIndexOf(']') + 1;
        final jsonString = response.substring(jsonStart, jsonEnd);

        try {
          final List<dynamic> highlights = jsonDecode(jsonString);
          return highlights.map((item) => Map<String, dynamic>.from(item)).toList();
        } catch (e) {
          debugPrint('Error parsing AI response as JSON: $e');
          return [];
        }
      }

      debugPrint('AI response does not contain valid JSON array');
      return [];
    } catch (e) {
      debugPrint('Error getting AI highlights: $e');
      return [];
    }
  }

  /// Get content type specific highlighting strategy
  String _getContentTypeStrategy(String contentType) {
    switch (contentType) {
      case 'news':
        return '''
        NEWS ARTICLES: Highlight breaking information, key facts, dates, statistics, quotes from important people, and conclusions.
        Focus on: Who, What, When, Where, Why, How. Prioritize recent events and verified information.''';

      case 'blog':
        return '''
        BLOG POSTS: Highlight main arguments, key insights, practical tips, personal experiences, and actionable advice.
        Focus on: Author's main points, unique perspectives, and valuable takeaways for readers.''';

      case 'documentation':
        return '''
        DOCUMENTATION: Highlight key concepts, important parameters, code examples, warnings, and step-by-step instructions.
        Focus on: API methods, configuration options, error conditions, and best practices.''';

      case 'educational':
        return '''
        EDUCATIONAL CONTENT: Highlight learning objectives, key concepts, definitions, examples, and important formulas/theories.
        Focus on: Core knowledge, prerequisites, and concepts that build understanding.''';

      case 'encyclopedia':
        return '''
        ENCYCLOPEDIA: Highlight definitions, historical facts, key events, important figures, and categorical information.
        Focus on: Factual data, classifications, and relationships between concepts.''';

      case 'ecommerce':
        return '''
        ECOMMERCE: Highlight prices, product features, specifications, reviews, and purchase information.
        Focus on: Cost, quality indicators, availability, and decision-making criteria.''';

      default:
        return '''
        GENERAL WEBSITES: Highlight unique facts, important data, contact information, key services, and essential details.
        Focus on: Information that helps users understand and interact with the content effectively.''';
    }
  }

  /// Generate JavaScript for highlighting AI-identified words/sentences/phrases
  String _generateAIHighlightingScript(List<Map<String, dynamic>> highlights) {
    final highlightsJson = jsonEncode(highlights);

    return '''
      // Initialize AI-powered contextual highlighting
      (function() {
        // AI-identified key information to highlight
        const keyHighlights = $highlightsJson;

        // Function to highlight specific words/phrases within text nodes
        function highlightTextInNode(node, highlight) {
          if (node.nodeType !== Node.TEXT_NODE) return false;

          const text = node.textContent;
          if (!text || text.trim().length < 3) return false;

          const highlightText = highlight.text;
          const lowerText = text.toLowerCase();
          const lowerHighlight = highlightText.toLowerCase();
          const index = lowerText.indexOf(lowerHighlight);

          if (index !== -1) {
            // Check boundaries based on highlight type
            let isValidBoundary = false;

            if (highlight.type === 'word') {
              // Strict word boundaries for single words
              const beforeChar = index > 0 ? text.charAt(index - 1) : ' ';
              const afterChar = index + highlightText.length < text.length ? text.charAt(index + highlightText.length) : ' ';

              isValidBoundary = (index === 0 || beforeChar === ' ' || beforeChar === '\\n' || beforeChar === '\\t' ||
                                beforeChar === '.' || beforeChar === ',' || beforeChar === '!' ||
                                beforeChar === '?' || beforeChar === ':' || beforeChar === ';') &&
                               (index + highlightText.length === text.length || afterChar === ' ' || afterChar === '\\n' || afterChar === '\\t' ||
                                afterChar === '.' || afterChar === ',' || afterChar === '!' ||
                                afterChar === '?' || afterChar === ':' || afterChar === ';');
            } else {
              // More lenient boundaries for phrases and sentences
              isValidBoundary = true;
            }

            if (isValidBoundary) {
              // Create highlighted span
              const beforeText = text.substring(0, index);
              const highlightContent = text.substring(index, index + highlightText.length);
              const afterText = text.substring(index + highlightText.length);

              // Create new nodes
              const fragment = document.createDocumentFragment();
              if (beforeText) fragment.appendChild(document.createTextNode(beforeText));

              const highlightSpan = document.createElement('span');
              const cssClass = highlight.type === 'sentence' ? 'contextual-highlight-sentence' :
                              highlight.type === 'phrase' ? 'contextual-highlight-phrase' : 'contextual-highlight-word';
              highlightSpan.className = cssClass;
              highlightSpan.setAttribute('data-importance', highlight.importance || '3');
              highlightSpan.setAttribute('data-reason', highlight.reason || '');
              highlightSpan.textContent = highlightContent;
              fragment.appendChild(highlightSpan);

              if (afterText) fragment.appendChild(document.createTextNode(afterText));

              // Replace the original text node
              node.parentNode.replaceChild(fragment, node);
              return true; // Successfully highlighted
            }
          }

          return false;
        }

        // Function to highlight complete sentences
        function highlightSentence(element, highlight) {
          const text = element.textContent || '';
          const highlightText = highlight.text;

          if (text.includes(highlightText)) {
            // Create a wrapper for the entire sentence
            const sentenceSpan = document.createElement('span');
            sentenceSpan.className = 'contextual-highlight-sentence';
            sentenceSpan.setAttribute('data-importance', highlight.importance || '3');
            sentenceSpan.setAttribute('data-reason', highlight.reason || '');
            sentenceSpan.textContent = text;

            // Replace the element content
            element.innerHTML = '';
            element.appendChild(sentenceSpan);
            return true;
          }

          return false;
        }

        // Function to process all content and highlight based on type
        function highlightAllContent() {
          // Remove previous highlights
          const highlightClasses = ['.contextual-highlight-word', '.contextual-highlight-phrase', '.contextual-highlight-sentence'];
          highlightClasses.forEach(selector => {
            const existingHighlights = document.querySelectorAll(selector);
            existingHighlights.forEach(el => {
              // Replace highlight spans with plain text
              const text = el.textContent;
              const textNode = document.createTextNode(text);
              el.parentNode.replaceChild(textNode, el);
            });
          });

          // Group highlights by type for processing
          const wordHighlights = keyHighlights.filter(h => h.type === 'word');
          const phraseHighlights = keyHighlights.filter(h => h.type === 'phrase');
          const sentenceHighlights = keyHighlights.filter(h => h.type === 'sentence');

          // Process word and phrase highlights (similar logic)
          const textHighlights = [...wordHighlights, ...phraseHighlights];
          if (textHighlights.length > 0) {
            const elements = document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li, td, th, div, span, article, section, main, blockquote, dd, dt');

            elements.forEach(element => {
              // Skip navigation and header elements
              if (element.closest('nav, header, footer, aside, .nav, .navigation, .menu, .sidebar')) return;

              // Skip elements that are too small
              const rect = element.getBoundingClientRect();
              if (rect.height < 10) return;

              // Walk through text nodes
              const walker = document.createTreeWalker(
                element,
                NodeFilter.SHOW_TEXT,
                {
                  acceptNode: function(node) {
                    // Skip text in script, style, or already highlighted elements
                    if (node.parentNode && (
                      node.parentNode.tagName === 'SCRIPT' ||
                      node.parentNode.tagName === 'STYLE' ||
                      node.parentNode.tagName === 'NOSCRIPT' ||
                      node.parentNode.classList.contains('contextual-highlight-word') ||
                      node.parentNode.classList.contains('contextual-highlight-phrase') ||
                      node.parentNode.closest('.contextual-highlight-word, .contextual-highlight-phrase')
                    )) {
                      return NodeFilter.FILTER_REJECT;
                    }
                    return NodeFilter.FILTER_ACCEPT;
                  }
                }
              );

              const textNodes = [];
              let currentNode = walker.nextNode();
              while (currentNode) {
                textNodes.push(currentNode);
                currentNode = walker.nextNode();
              }

              // Process text nodes for highlighting
              textNodes.forEach(node => {
                textHighlights.forEach(highlight => {
                  if (!node.parentNode) return; // Node might have been replaced
                  highlightTextInNode(node, highlight);
                });
              });
            });
          }

          // Process sentence highlights
          if (sentenceHighlights.length > 0) {
            const elements = document.querySelectorAll('p, li, blockquote, dd, dt');

            elements.forEach(element => {
              // Skip navigation and header elements
              if (element.closest('nav, header, footer, aside, .nav, .navigation, .menu, .sidebar')) return;

              // Skip elements that are too small
              const rect = element.getBoundingClientRect();
              if (rect.height < 10) return;

              sentenceHighlights.forEach(highlight => {
                highlightSentence(element, highlight);
              });
            });
          }
        }

        // Execute highlighting immediately
        highlightAllContent();

        console.log('AI-powered contextual highlighting completed with', keyHighlights.length, 'highlights across entire page');
        console.log('Highlights by type:', {
          words: keyHighlights.filter(h => h.type === 'word').length,
          phrases: keyHighlights.filter(h => h.type === 'phrase').length,
          sentences: keyHighlights.filter(h => h.type === 'sentence').length
        });
      })();
    ''';
  }

  /// Get CSS styles for contextual highlighting
  String _getHighlightingCSS() {
    return '''
      // Inject highlight styles
      if (!document.getElementById('contextual-highlight-style')) {
        const style = document.createElement('style');
        style.id = 'contextual-highlight-style';
        style.textContent = `
          /* Word highlights - compact and precise */
          .contextual-highlight-word {
            background-color: #FFFF00 !important; /* Bright yellow background */
            color: #000000 !important; /* Black text for contrast */
            font-weight: bold !important;
            padding: 1px 3px !important;
            border-radius: 3px !important;
            border: 1px solid #FFDD00 !important;
            box-shadow: 0 1px 2px rgba(0,0,0,0.1) !important;
            transition: all 0.2s ease !important;
            display: inline !important;
            position: relative !important;
          }

          .contextual-highlight-word:hover {
            background-color: #FFFF88 !important;
            transform: scale(1.05) !important;
          }

          /* Phrase highlights - slightly more prominent */
          .contextual-highlight-phrase {
            background-color: #FFE066 !important; /* Golden yellow */
            color: #000000 !important;
            font-weight: 600 !important;
            padding: 2px 4px !important;
            border-radius: 4px !important;
            border: 1px solid #FFD700 !important;
            box-shadow: 0 2px 4px rgba(0,0,0,0.15) !important;
            transition: all 0.2s ease !important;
            display: inline !important;
            position: relative !important;
          }

          .contextual-highlight-phrase:hover {
            background-color: #FFEB99 !important;
            transform: scale(1.02) !important;
          }

          /* Sentence highlights - most prominent, spans entire sentence */
          .contextual-highlight-sentence {
            background-color: #FF6B6B !important; /* Coral red background */
            color: #FFFFFF !important; /* White text for contrast */
            font-weight: 500 !important;
            padding: 4px 8px !important;
            border-radius: 6px !important;
            border: 2px solid #FF5252 !important;
            box-shadow: 0 3px 8px rgba(0,0,0,0.2) !important;
            transition: all 0.3s ease !important;
            display: inline-block !important;
            position: relative !important;
            line-height: 1.4 !important;
            margin: 2px 0 !important;
          }

          .contextual-highlight-sentence:hover {
            background-color: #FF5252 !important;
            transform: translateY(-1px) !important;
            box-shadow: 0 4px 12px rgba(0,0,0,0.3) !important;
          }

          /* Importance-based styling */
          .contextual-highlight-word[data-importance="5"],
          .contextual-highlight-phrase[data-importance="5"],
          .contextual-highlight-sentence[data-importance="5"] {
            animation: contextual-pulse 2s infinite !important;
          }

          .contextual-highlight-word[data-importance="4"],
          .contextual-highlight-phrase[data-importance="4"],
          .contextual-highlight-sentence[data-importance="4"] {
            opacity: 0.95 !important;
          }

          .contextual-highlight-word[data-importance="2"],
          .contextual-highlight-phrase[data-importance="2"],
          .contextual-highlight-sentence[data-importance="2"] {
            opacity: 0.8 !important;
          }

          .contextual-highlight-word[data-importance="1"],
          .contextual-highlight-phrase[data-importance="1"],
          .contextual-highlight-sentence[data-importance="1"] {
            opacity: 0.7 !important;
          }

          /* Pulse animation for high-importance highlights */
          @keyframes contextual-pulse {
            0%, 100% {
              transform: scale(1);
              box-shadow: 0 3px 8px rgba(0,0,0,0.2);
            }
            50% {
              transform: scale(1.02);
              box-shadow: 0 5px 12px rgba(0,0,0,0.3);
            }
          }

          /* Tooltip for showing highlight reasons */
          .contextual-highlight-word::after,
          .contextual-highlight-phrase::after,
          .contextual-highlight-sentence::after {
            content: attr(data-reason);
            position: absolute;
            bottom: 100%;
            left: 50%;
            transform: translateX(-50%);
            background-color: rgba(0, 0, 0, 0.8);
            color: white;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            white-space: nowrap;
            opacity: 0;
            visibility: hidden;
            transition: all 0.2s ease;
            pointer-events: none;
            z-index: 1000;
          }

          .contextual-highlight-word:hover::after,
          .contextual-highlight-phrase:hover::after,
          .contextual-highlight-sentence:hover::after {
            opacity: 1;
            visibility: visible;
            transform: translateX(-50%) translateY(-4px);
          }
        `;
        document.head.appendChild(style);
      }
    ''';
  }

  /// Constructor
  ContextualHighlightsManager(this._aiService);

  /// Dispose of resources
  void dispose() {
    _highlightStateController.close();
  }
}

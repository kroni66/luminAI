import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../widgets/new_tab_page.dart';
import 'ai_service.dart';
import '../models/tab_info.dart';

class AIRecommendationService {
  final AIService _aiService;

  List<AIRec>? _aiRecommendations;
  bool _hasGeneratedRecommendations = false;
  bool _isOrganizingTabs = false;
  bool _isGeneratingRecommendations = false;

  // Callbacks
  VoidCallback? onRecommendationsChanged;
  VoidCallback? onOrganizationStateChanged;
  VoidCallback? onRecommendationLoadingStateChanged;

  AIRecommendationService(this._aiService);

  // Getters
  List<AIRec>? get aiRecommendations => _aiRecommendations;
  bool get hasGeneratedRecommendations => _hasGeneratedRecommendations;
  bool get isOrganizingTabs => _isOrganizingTabs;
  bool get isGeneratingRecommendations => _isGeneratingRecommendations;

  // AI-powered tab organization
  Future<List<int>> organizeTabsWithAI(List<TabInfo> tabs, int activeTabIndex) async {
    if (tabs.length <= 1) return List.generate(tabs.length, (i) => i);

    // Show loading indicator
    _isOrganizingTabs = true;
    onOrganizationStateChanged?.call();

    try {
      // Prepare tab information for AI analysis
      final tabInfo = tabs.asMap().entries.map((entry) {
        final index = entry.key;
        final tab = entry.value;
        return {
          'index': index,
          'title': tab.title,
          'url': tab.url,
          'domain': _extractDomain(tab.url),
        };
      }).toList();

      // Create AI prompt for tab organization
      final prompt = '''
You are an AI assistant that helps organize browser tabs. Analyze the following tabs and suggest a logical order based on:

1. **Content similarity** - Group similar topics together
2. **Importance/Priority** - More important or frequently used tabs first
3. **Workflow logic** - Tabs that are part of a workflow should be grouped
4. **Domain relationships** - Related websites should be adjacent

Current tabs:
${tabInfo.map((tab) => '${tab['index']}: "${tab['title']}" (${tab['domain']}) - ${tab['url']}').join('\n')}

Please respond with ONLY a JSON array of tab indices in the optimal order. For example: [3, 0, 2, 1, 4]

Consider these factors:
- Social media together (Twitter, Reddit, etc.)
- Shopping sites together (Amazon, eBay, etc.)
- Productivity tools together (GitHub, documentation, etc.)
- News/media together
- Work-related tabs grouped
- Personal tabs grouped
- Keep current active tab (${activeTabIndex}) near the front if it's important

Return ONLY the JSON array, no explanation.
''';

      // Get AI response
      String aiResponse = '';
      await for (final chunk in _aiService.generateChatResponseStream(prompt, [])) {
        aiResponse += chunk;
      }

      // Parse AI response (should be a JSON array of indices)
      final response = aiResponse.trim();
      List<int> newOrder;

      try {
        // Try to parse as JSON array
        final parsed = response.startsWith('[') && response.endsWith(']') && response.length >= 2
            ? response.substring(1, response.length - 1)
                .split(',')
                .map((s) => int.tryParse(s.trim()) ?? -1)
                .where((n) => n >= 0 && n < tabs.length)
                .toList()
            : null;

        if (parsed != null && parsed.length == tabs.length && parsed.toSet().length == tabs.length) {
          newOrder = parsed;
        } else {
          // Fallback: sort by domain similarity
          newOrder = _fallbackTabOrganization(tabs, activeTabIndex);
        }
      } catch (e) {
        debugPrint('Failed to parse AI response: $e');
        newOrder = _fallbackTabOrganization(tabs, activeTabIndex);
      }

      return newOrder;
    } catch (e) {
      debugPrint('Failed to organize tabs with AI: $e');
      return List.generate(tabs.length, (i) => i);
    } finally {
      // Hide loading indicator
      _isOrganizingTabs = false;
      onOrganizationStateChanged?.call();
    }
  }

  // Extract domain from URL
  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (e) {
      return url;
    }
  }

  // Fallback tab organization when AI fails
  List<int> _fallbackTabOrganization(List<TabInfo> tabs, int activeTabIndex) {
    // Simple domain-based grouping
    final domains = tabs.map((tab) => _extractDomain(tab.url)).toList();
    final indices = List<int>.generate(tabs.length, (i) => i);

    // Sort by domain, keeping original relative order within same domain
    indices.sort((a, b) {
      final domainA = domains[a];
      final domainB = domains[b];

      // Prioritize current active tab
      if (a == activeTabIndex) return -1;
      if (b == activeTabIndex) return 1;

      // Group by domain
      final domainCompare = domainA.compareTo(domainB);
      if (domainCompare != 0) return domainCompare;

      // Within same domain, maintain original order
      return a.compareTo(b);
    });

    return indices;
  }

  // Generate AI recommendations based on open tabs (auto-generates only once)
  Future<void> generateAIRecommendations(List<TabInfo> tabs, int activeTabIndex) async {
    if (tabs.length <= 3) {
      _aiRecommendations = null;
      _hasGeneratedRecommendations = false;
      onRecommendationsChanged?.call();
      return;
    }

    // Only auto-generate if we haven't generated before
    if (_hasGeneratedRecommendations) {
      return;
    }

    // Set loading state
    _isGeneratingRecommendations = true;
    onRecommendationLoadingStateChanged?.call();

    try {
      // Prepare tab information for AI analysis
      final tabInfo = tabs.map((tab) {
        final domain = _extractDomain(tab.url);
        return {
          'title': tab.title,
          'url': tab.url,
          'domain': domain,
          'isActive': tabs.indexOf(tab) == activeTabIndex,
        };
      }).toList();

      // Create AI prompt for recommendations
      final prompt = '''
You are an AI assistant that analyzes a user's open browser tabs and suggests what they might want to visit next. Based on the following open tabs, provide exactly 3 specific website recommendations.

Current open tabs:
${tabInfo.map((tab) => '${(tab['isActive'] as bool) ? "ACTIVE: " : ""}"${tab['title']}" (${tab['domain']})').join('\n')}

Analyze the tabs and suggest 3 relevant next websites the user might want to visit. Consider:

1. **Content Flow**: What logically follows from their current browsing
2. **Complementary Content**: Related topics or resources
3. **Productivity**: Tools or services that complement their work
4. **Research Depth**: Deeper dives into topics they're exploring
5. **Current Trends**: Popular or trending content related to their interests

For each recommendation, provide:
- title: A brief, catchy title (max 50 chars)
- description: Short description (max 100 chars)
- url: A realistic, working URL
- category: One word category (work, research, news, social, entertainment, shopping, learning)
- reason: Why this recommendation fits (max 80 chars)

Return ONLY a valid JSON array with exactly 3 objects. Format:
[{"title":"...", "description":"...", "url":"https://...", "category":"...", "reason":"..."}, ...]

Make recommendations practical and immediately useful. Focus on high-quality, popular websites.
''';

      // Get AI response
      String aiResponse = '';
      await for (final chunk in _aiService.generateChatResponseStream(prompt, [])) {
        aiResponse += chunk;
      }

      // Parse AI response
      final response = aiResponse.trim();
      List<AIRec> recommendations = [];

      try {
        // Try to parse as JSON array
        if (response.startsWith('[') && response.endsWith(']')) {
          final jsonList = jsonDecode(response) as List<dynamic>;
          recommendations = jsonList.take(3).map((item) {
            final map = item as Map<String, dynamic>;
            final title = map['title'] as String? ?? 'Recommendation';
            final description = map['description'] as String? ?? '';

            return AIRec(
              title: title.substring(0, math.min(50, title.length)),
              description: description.substring(0, math.min(100, description.length)),
              url: map['url'] as String? ?? 'https://example.com',
              category: map['category'] as String? ?? 'general',
              reason: (map['reason'] as String? ?? '').substring(0, math.min(80, (map['reason'] as String? ?? '').length)),
            );
          }).toList();
        }
      } catch (e) {
        debugPrint('Failed to parse AI recommendations: $e');
        // Don't set recommendations if parsing fails
      }

      _aiRecommendations = recommendations.isNotEmpty ? recommendations : null;
      _hasGeneratedRecommendations = recommendations.isNotEmpty;
      onRecommendationsChanged?.call();

      debugPrint('Generated ${recommendations.length} AI recommendations');
    } catch (e) {
      debugPrint('Failed to generate AI recommendations: $e');
      _aiRecommendations = null;
      onRecommendationsChanged?.call();
    } finally {
      // Clear loading state
      _isGeneratingRecommendations = false;
      onRecommendationLoadingStateChanged?.call();
    }
  }

  // Manually regenerate AI recommendations
  Future<void> regenerateAIRecommendations(List<TabInfo> tabs, int activeTabIndex) async {
    if (tabs.length <= 3) {
      return;
    }

    _hasGeneratedRecommendations = false; // Reset flag to allow regeneration
    await generateAIRecommendations(tabs, activeTabIndex);
  }

  // AI-powered tab organization into folders by categories
  Future<Map<String, List<int>>> organizeTabsIntoFolders(List<TabInfo> tabs, int activeTabIndex) async {
    if (tabs.length <= 2) {
      // Not enough tabs to organize
      return {};
    }

    // Show loading indicator
    _isOrganizingTabs = true;
    onOrganizationStateChanged?.call();

    try {
      // Prepare tab information for AI analysis
      final tabInfo = tabs.asMap().entries.map((entry) {
        final index = entry.key;
        final tab = entry.value;
        return {
          'index': index,
          'title': tab.title,
          'url': tab.url,
          'domain': _extractDomain(tab.url),
        };
      }).toList();

      // Create AI prompt for folder organization
      final prompt = '''
You are an AI assistant that helps organize browser tabs into logical folder categories. Analyze the following tabs and group them into meaningful categories.

Current tabs:
${tabInfo.map((tab) => '${tab['index']}: "${tab['title']}" (${tab['domain']}) - ${tab['url']}').join('\n')}

Please categorize these tabs into logical folder groups. Consider these common categories:
- Social Media (Twitter, Facebook, Reddit, Instagram, etc.)
- Productivity (GitHub, Google Docs, Notion, Trello, etc.)
- News & Media (CNN, BBC, YouTube, etc.)
- Shopping (Amazon, eBay, Walmart, etc.)
- Work/Professional (company sites, professional tools, etc.)
- Entertainment (Netflix, Spotify, gaming sites, etc.)
- Learning/Education (Coursera, Udemy, documentation sites, etc.)
- Finance (banking, PayPal, investment sites, etc.)
- Communication (Gmail, Outlook, Slack, Discord, etc.)
- Travel (booking sites, maps, etc.)
- Health & Fitness (medical sites, fitness trackers, etc.)

Return ONLY a valid JSON object where each key is a folder name and each value is an array of tab indices that belong in that folder. For example:
{
  "Social Media": [1, 3, 7],
  "Productivity": [0, 2, 5],
  "News": [4, 6]
}

Important rules:
1. Only create folders that have 2 or more tabs
2. Each tab should only appear in one folder (no duplicates)
3. Tabs that don't fit well into any category can be left out of folders
4. Use clear, descriptive folder names
5. Return only valid JSON, no explanation text
''';

      // Get AI response
      String aiResponse = '';
      await for (final chunk in _aiService.generateChatResponseStream(prompt, [])) {
        aiResponse += chunk;
      }

      // Parse AI response
      final response = aiResponse.trim();
      Map<String, List<int>> folderOrganization = {};

      try {
        // Try to parse as JSON
        if (response.startsWith('{') && response.endsWith('}')) {
          final parsed = jsonDecode(response) as Map<String, dynamic>;

          // Validate and convert to the expected format
          for (final entry in parsed.entries) {
            final folderName = entry.key;
            final tabIndices = entry.value;

            // Filter out invalid indices and ensure they exist in tabs
            final validIndices = (tabIndices is List)
                ? tabIndices
                    .whereType<int>()
                    .where((index) => index >= 0 && index < tabs.length)
                    .toList()
                : <int>[];

            // Only include folders with 2 or more tabs
            if (validIndices.length >= 2) {
              folderOrganization[folderName] = validIndices;
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to parse AI folder organization response: $e');
        // Return empty organization if parsing fails
      }

      debugPrint('AI organized tabs into ${folderOrganization.length} folders');
      return folderOrganization;

    } catch (e) {
      debugPrint('Failed to organize tabs into folders with AI: $e');
      return {};
    } finally {
      // Hide loading indicator
      _isOrganizingTabs = false;
      onOrganizationStateChanged?.call();
    }
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'ai_service.dart';
import 'settings_manager.dart';
import 'function_calling_service.dart';
import '../models/tab_info.dart';
import '../widgets/tab_sidebar.dart';

class ChatManager {
  final AIService _aiService;
  final SettingsManager _settingsManager;
  final FunctionCallingService _functionCallingService;

  bool _isChatOpen = false;
  bool _isProcessingAction = false;
  bool _isStreaming = false;
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, dynamic>> _chatMessages = [];
  final ScrollController _chatScrollController = ScrollController();

  // Cancellation support for streaming
  StreamSubscription<String>? _currentStreamSubscription;

  // Tab contexts for @ mentions
  final Map<String, Map<String, dynamic>> _tabContexts = {};

  // Callbacks
  VoidCallback? onChatStateChanged;
  VoidCallback? onMessagesChanged;

  ChatManager(this._aiService, this._settingsManager, this._functionCallingService);

  // Getters
  bool get isChatOpen => _isChatOpen;
  bool get isStreaming => _isStreaming;
  bool get toolModeEnabled => _settingsManager.toolModeEnabled;
  TextEditingController get chatController => _chatController;
  List<Map<String, dynamic>> get chatMessages => _chatMessages;
  ScrollController get chatScrollController => _chatScrollController;
  Map<String, Map<String, dynamic>> get tabContexts => _tabContexts;

  void toggleChat() {
    _isChatOpen = !_isChatOpen;
    onChatStateChanged?.call();
  }

  Future<void> toggleToolMode(bool enabled) async {
    await _settingsManager.updateToolModeEnabled(enabled);
    onChatStateChanged?.call(); // Notify UI to update
  }

  void clearChat() {
    _chatMessages.clear();
    _tabContexts.clear(); // Clear tab contexts when chat is cleared
    onMessagesChanged?.call();
  }

  void cancelStreaming() {
    if (_isStreaming && _currentStreamSubscription != null) {
      _currentStreamSubscription!.cancel();
      _currentStreamSubscription = null;
      _isStreaming = false;

      // Find the currently streaming message and mark it as complete
      final streamingIndex = _chatMessages.lastIndexWhere((msg) => msg['streaming'] == true);
      if (streamingIndex != -1) {
        final currentMessage = _chatMessages[streamingIndex];
        _chatMessages[streamingIndex] = {
          ...currentMessage,
          'streaming': false,
          'message': '${currentMessage['message']} [Response stopped]'
        };
        onMessagesChanged?.call();
      }
    }
  }

  Future<void> sendMessage() async {
    if (_chatController.text.trim().isEmpty) return;

    final userMessage = _chatController.text.trim();
    final expandedMessage = _expandTabMentions(userMessage);

    _addMessage({'sender': 'user', 'message': userMessage});
    _chatController.clear();

    // Scroll to bottom
    _scrollChatToBottom();

    // Add a placeholder message for the AI response that will be streamed
    final aiMessageIndex = _chatMessages.length;
    _addMessage({'sender': 'ai', 'message': '', 'streaming': true});

    _isStreaming = true;

    // Generate AI response with function calling capabilities
    try {
      String accumulatedResponse = '';

      // Choose streaming method based on tool mode
      final Stream<String> stream;
      if (_settingsManager.toolModeEnabled) {
        // Use function calling service when tool mode is enabled
        stream = _functionCallingService.generateStreamingResponseWithFunctions(
          expandedMessage,
          _chatMessages.sublist(0, aiMessageIndex).map((msg) => msg.map((k, v) => MapEntry(k, v.toString()))).toList()
        );
      } else {
        // Use direct streaming for regular chat messages
        stream = _aiService.generateChatResponseStream(
          expandedMessage,
          _chatMessages.sublist(0, aiMessageIndex).map((msg) => msg.map((k, v) => MapEntry(k, v.toString()))).toList()
        );
      }

      final completer = Completer<void>();

      _currentStreamSubscription = stream.listen(
        (chunk) {
          accumulatedResponse += chunk;

          // Update the AI message with accumulated response
          _updateMessage(aiMessageIndex, {
            'sender': 'ai',
            'message': accumulatedResponse,
            'streaming': true
          });

          // Auto-scroll as content comes in
          _scrollChatToBottom();
        },
        onDone: () {
          // Mark streaming as complete
          debugPrint('ChatManager: Stream completed for sendMessage, setting streaming to false');
          _isStreaming = false;
          _currentStreamSubscription = null;
          _updateMessage(aiMessageIndex, {
            'sender': 'ai',
            'message': accumulatedResponse,
            'streaming': false
          });
          onChatStateChanged?.call(); // Notify of state change
          completer.complete();
        },
        onError: (error) {
          debugPrint('Error in streaming response: $error');
          _isStreaming = false;
          _currentStreamSubscription = null;
          // Fallback to mock response if AI services fail
          final fallbackResponse = _getAIResponse(expandedMessage);
          _updateMessage(aiMessageIndex, {
            'sender': 'ai',
            'message': fallbackResponse,
            'streaming': false
          });
          onChatStateChanged?.call(); // Notify of state change
          completer.completeError(error);
        }
      );

      // Wait for the stream to complete with a timeout
      await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          debugPrint('ChatManager: SendMessage stream timed out, forcing completion');
          _isStreaming = false;
          _currentStreamSubscription?.cancel();
          _currentStreamSubscription = null;
          _updateMessage(aiMessageIndex, {
            'sender': 'ai',
            'message': accumulatedResponse.isNotEmpty ? accumulatedResponse : 'Response timed out.',
            'streaming': false
          });
          onChatStateChanged?.call();
        }
      );

    } catch (e) {
      debugPrint('Error in sendMessage: $e');
      _isStreaming = false;
      _currentStreamSubscription = null;
      // Fallback to mock response if AI services fail
      final fallbackResponse = _getAIResponse(expandedMessage);
      _updateMessage(aiMessageIndex, {
        'sender': 'ai',
        'message': fallbackResponse,
        'streaming': false
      });
    }

    // Final scroll to bottom
    _scrollChatToBottom();
  }

  void _addMessage(Map<String, dynamic> message) {
    _chatMessages.add(message);
    onMessagesChanged?.call();
  }

  void _updateMessage(int index, Map<String, dynamic> message) {
    if (index >= 0 && index < _chatMessages.length) {
      _chatMessages[index] = message;
      onMessagesChanged?.call();
    }
  }

  void _scrollChatToBottom() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Extract content from current website
  Future<String> extractWebsiteContent(dynamic windowsController) async {
    if (windowsController == null || !windowsController.value.isInitialized) {
      return 'No website is currently loaded.';
    }

    try {
      // Get page title
      final title = await windowsController.executeScript('document.title') ?? 'Unknown Title';

      // Get page URL
      final url = ''; // This would need to be passed in or accessed differently

      // Extract main content (without modifying the live DOM)
      final content = await windowsController.executeScript('''
        (function() {
          // Get all visible text content from the page
          var allText = document.body.innerText || document.body.textContent || '';

          // Clean up whitespace and limit length
          allText = allText.replace(/\\s+/g, ' ').trim();

          // Limit to first 3000 characters to avoid token limits
          if (allText.length > 3000) {
            allText = allText.substring(0, 3000) + '...';
          }

          return allText;
        })();
      ''');

      if (content == null || content.toString().trim().isEmpty) {
        return 'Unable to extract content from the current website.';
      }

      return 'Website: $title\\nURL: $url\\n\\nContent:\\n${content.toString()}';

    } catch (e) {
      debugPrint('Error extracting website content: $e');
      return 'Error extracting content from the current website.';
    }
  }

  // Handle quick actions with website content
  Future<void> handleQuickAction(String action, dynamic windowsController, {String? imageData}) async {
    // Prevent multiple simultaneous calls
    if (_isProcessingAction) {
      debugPrint('handleQuickAction: Already processing an action, ignoring duplicate call');
      return;
    }
    _isProcessingAction = true;

    try {
      // Open chat if not already open
      if (!_isChatOpen) {
        toggleChat();
      }

      // Show that we're processing
      _addMessage({'sender': 'user', 'message': action});
      _scrollChatToBottom();

    // Extract website content
    final websiteContent = await extractWebsiteContent(windowsController);

    // Immediately refresh the webpage to restore original styling
    try {
      if (windowsController != null && windowsController.value.isInitialized) {
        await windowsController.reload();
      }
    } catch (e) {
      debugPrint('Error refreshing webpage after content extraction: $e');
    }

    // Create context-aware prompt based on action
    String prompt;
    switch (action.toLowerCase()) {
      case 'summarize website':
        prompt = 'Please provide a concise summary of this website content:\\n\\n$websiteContent';
        break;
      case 'top 10 key points':
        prompt = 'Please identify and list the top 10 most important points from this website content:\\n\\n$websiteContent';
        break;
      case 'main topics':
        prompt = 'What are the main topics covered on this website? Please list them:\\n\\n$websiteContent';
        break;
      case 'key takeaways':
        prompt = 'What are the key takeaways from this website content?\\n\\n$websiteContent';
        break;
      case 'explain simply':
        prompt = 'Please explain the content of this website in simple terms:\\n\\n$websiteContent';
        break;
      default:
        prompt = '$action\\n\\nWebsite content:\\n$websiteContent';
    }

    // Add language instruction to the prompt
    prompt = _addLanguageInstructionToPrompt(prompt);

    // Add placeholder for AI response
    final aiMessageIndex = _chatMessages.length;
    _addMessage({'sender': 'ai', 'message': '', 'streaming': true});

    _isStreaming = true;

    // Generate AI response with website context
    try {
      String accumulatedResponse = '';

      final stream = _aiService.generateChatResponseStream(prompt, _chatMessages.sublist(0, aiMessageIndex).map((msg) => msg.map((k, v) => MapEntry(k, v.toString()))).toList(), imageData: imageData);

      final completer = Completer<void>();

      _currentStreamSubscription = stream.listen(
        (chunk) {
          debugPrint('ChatManager: Received chunk: ${chunk.length} chars');
          accumulatedResponse += chunk;

          _updateMessage(aiMessageIndex, {
            'sender': 'ai',
            'message': accumulatedResponse,
            'streaming': true
          });

          _scrollChatToBottom();
        },
        onDone: () {
          debugPrint('ChatManager: Stream completed for quick action, setting streaming to false');
          _isStreaming = false;
          _currentStreamSubscription = null;
          _updateMessage(aiMessageIndex, {
            'sender': 'ai',
            'message': accumulatedResponse,
            'streaming': false
          });
          onMessagesChanged?.call(); // Force UI update
          onChatStateChanged?.call(); // Also notify of state change
          completer.complete();
        },
        onError: (error) {
          debugPrint('Error in quick action streaming: $error');
          _isStreaming = false;
          _currentStreamSubscription = null;
          _updateMessage(aiMessageIndex, {
            'sender': 'ai',
            'message': 'Sorry, I couldn\'t analyze the website content. Please make sure Ollama is running and try again.',
            'streaming': false
          });
          onMessagesChanged?.call();
          onChatStateChanged?.call();
          completer.completeError(error);
        }
      );

      // Wait for the stream to complete with a timeout
      await completer.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          debugPrint('ChatManager: Stream timed out, forcing completion');
          _isStreaming = false;
          _currentStreamSubscription?.cancel();
          _currentStreamSubscription = null;
          _updateMessage(aiMessageIndex, {
            'sender': 'ai',
            'message': accumulatedResponse.isNotEmpty ? accumulatedResponse : 'Response timed out.',
            'streaming': false
          });
          onMessagesChanged?.call();
          onChatStateChanged?.call();
        }
      );

    } catch (e) {
      debugPrint('Error in handleQuickAction: $e');
      _isStreaming = false;
      _currentStreamSubscription = null;
      _updateMessage(aiMessageIndex, {
        'sender': 'ai',
        'message': 'Sorry, I couldn\'t analyze the website content. Please make sure Ollama is running and try again.',
        'streaming': false
      });
    }

    _scrollChatToBottom();
  } finally {
    _isProcessingAction = false;
  }
  }

  // Send image to AI chat
  void sendImageToAIChat(String imageUrl, String imageAlt) {
    debugPrint('ChatManager: sendImageToAIChat called with imageUrl length: ${imageUrl.length}, imageAlt: $imageAlt');

    // Open chat if not already open
    if (!_isChatOpen) {
      debugPrint('ChatManager: Opening chat');
      toggleChat();
    }

    // Add user message with image data
    final imageDescription = imageAlt.isNotEmpty ? imageAlt : 'Screenshot from webpage';
    final userMessage = 'Please analyze this screenshot';

    debugPrint('ChatManager: Adding user message with image');
    _addMessage({
      'sender': 'user',
      'message': userMessage,
      'imageData': imageUrl, // Store the base64 image data
      'imageAlt': imageDescription,
    });
    _scrollChatToBottom();

    // Generate AI response with language instruction and image data
    final imagePrompt = _addLanguageInstructionToPrompt('Analyze this screenshot and describe what you see');
    debugPrint('ChatManager: Calling handleQuickAction with prompt: $imagePrompt and imageData length: ${imageUrl.length}');
    handleQuickAction(imagePrompt, null, imageData: imageUrl);
  }

  // Analyze image with AI
  void analyzeImageWithAI(String imageUrl, String imageAlt) {
    // Open chat if not already open
    if (!_isChatOpen) {
      toggleChat();
    }

    // Create detailed analysis prompt
    final imageDescription = imageAlt.isNotEmpty ? imageAlt : 'Image from website';
    final analysisPrompt = 'Please provide a detailed analysis of this image: $imageDescription\n\nImage URL: $imageUrl\n\nPlease describe:\n1. What you see in the image\n2. Key visual elements\n3. Colors and composition\n4. Any text or objects\n5. Overall context and purpose';

    _addMessage({'sender': 'user', 'message': 'Analyze Image: $imageDescription'});
    _scrollChatToBottom();

    // Generate AI response with detailed analysis and language instruction
    final analysisPromptWithLanguage = _addLanguageInstructionToPrompt(analysisPrompt);
    handleQuickAction(analysisPromptWithLanguage, null, imageData: imageUrl);
  }

  // Send selected text to AI chat
  void sendTextToAIChat(String selectedText) {
    // Open chat if not already open
    if (!_isChatOpen) {
      toggleChat();
    }

    // Add user message with selected text
    final userMessage = 'Please explain or analyze this text: "$selectedText"';

    _addMessage({'sender': 'user', 'message': userMessage});
    _scrollChatToBottom();

    // Generate AI response with language instruction
    final textPrompt = _addLanguageInstructionToPrompt('Please explain or analyze this text: "$selectedText"');
    handleQuickAction(textPrompt, null);
  }

  // Localized strings
  String getLocalizedString(String key) {
    final isEnglish = _settingsManager.assistantLanguage == AssistantLanguage.english;

    switch (key) {
      case 'assistant_title':
        return isEnglish ? 'AI Assistant' : 'AI Asistent';
      case 'welcome_message':
        return isEnglish
            ? 'Hello! I\'m your AI assistant.\nHow can I help you today?'
            : 'Ahoj! Jsem váš AI asistent.\nJak vám mohu pomoci?';
      case 'quick_actions':
        return isEnglish ? 'Quick Actions' : 'Rychlé akce';
      case 'summarize_website':
        return isEnglish ? 'Summarize Website' : 'Shrnutí webu';
      case 'top_10_key_points':
        return isEnglish ? 'Top 10 Key Points' : 'Top 10 klíčových bodů';
      case 'main_topics':
        return isEnglish ? 'Main Topics' : 'Hlavní témata';
      case 'key_takeaways':
        return isEnglish ? 'Key Takeaways' : 'Klíčové poznatky';
      case 'explain_simply':
        return isEnglish ? 'Explain Simply' : 'Vysvětli jednoduše';
      case 'clear_chat_title':
        return isEnglish ? 'Clear Chat' : 'Vyčistit chat';
      case 'clear_chat_description':
        return isEnglish
            ? 'Are you sure you want to clear all chat messages? This action cannot be undone.'
            : 'Opravdu chcete vyčistit všechny zprávy v chatu? Tato akce nelze vrátit zpět.';
      case 'cancel':
        return isEnglish ? 'Cancel' : 'Zrušit';
      case 'clear':
        return isEnglish ? 'Clear' : 'Vyčistit';
      case 'ask_me_anything':
        return isEnglish ? 'Ask me anything...' : 'Zeptejte se mě na cokoliv...';
      default:
        return key;
    }
  }

  String _getLanguageInstruction() {
    final isEnglish = _settingsManager.assistantLanguage == AssistantLanguage.english;
    return isEnglish
        ? 'Please respond in English.'
        : 'Odpovídejte prosím v češtině.';
  }

  String _addLanguageInstructionToPrompt(String prompt) {
    final languageInstruction = _getLanguageInstruction();
    return '$languageInstruction\n\n$prompt';
  }

  String _getAIResponse(String userMessage) {
    // Simple AI responses for demo
    final isEnglish = _settingsManager.assistantLanguage == AssistantLanguage.english;

    final responses = isEnglish ? [
      "Hello! How can I help you today?",
      "I'm here to assist you with browsing and web-related tasks.",
      "That's an interesting question. Let me think about that...",
      "I can help you navigate, search, or answer questions about web content.",
      "Feel free to ask me anything about your browsing experience!",
    ] : [
      "Ahoj! Jak vám mohu pomoci dnes?",
      "Jsem zde, abych vám pomohl s prohlížením a webovými úkoly.",
      "To je zajímavá otázka. Nech mě přemýšlet...",
      "Mohu vám pomoci s navigací, vyhledáváním nebo odpovědět na otázky o webovém obsahu.",
      "Neváhejte se mě zeptat na cokoliv ohledně vašeho prohlížení!",
    ];

    if (userMessage.toLowerCase().contains('hello') || userMessage.toLowerCase().contains('hi') ||
        userMessage.toLowerCase().contains('ahoj') || userMessage.toLowerCase().contains('čau')) {
      return isEnglish
          ? "Hi there! How can I help you with your browsing today?"
          : "Ahoj! Jak vám mohu pomoci s prohlížením dnes?";
    } else if (userMessage.toLowerCase().contains('search') || userMessage.toLowerCase().contains('find') ||
               userMessage.toLowerCase().contains('hledej') || userMessage.toLowerCase().contains('najdi')) {
      return isEnglish
          ? "I can help you search! Try using the Google button or typing in the address bar."
          : "Mohu vám pomoci s vyhledáváním! Zkuste použít tlačítko Google nebo psát do adresního řádku.";
    } else if (userMessage.toLowerCase().contains('bookmark') || userMessage.toLowerCase().contains('záložka')) {
      return isEnglish
          ? "You can add bookmarks using the bookmark button in the toolbar!"
          : "Záložky můžete přidat pomocí tlačítka záložek na panelu nástrojů!";
    } else {
      return responses[DateTime.now().millisecondsSinceEpoch % responses.length];
    }
  }

  Future<void> addTabContext(List<TabInfo> selectedTabs) async {
    final currentText = _chatController.text;
    final mentions = <String>[];

    for (final tab in selectedTabs) {
      try {
        final content = await extractWebsiteContent(tab.controller);
        final fullTabName = tab.title.isNotEmpty ? tab.title : 'New Tab';
        final shortTabName = _createShortTabName(fullTabName);

        // Store tab context using the full name as key for context, but use short name for mentions
        _tabContexts[fullTabName] = {
          'id': tab.id,
          'url': tab.url,
          'title': tab.title,
          'content': content,
          'shortName': shortTabName,
          'timestamp': DateTime.now().toIso8601String(),
        };

        mentions.add('@$shortTabName');
      } catch (e) {
        debugPrint('Error extracting content from tab ${tab.title}: $e');
        final fullTabName = tab.title.isNotEmpty ? tab.title : 'New Tab';
        final shortTabName = _createShortTabName(fullTabName);

        // Store error context
        _tabContexts[fullTabName] = {
          'id': tab.id,
          'url': tab.url,
          'title': tab.title,
          'content': 'Failed to extract content from this tab.',
          'shortName': shortTabName,
          'timestamp': DateTime.now().toIso8601String(),
        };

        mentions.add('@$shortTabName');
      }
    }

    // Add mentions to input field
    final mentionText = mentions.join(' ');
    final newText = currentText.isEmpty ? mentionText : '$currentText $mentionText';
    _chatController.text = newText;
    _chatController.selection = TextSelection.fromPosition(
      TextPosition(offset: _chatController.text.length),
    );
  }

  Future<void> addContextNodeContext(List<ContextNode> selectedNodes) async {
    final currentText = _chatController.text;
    final mentions = <String>[];

    for (final node in selectedNodes) {
      try {
        // Extract content from the node's URL using web scraping
        final content = await _extractNodeContent(node.url);
        final fullNodeName = node.title.isNotEmpty ? node.title : 'Context Node';
        final shortNodeName = _createShortTabName(fullNodeName);

        // Store context node context using the full name as key for context, but use short name for mentions
        _tabContexts[fullNodeName] = {
          'id': node.url, // Use URL as ID for context nodes
          'url': node.url,
          'title': node.title,
          'content': content,
          'shortName': shortNodeName,
          'timestamp': node.visitedAt.toIso8601String(),
          'isContextNode': true, // Mark as context node
        };

        mentions.add('@$shortNodeName');
      } catch (e) {
        debugPrint('Error extracting content from context node ${node.title}: $e');
        final fullNodeName = node.title.isNotEmpty ? node.title : 'Context Node';
        final shortNodeName = _createShortTabName(fullNodeName);

        // Store error context
        _tabContexts[fullNodeName] = {
          'id': node.url,
          'url': node.url,
          'title': node.title,
          'content': 'Failed to extract content from this context node.',
          'shortName': shortNodeName,
          'timestamp': node.visitedAt.toIso8601String(),
          'isContextNode': true,
        };

        mentions.add('@$shortNodeName');
      }
    }

    // Add mentions to input field
    final mentionText = mentions.join(' ');
    final newText = currentText.isEmpty ? mentionText : '$currentText $mentionText';
    _chatController.text = newText;
    _chatController.selection = TextSelection.fromPosition(
      TextPosition(offset: _chatController.text.length),
    );
  }

  Future<String> _extractNodeContent(String url) async {
    try {
      final client = http.Client();
      final response = await client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return _extractWebsiteInfo(response.body, url);
      } else {
        return 'Unable to access the website at $url (HTTP ${response.statusCode}).';
      }
    } catch (e) {
      debugPrint('Error fetching context node content: $e');
      return 'Error extracting content from $url.';
    }
  }

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

  String _extractTitle(String content) {
    try {
      final titleMatch = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(content);
      return titleMatch?.group(1)?.trim() ?? '';
    } catch (e) {
      return 'Unknown title';
    }
  }

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

  String _createShortTabName(String fullName) {
    // Create a short name by taking first word or first 15 characters
    final words = fullName.split(' ');
    if (words.length > 1 && words[0].length <= 15) {
      return words[0];
    }
    return fullName.length > 15 ? fullName.substring(0, 15) : fullName;
  }

  String _expandTabMentions(String message) {
    String expandedMessage = message;

    // Find all @ mentions in the message
    final mentionRegex = RegExp(r'@([^\s@]+)');
    final matches = mentionRegex.allMatches(message);

    for (final match in matches) {
      final shortTabName = match.group(1);
      if (shortTabName != null) {
        // Find the full tab name that has this short name
        String? fullTabName;
        for (final entry in _tabContexts.entries) {
          if (entry.value['shortName'] == shortTabName) {
            fullTabName = entry.key;
            break;
          }
        }

        if (fullTabName != null) {
          final tabContext = _tabContexts[fullTabName];
          final contextText = '''
Tab Context: ${tabContext!['title']}
URL: ${tabContext['url']}

${tabContext['content']}

---
''';
          // Replace the @mention with the full context
          expandedMessage = expandedMessage.replaceFirst('@$shortTabName', contextText);
        }
      }
    }

    return expandedMessage;
  }

  void dispose() {
    cancelStreaming(); // Cancel any ongoing streaming
    _chatController.dispose();
    _chatScrollController.dispose();
  }
}

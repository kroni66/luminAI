import 'dart:async';
import 'package:ollama_dart/ollama_dart.dart';
import 'package:flutter/foundation.dart';

class OllamaService {
  static const String defaultModel = 'gpt-oss:20b';
  static const String defaultBaseUrl = 'http://localhost:11434';
  
  OllamaClient? _client;
  String _baseUrl = defaultBaseUrl;
  String _model = defaultModel;
  bool _isConnected = false;
  
  // Getters
  String get baseUrl => _baseUrl;
  String get model => _model;
  bool get isConnected => _isConnected;
  
  // Initialize the Ollama client
  void initialize({String? baseUrl, String? model}) {
    _baseUrl = baseUrl ?? defaultBaseUrl;
    _model = model ?? defaultModel;
 
    try {
      // Ensure the base URL includes /api path for correct endpoint access
      String apiBaseUrl = _baseUrl;
      if (!apiBaseUrl.endsWith('/api')) {
        apiBaseUrl = '$apiBaseUrl/api';
      }
      
      _client = OllamaClient(
        baseUrl: apiBaseUrl,
      );
      debugPrint('Ollama client initialized with API base URL: $apiBaseUrl (will use $apiBaseUrl/tags)');
    } catch (e) {
      debugPrint('Failed to initialize Ollama client: $e');
      _client = null;
    }
  }
  
  // Test connection to Ollama server
  Future<bool> testConnection() async {
    if (_client == null) {
      initialize();
    }
    
    try {
      debugPrint('Testing connection to Ollama server at $_baseUrl/api/tags');
      
      // Use listModels which calls /api/tags endpoint
      final models = await _client!.listModels();
      _isConnected = true;
      final modelCount = models.models?.length ?? 0;
      debugPrint('Successfully connected to Ollama server via /api/tags. Found $modelCount models.');
      
      if (modelCount == 0) {
        debugPrint('Warning: No models found. You may need to pull a model first with: ollama pull <model-name>');
      }
      
      return true;
    } catch (e) {
      _isConnected = false;
      debugPrint('Failed to connect to Ollama server: $e');
      
      // Provide specific error messages based on the error type
      if (e.toString().contains('404')) {
        debugPrint('Ollama API endpoint not found at: $_baseUrl/api/tags');
        debugPrint('Make sure Ollama is installed and running with: ollama serve');
        debugPrint('Test manually with: curl $_baseUrl/api/tags');
      } else if (e.toString().contains('Connection refused') || e.toString().contains('Failed to connect')) {
        debugPrint('Cannot connect to Ollama server. Make sure it\'s running on $_baseUrl');
        debugPrint('Start Ollama with: ollama serve');
      } else if (e.toString().contains('SocketException')) {
        debugPrint('Network error: Cannot reach Ollama server at $_baseUrl');
      }
      
      return false;
    }
  }
  
  // Check if model is available
  Future<bool> isModelAvailable() async {
    if (_client == null || !_isConnected) {
      return false;
    }
    
    try {
      final models = await _client!.listModels();
      final availableModels = models.models?.map((m) => m.model ?? '') ?? [];
      final isAvailable = availableModels.contains(_model);
      
      if (!isAvailable) {
        debugPrint('Model $_model not found. Available models: $availableModels');
      }
      
      return isAvailable;
    } catch (e) {
      debugPrint('Failed to check model availability: $e');
      return false;
    }
  }
  
  // Get list of available models
  Future<List<String>> getAvailableModels() async {
    if (_client == null || !_isConnected) {
      return [];
    }
    
    try {
      final models = await _client!.listModels();
      return models.models?.map((m) => m.model ?? '').where((name) => name.isNotEmpty).toList() ?? [];
    } catch (e) {
      debugPrint('Failed to get available models: $e');
      return [];
    }
  }
  
  // Generate chat completion
  Future<String> generateChatResponse(String userMessage, List<Map<String, String>> chatHistory, {String? imageData}) async {
    if (_client == null || !_isConnected) {
      return 'Error: Not connected to Ollama server. Please check your connection in Settings > AI.';
    }
    
    try {
      // Convert chat history to Ollama messages format
      final messages = <Message>[
        Message(
          role: MessageRole.system,
          content: 'You are LUMIN, a helpful AI assistant integrated into a web browser. You can help users with browsing, searching, and answering questions. Be concise and helpful.',
        ),
      ];
      
      // Add chat history
      for (final entry in chatHistory) {
        if (entry['sender'] == 'user') {
          messages.add(Message(
            role: MessageRole.user,
            content: entry['message'] ?? '',
          ));
        } else if (entry['sender'] == 'ai') {
          messages.add(Message(
            role: MessageRole.assistant,
            content: entry['message'] ?? '',
          ));
        }
      }
      
      // Add current user message
      messages.add(Message(
        role: MessageRole.user,
        content: userMessage,
      ));
      
      final response = await _client!.generateChatCompletion(
        request: GenerateChatCompletionRequest(
          model: _model,
          messages: messages,
          keepAlive: 1, // Keep model loaded for faster responses
        ),
      );
      
      return response.message.content;
    } catch (e) {
      debugPrint('Failed to generate chat response: $e');
      if (e.toString().contains('model')) {
        return 'Error: Model "$_model" not found. Please check if the model is installed and available in Settings > AI.';
      }
      return 'Error: Failed to generate response. Please check your Ollama connection.';
    }
  }
  
  // Generate streaming chat response
  Stream<String> generateChatResponseStream(String userMessage, List<Map<String, String>> chatHistory, {String? imageData}) async* {
    if (_client == null || !_isConnected) {
      yield 'Error: Not connected to Ollama server. Please check your connection in Settings > AI.';
      return;
    }
    
    try {
      // Convert chat history to Ollama messages format
      final messages = <Message>[
        Message(
          role: MessageRole.system,
          content: 'You are LUMIN, a helpful AI assistant integrated into a web browser. You can help users with browsing, searching, and answering questions. Be concise and helpful.',
        ),
      ];
      
      // Add chat history
      for (final entry in chatHistory) {
        if (entry['sender'] == 'user') {
          messages.add(Message(
            role: MessageRole.user,
            content: entry['message'] ?? '',
          ));
        } else if (entry['sender'] == 'ai') {
          messages.add(Message(
            role: MessageRole.assistant,
            content: entry['message'] ?? '',
          ));
        }
      }
      
      // Add current user message
      messages.add(Message(
        role: MessageRole.user,
        content: userMessage,
      ));
      
      final stream = _client!.generateChatCompletionStream(
        request: GenerateChatCompletionRequest(
          model: _model,
          messages: messages,
          keepAlive: 1,
        ),
      );

      try {
        await for (final response in stream) {
          final content = response.message.content;
          if (content.isNotEmpty) {
            yield content;
          }
        }
        debugPrint('Ollama: Stream completed normally');
      } catch (e) {
        debugPrint('Ollama: Stream error: $e');
        rethrow; // Re-throw so it gets caught by the outer catch block
      }
    } catch (e) {
      debugPrint('Failed to generate streaming chat response: $e');
      if (e.toString().contains('model')) {
        yield 'Error: Model "$_model" not found. Please check if the model is installed and available in Settings > AI.';
      } else {
        yield 'Error: Failed to generate response. Please check your Ollama connection.';
      }
      return; // Properly end the stream on error
    }
  }
  
  // Get detailed connection status
  Future<String> getConnectionStatus() async {
    if (_client == null) {
      return 'Ollama client not initialized';
    }
    
    try {
      final models = await _client!.listModels();
      final modelCount = models.models?.length ?? 0;
      return 'Connected to Ollama server via /api/tags\nFound $modelCount models available';
    } catch (e) {
      if (e.toString().contains('404')) {
        return 'Ollama API not found at $_baseUrl/api/tags\n\nTroubleshooting:\n• Make sure Ollama is installed\n• Start Ollama server: "ollama serve"\n• Test: curl $_baseUrl/api/tags';
      } else if (e.toString().contains('Connection refused') || e.toString().contains('Failed to connect')) {
        return 'Cannot connect to Ollama server at $_baseUrl\n\nTroubleshooting:\n• Start Ollama: "ollama serve"\n• Check firewall settings\n• Verify the URL is correct';
      } else {
        return 'Connection error: ${e.toString()}';
      }
    }
  }
  
  // Update configuration
  void updateConfiguration({String? baseUrl, String? model}) {
    if (baseUrl != null && baseUrl != _baseUrl) {
      _baseUrl = baseUrl;
      _isConnected = false; // Reset connection status
      initialize(); // Reinitialize with new base URL
    }
    
    if (model != null) {
      _model = model;
    }
  }
  
  // Dispose resources
  void dispose() {
    _client = null;
    _isConnected = false;
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class OpenRouterService {
  static const String defaultModel = 'openai/gpt-4o'; // Vision-capable model
  static const String apiBaseUrl = 'https://openrouter.ai/api/v1';

  String _apiKey = '';
  String _model = defaultModel;
  bool _isConnected = false;

  // Getters
  String get apiKey => _apiKey;
  String get model => _model;
  bool get isConnected => _isConnected;

  // Initialize the OpenRouter client
  void initialize({String? apiKey, String? model}) {
    _apiKey = apiKey ?? '';
    _model = model ?? defaultModel;

    debugPrint('OpenRouter service initialized with model: $_model');
  }

  // Test connection to OpenRouter API
  Future<bool> testConnection() async {
    if (_apiKey.isEmpty) {
      _isConnected = false;
      return false;
    }

    try {
      debugPrint('Testing connection to OpenRouter API');

      final response = await http.get(
        Uri.parse('$apiBaseUrl/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _isConnected = true;
        final data = jsonDecode(response.body);
        final modelCount = (data['data'] as List?)?.length ?? 0;
        debugPrint('Successfully connected to OpenRouter API. Found $modelCount models.');
        return true;
      } else {
        _isConnected = false;
        debugPrint('OpenRouter API returned status ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      _isConnected = false;
      debugPrint('Failed to connect to OpenRouter API: $e');
      return false;
    }
  }

  // Check if model is available
  Future<bool> isModelAvailable() async {
    if (_apiKey.isEmpty || !_isConnected) {
      return false;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['data'] as List?)?.map((m) => m['id'] as String?) ?? [];
        final isAvailable = models.contains(_model);

        if (!isAvailable) {
          debugPrint('Model $_model not found. Available models: $models');
        }

        return isAvailable;
      }
      return false;
    } catch (e) {
      debugPrint('Failed to check model availability: $e');
      return false;
    }
  }

  // Get list of available models
  Future<List<String>> getAvailableModels() async {
    if (_apiKey.isEmpty || !_isConnected) {
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['data'] as List?)
            ?.map((m) => m['id'] as String?)
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toList() ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('Failed to get available models: $e');
      return [];
    }
  }

  // Generate chat completion with optional image support
  Future<String> generateChatResponse(String userMessage, List<Map<String, String>> chatHistory, {String? imageData}) async {
    if (_apiKey.isEmpty || !_isConnected) {
      return 'Error: OpenRouter API key not configured or not connected. Please check your settings in Settings > AI.';
    }

    try {
      // Convert chat history to OpenRouter messages format
      final messages = <Map<String, dynamic>>[
        {
          'role': 'system',
          'content': 'You are LUMIN, a helpful AI assistant integrated into a web browser. You can help users with browsing, searching, and answering questions. Be concise and helpful.',
        },
      ];

      // Add chat history
      for (final entry in chatHistory) {
        if (entry['sender'] == 'user') {
          messages.add({
            'role': 'user',
            'content': entry['message'] ?? '',
          });
        } else if (entry['sender'] == 'ai') {
          messages.add({
            'role': 'assistant',
            'content': entry['message'] ?? '',
          });
        }
      }

      // Add current user message (if not already in history)
      bool messageExists = chatHistory.any((entry) => entry['sender'] == 'user' && entry['message'] == userMessage);
      if (!messageExists) {
        messages.add({
          'role': 'user',
          'content': userMessage,
        });
      }

      final response = await http.post(
        Uri.parse('$apiBaseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/browser2/browser2', // Optional, for rankings
          'X-Title': 'Browser2', // Optional, for rankings
        },
        body: jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 2048,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices']?[0]?['message']?['content'] ?? 'No response generated';
      } else {
        debugPrint('OpenRouter API error: ${response.statusCode} - ${response.body}');
        return 'Error: Failed to generate response from OpenRouter API.';
      }
    } catch (e) {
      debugPrint('Failed to generate chat response: $e');
      return 'Error: Failed to generate response. Please check your OpenRouter API key and internet connection.';
    }
  }

  // Generate streaming chat response with optional image support
  Stream<String> generateChatResponseStream(String userMessage, List<Map<String, String>> chatHistory, {String? imageData}) async* {
    if (_apiKey.isEmpty || !_isConnected) {
      yield 'Error: OpenRouter API key not configured or not connected. Please check your settings in Settings > AI.';
      return;
    }

    try {
      // Convert chat history to OpenRouter messages format
      final messages = <Map<String, dynamic>>[
        {
          'role': 'system',
          'content': 'You are LUMIN, a helpful AI assistant integrated into a web browser. You can help users with browsing, searching, and answering questions. Be concise and helpful.',
        },
      ];

      // Add chat history
      for (final entry in chatHistory) {
        if (entry['sender'] == 'user') {
          messages.add({
            'role': 'user',
            'content': entry['message'] ?? '',
          });
        } else if (entry['sender'] == 'ai') {
          messages.add({
            'role': 'assistant',
            'content': entry['message'] ?? '',
          });
        }
      }

      // If we have image data for the current message, modify the last user message to include it
      if (imageData != null && messages.isNotEmpty) {
        for (int i = messages.length - 1; i >= 0; i--) {
          if (messages[i]['role'] == 'user') {
            debugPrint('OpenRouter: Modifying last user message to include image');
            debugPrint('OpenRouter: Original message: ${messages[i]}');
            debugPrint('OpenRouter: Image data preview: ${imageData.substring(0, 100)}...');
            messages[i] = {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': messages[i]['content']},
                {'type': 'image_url', 'image_url': {'url': imageData}}
              ],
            };
            debugPrint('OpenRouter: Modified message: ${messages[i]}');
            break;
          }
        }
      }

      // Add current user message (if not already in history)
      bool messageExists = chatHistory.any((entry) => entry['sender'] == 'user' && entry['message'] == userMessage);
      if (!messageExists) {
        messages.add({
          'role': 'user',
          'content': userMessage,
        });
      }

      final request = http.Request('POST', Uri.parse('$apiBaseUrl/chat/completions'))
        ..headers.addAll({
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/browser2/browser2',
          'X-Title': 'Browser2',
        })
        ..body = jsonEncode({
          'model': _model,
          'messages': messages,
          'temperature': 0.7,
          'max_tokens': 2048,
          'stream': true,
        });

      final client = http.Client();
      final streamedResponse = await client.send(request);
      final stream = streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter());

      try {
        bool streamEnded = false;
        await for (final line in stream) {
          // Skip empty lines
          if (line.trim().isEmpty) continue;

          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data.isEmpty) continue;

            if (data == '[DONE]') {
              debugPrint('OpenRouter: Received [DONE], ending stream');
              streamEnded = true;
              break; // Exit the loop instead of return
            }

            try {
              final jsonData = jsonDecode(data);
              final delta = jsonData['choices']?[0]?['delta']?['content'];
              if (delta != null && delta.isNotEmpty) {
                yield delta;
              }
            } catch (e) {
              debugPrint('OpenRouter: Failed to parse JSON: $data, error: $e');
              // Skip malformed JSON lines
              continue;
            }
          } else {
            debugPrint('OpenRouter: Ignoring non-data line: $line');
          }
        }

        debugPrint('OpenRouter: Stream processing ended, streamEnded: $streamEnded');
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Failed to generate streaming chat response: $e');
      yield 'Error: Failed to generate response. Please check your OpenRouter API key and internet connection.';
      return; // Properly end the stream on error
    }
  }

  // Get detailed connection status
  Future<String> getConnectionStatus() async {
    if (_apiKey.isEmpty) {
      return 'OpenRouter API key not configured\n\nPlease add your API key in Settings > AI > OpenRouter';
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final modelCount = (data['data'] as List?)?.length ?? 0;
        return 'Connected to OpenRouter API\nFound $modelCount models available\nCurrent model: $_model';
      } else if (response.statusCode == 401) {
        return 'Invalid OpenRouter API key\n\nPlease check your API key in Settings > AI > OpenRouter';
      } else {
        return 'OpenRouter API error: ${response.statusCode}\n${response.body}';
      }
    } catch (e) {
      return 'Connection error: ${e.toString()}\n\nPlease check your internet connection and API key';
    }
  }

  // Update configuration
  void updateConfiguration({String? apiKey, String? model}) {
    if (apiKey != null && apiKey != _apiKey) {
      _apiKey = apiKey;
      _isConnected = false; // Reset connection status when API key changes
    }

    if (model != null) {
      _model = model;
    }
  }

  // Dispose resources
  void dispose() {
    _isConnected = false;
  }
}

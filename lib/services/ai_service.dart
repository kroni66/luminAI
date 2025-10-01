import 'dart:async';
import 'ollama_service.dart';
import 'openrouter_service.dart';
import 'settings_manager.dart';

class AIService {
  final OllamaService _ollamaService;
  final OpenRouterService _openRouterService;
  final SettingsManager _settingsManager;

  AIService(this._ollamaService, this._openRouterService, this._settingsManager);

  // Get the current active service based on provider setting
  dynamic get _currentService {
    return _settingsManager.aiProvider == AIProvider.ollama
        ? _ollamaService
        : _openRouterService;
  }

  // Unified interface methods
  Future<bool> testConnection() async {
    return await _currentService.testConnection();
  }

  Future<String> getConnectionStatus() async {
    return await _currentService.getConnectionStatus();
  }

  Future<String> generateChatResponse(String userMessage, List<Map<String, String>> chatHistory, {String? imageData}) async {
    return await _currentService.generateChatResponse(userMessage, chatHistory, imageData: imageData);
  }

  Stream<String> generateChatResponseStream(String userMessage, List<Map<String, String>> chatHistory, {String? imageData}) async* {
    yield* _currentService.generateChatResponseStream(userMessage, chatHistory, imageData: imageData);
  }

  bool get isConnected => _currentService.isConnected;

  // Provider-specific methods for settings
  void updateOllamaConfiguration({String? baseUrl, String? model}) {
    _ollamaService.updateConfiguration(baseUrl: baseUrl, model: model);
  }

  void updateOpenRouterConfiguration({String? apiKey, String? model}) {
    _openRouterService.updateConfiguration(apiKey: apiKey, model: model);
  }
}

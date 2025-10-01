import 'dart:async';
import 'package:flutter/material.dart';
import 'ollama_service.dart';
import 'adblock_service.dart';
import '../database_helper.dart';

enum AssistantLanguage {
  english,
  czech,
}

enum AppTheme {
  dark,
  light,
  system,
}

enum AIProvider {
  ollama,
  openrouter,
}

class SettingsManager {
  // Scroll settings
  double _mouseSensitivity = 0.1; // Single scroll speed value - lower = more sensitive scrolling (smaller steps per wheel click)
  bool _smoothScrolling = true;

  // Advanced scroll physics settings
  double _scrollFriction = 0.85;     // Momentum friction (0.0-1.0, lower = more momentum)
  double _scrollDeceleration = 0.92; // Deceleration rate (0.0-1.0, lower = faster stop)
  double _scrollMinVelocity = 0.1;   // Minimum velocity to continue scrolling
  double _scrollMaxVelocity = 30.0;  // Maximum scroll velocity

  // AI Settings
  AIProvider _aiProvider = AIProvider.ollama;
  String _ollamaBaseUrl = OllamaService.defaultBaseUrl;
  String _ollamaModel = OllamaService.defaultModel;
  String _openRouterApiKey = '';
  String _openRouterModel = 'x-ai/grok-4-fast';

  // Ad blocking
  bool _adBlockingEnabled = true;

  // AI Assistant language
  AssistantLanguage _assistantLanguage = AssistantLanguage.english;

  // AI Tool mode (whether AI can use browser automation tools)
  bool _toolModeEnabled = false;

  // Theme settings
  AppTheme _appTheme = AppTheme.dark;

  // Download settings
  String? _defaultDownloadDirectory;
  int _maxConcurrentDownloads = 3;
  bool _showDownloadNotifications = true;

  // Window size settings
  double _windowWidth = 1280.0;
  double _windowHeight = 800.0;

  // Update settings
  bool _autoCheckForUpdates = true;
  Duration _updateCheckInterval = const Duration(hours: 24);
  bool _autoDownloadUpdates = false;
  bool _showUpdateNotifications = true;
  DateTime? _lastUpdateCheck;

  // Services
  final OllamaService ollamaService;
  final AdBlockService adBlockService;
  final DatabaseHelper _dbHelper;

  // Callbacks
  VoidCallback? onSettingsChanged;

  SettingsManager({
    required this.ollamaService,
    required this.adBlockService,
    required DatabaseHelper dbHelper,
  }) : _dbHelper = dbHelper;

  // Getters
  double get mouseSensitivity => _mouseSensitivity;
  double get trackpadSensitivity => _mouseSensitivity; // Use same value for compatibility
  bool get smoothScrolling => _smoothScrolling;

  // Advanced scroll physics getters
  double get scrollFriction => _scrollFriction;
  double get scrollDeceleration => _scrollDeceleration;
  double get scrollMinVelocity => _scrollMinVelocity;
  double get scrollMaxVelocity => _scrollMaxVelocity;
  AIProvider get aiProvider => _aiProvider;
  String get ollamaBaseUrl => _ollamaBaseUrl;
  String get ollamaModel => _ollamaModel;
  String get openRouterApiKey => _openRouterApiKey;
  String get openRouterModel => _openRouterModel;
  bool get adBlockingEnabled => _adBlockingEnabled;
  AssistantLanguage get assistantLanguage => _assistantLanguage;
  bool get toolModeEnabled => _toolModeEnabled;
  AppTheme get appTheme => _appTheme;

  // Download settings getters
  String? get defaultDownloadDirectory => _defaultDownloadDirectory;
  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  bool get showDownloadNotifications => _showDownloadNotifications;

  // Update settings getters
  bool get autoCheckForUpdates => _autoCheckForUpdates;
  Duration get updateCheckInterval => _updateCheckInterval;
  bool get autoDownloadUpdates => _autoDownloadUpdates;
  bool get showUpdateNotifications => _showUpdateNotifications;
  DateTime? get lastUpdateCheck => _lastUpdateCheck;

  // Window size getters
  double get windowWidth => _windowWidth;
  double get windowHeight => _windowHeight;

  Future<void> initialize() async {
    await _initializeOllama();
    await _initializeOpenRouter();
    await _initializeAdBlock();
    await _loadSettingsFromDatabase();
  }

  Future<void> _initializeOllama() async {
    ollamaService.initialize(
      baseUrl: _ollamaBaseUrl,
      model: _ollamaModel,
    );
    // Test connection in background
    ollamaService.testConnection();
  }

  Future<void> _initializeOpenRouter() async {
    // OpenRouter service will be initialized later with loaded settings
    // This is a placeholder for consistency with Ollama initialization
  }

  Future<void> _initializeAdBlock() async {
    await adBlockService.initialize(enabled: _adBlockingEnabled);
  }

  Future<void> _loadSettingsFromDatabase() async {
    try {
      // Load assistant language
      final languageValue = await _dbHelper.getSetting('assistant_language');
      if (languageValue != null) {
        if (languageValue == 'english') {
          _assistantLanguage = AssistantLanguage.english;
        } else if (languageValue == 'czech') {
          _assistantLanguage = AssistantLanguage.czech;
        }
      }

      // Load other settings as needed
      final mouseSensitivityValue = await _dbHelper.getSetting('mouse_sensitivity');
      if (mouseSensitivityValue != null) {
        _mouseSensitivity = double.tryParse(mouseSensitivityValue) ?? _mouseSensitivity;
      }

      final smoothScrollingValue = await _dbHelper.getSetting('smooth_scrolling');
      if (smoothScrollingValue != null) {
        _smoothScrolling = smoothScrollingValue == 'true';
      }

      // Load advanced scroll physics settings
      final scrollFrictionValue = await _dbHelper.getSetting('scroll_friction');
      if (scrollFrictionValue != null) {
        _scrollFriction = double.tryParse(scrollFrictionValue) ?? _scrollFriction;
      }

      final scrollDecelerationValue = await _dbHelper.getSetting('scroll_deceleration');
      if (scrollDecelerationValue != null) {
        _scrollDeceleration = double.tryParse(scrollDecelerationValue) ?? _scrollDeceleration;
      }

      final scrollMinVelocityValue = await _dbHelper.getSetting('scroll_min_velocity');
      if (scrollMinVelocityValue != null) {
        _scrollMinVelocity = double.tryParse(scrollMinVelocityValue) ?? _scrollMinVelocity;
      }

      final scrollMaxVelocityValue = await _dbHelper.getSetting('scroll_max_velocity');
      if (scrollMaxVelocityValue != null) {
        _scrollMaxVelocity = double.tryParse(scrollMaxVelocityValue) ?? _scrollMaxVelocity;
      }

      final ollamaBaseUrlValue = await _dbHelper.getSetting('ollama_base_url');
      if (ollamaBaseUrlValue != null) {
        _ollamaBaseUrl = ollamaBaseUrlValue;
      }

      final ollamaModelValue = await _dbHelper.getSetting('ollama_model');
      if (ollamaModelValue != null) {
        _ollamaModel = ollamaModelValue;
      }

      final aiProviderValue = await _dbHelper.getSetting('ai_provider');
      if (aiProviderValue != null) {
        if (aiProviderValue == 'openrouter') {
          _aiProvider = AIProvider.openrouter;
        } else {
          _aiProvider = AIProvider.ollama;
        }
      }

      final openRouterApiKeyValue = await _dbHelper.getSetting('openrouter_api_key');
      if (openRouterApiKeyValue != null) {
        _openRouterApiKey = openRouterApiKeyValue;
      }

      final openRouterModelValue = await _dbHelper.getSetting('openrouter_model');
      if (openRouterModelValue != null) {
        _openRouterModel = openRouterModelValue;
      }

      final adBlockingEnabledValue = await _dbHelper.getSetting('ad_blocking_enabled');
      if (adBlockingEnabledValue != null) {
        _adBlockingEnabled = adBlockingEnabledValue == 'true';
      }

      // Load tool mode setting
      final toolModeEnabledValue = await _dbHelper.getSetting('tool_mode_enabled');
      if (toolModeEnabledValue != null) {
        _toolModeEnabled = toolModeEnabledValue == 'true';
      }

      // Load theme setting
      final appThemeValue = await _dbHelper.getSetting('app_theme');
      if (appThemeValue != null) {
        if (appThemeValue == 'light') {
          _appTheme = AppTheme.light;
        } else if (appThemeValue == 'system') {
          _appTheme = AppTheme.system;
        } else {
          _appTheme = AppTheme.dark;
        }
      }

      // Load window size settings
      final windowWidthValue = await _dbHelper.getSetting('window_width');
      if (windowWidthValue != null) {
        _windowWidth = double.tryParse(windowWidthValue) ?? _windowWidth;
      }

      final windowHeightValue = await _dbHelper.getSetting('window_height');
      if (windowHeightValue != null) {
        _windowHeight = double.tryParse(windowHeightValue) ?? _windowHeight;
      }

      // Load update settings
      final autoCheckForUpdatesValue = await _dbHelper.getSetting('auto_check_for_updates');
      if (autoCheckForUpdatesValue != null) {
        _autoCheckForUpdates = autoCheckForUpdatesValue == 'true';
      }

      final updateCheckIntervalValue = await _dbHelper.getSetting('update_check_interval_hours');
      if (updateCheckIntervalValue != null) {
        final hours = int.tryParse(updateCheckIntervalValue) ?? 24;
        _updateCheckInterval = Duration(hours: hours);
      }

      final autoDownloadUpdatesValue = await _dbHelper.getSetting('auto_download_updates');
      if (autoDownloadUpdatesValue != null) {
        _autoDownloadUpdates = autoDownloadUpdatesValue == 'true';
      }

      final showUpdateNotificationsValue = await _dbHelper.getSetting('show_update_notifications');
      if (showUpdateNotificationsValue != null) {
        _showUpdateNotifications = showUpdateNotificationsValue == 'true';
      }

      final lastUpdateCheckValue = await _dbHelper.getSetting('last_update_check');
      if (lastUpdateCheckValue != null) {
        _lastUpdateCheck = DateTime.tryParse(lastUpdateCheckValue);
      }

      debugPrint('Settings loaded from database');
    } catch (e) {
      debugPrint('Error loading settings from database: $e');
    }
  }

  void updateScrollSettings({
    double? scrollSpeed,
    bool? smoothScrolling,
  }) {
    if (scrollSpeed != null) _mouseSensitivity = scrollSpeed;
    if (smoothScrolling != null) _smoothScrolling = smoothScrolling;

    onSettingsChanged?.call();
  }

  void updateScrollPhysics({
    double? friction,
    double? deceleration,
    double? minVelocity,
    double? maxVelocity,
  }) {
    if (friction != null) _scrollFriction = friction.clamp(0.0, 1.0);
    if (deceleration != null) _scrollDeceleration = deceleration.clamp(0.0, 1.0);
    if (minVelocity != null) _scrollMinVelocity = minVelocity.clamp(0.0, 10.0);
    if (maxVelocity != null) _scrollMaxVelocity = maxVelocity.clamp(10.0, 200.0);

    onSettingsChanged?.call();
  }

  void updateAISettings({
    String? baseUrl,
    String? model,
  }) {
    if (baseUrl != null) _ollamaBaseUrl = baseUrl;
    if (model != null) _ollamaModel = model;

    ollamaService.updateConfiguration(
      baseUrl: baseUrl ?? _ollamaBaseUrl,
      model: model ?? _ollamaModel,
    );

    onSettingsChanged?.call();
  }

  Future<void> updateAIProviderSettings({
    AIProvider? provider,
    String? openRouterApiKey,
    String? openRouterModel,
  }) async {
    if (provider != null) _aiProvider = provider;
    if (openRouterApiKey != null) _openRouterApiKey = openRouterApiKey;
    if (openRouterModel != null) _openRouterModel = openRouterModel;

    // Save to database
    try {
      final providerValue = _aiProvider == AIProvider.openrouter ? 'openrouter' : 'ollama';
      await _dbHelper.setSetting('ai_provider', providerValue);

      if (openRouterApiKey != null) {
        await _dbHelper.setSetting('openrouter_api_key', openRouterApiKey);
      }

      if (openRouterModel != null) {
        await _dbHelper.setSetting('openrouter_model', openRouterModel);
      }

      debugPrint('AI provider settings saved to database');
    } catch (e) {
      debugPrint('Error saving AI provider settings to database: $e');
    }

    onSettingsChanged?.call();
  }

  Future<void> updateAdBlockSettings(bool enabled) async {
    _adBlockingEnabled = enabled;

    await adBlockService.setEnabled(enabled);

    onSettingsChanged?.call();
  }

  Future<void> updateAssistantLanguage(AssistantLanguage language) async {
    _assistantLanguage = language;

    // Save to database
    try {
      final languageValue = language == AssistantLanguage.english ? 'english' : 'czech';
      await _dbHelper.setSetting('assistant_language', languageValue);
      debugPrint('Assistant language saved to database: $languageValue');
    } catch (e) {
      debugPrint('Error saving assistant language to database: $e');
    }

    onSettingsChanged?.call();
  }

  Future<void> updateToolModeEnabled(bool enabled) async {
    _toolModeEnabled = enabled;

    // Save to database
    try {
      await _dbHelper.setSetting('tool_mode_enabled', enabled.toString());
      debugPrint('Tool mode setting saved to database: $enabled');
    } catch (e) {
      debugPrint('Error saving tool mode setting to database: $e');
    }

    onSettingsChanged?.call();
  }

  Future<void> updateAppTheme(AppTheme theme) async {
    _appTheme = theme;

    // Save to database
    try {
      String themeValue;
      switch (theme) {
        case AppTheme.light:
          themeValue = 'light';
          break;
        case AppTheme.system:
          themeValue = 'system';
          break;
        case AppTheme.dark:
          themeValue = 'dark';
          break;
      }
      await _dbHelper.setSetting('app_theme', themeValue);
      debugPrint('App theme saved to database: $themeValue');
    } catch (e) {
      debugPrint('Error saving app theme to database: $e');
    }

    onSettingsChanged?.call();
  }

  // Download settings methods
  void updateDefaultDownloadDirectory(String? directory) {
    _defaultDownloadDirectory = directory;
    onSettingsChanged?.call();
  }

  void updateMaxConcurrentDownloads(int maxDownloads) {
    _maxConcurrentDownloads = maxDownloads.clamp(1, 10); // Limit between 1 and 10
    onSettingsChanged?.call();
  }

  void updateShowDownloadNotifications(bool show) {
    _showDownloadNotifications = show;
    onSettingsChanged?.call();
  }

  // Update settings setters
  void updateAutoCheckForUpdates(bool autoCheck) {
    _autoCheckForUpdates = autoCheck;
    onSettingsChanged?.call();
  }

  void updateUpdateCheckInterval(Duration interval) {
    _updateCheckInterval = interval;
    onSettingsChanged?.call();
  }

  void updateAutoDownloadUpdates(bool autoDownload) {
    _autoDownloadUpdates = autoDownload;
    onSettingsChanged?.call();
  }

  void updateShowUpdateNotifications(bool show) {
    _showUpdateNotifications = show;
    onSettingsChanged?.call();
  }

  void updateLastUpdateCheck(DateTime? lastCheck) {
    _lastUpdateCheck = lastCheck;
  }

  // Window size methods
  Future<void> updateWindowSize(double width, double height) async {
    _windowWidth = width;
    _windowHeight = height;

    // Save to database
    try {
      await _dbHelper.setSetting('window_width', width.toString());
      await _dbHelper.setSetting('window_height', height.toString());
      debugPrint('Window size saved to database: ${width}x${height}');
    } catch (e) {
      debugPrint('Error saving window size to database: $e');
    }

    onSettingsChanged?.call();
  }

  // Smooth scrolling setup using CSS scroll-behavior on webview
  String getWebViewSmoothScrollingJavaScript() {
    if (!_smoothScrolling) {
      return '';
    }

    return '''
      // Set up smooth scrolling using CSS scroll-behavior on the webview document
      (function() {
        // Apply smooth scrolling CSS immediately to all scrollable elements
        var style = document.createElement('style');
        style.id = 'browser2-smooth-scroll-style';
        style.textContent = \`
          html, body {
            scroll-behavior: smooth !important;
            -webkit-overflow-scrolling: touch;
            overscroll-behavior: contain;
          }
          * {
            scroll-behavior: smooth !important;
          }
        \`;
        document.head.appendChild(style);

        // Also set styles directly on elements for immediate effect
        document.documentElement.style.scrollBehavior = 'smooth';
        document.body.style.scrollBehavior = 'smooth';
        document.documentElement.style.webkitOverflowScrolling = 'touch';
        document.body.style.webkitOverflowScrolling = 'touch';
        document.documentElement.style.overscrollBehavior = 'contain';
        document.body.style.overscrollBehavior = 'contain';

        console.log('Smooth scrolling enabled via CSS scroll-behavior');
      })();
    ''';
  }

  // Mouse wheel sensitivity control (compatible with CSS scroll-behavior)
  String getWebViewMouseSensitivityJavaScript() {
    final sensitivity = _mouseSensitivity;

    return '''
      // Apply mouse wheel sensitivity control that works with CSS scroll-behavior
      (function() {
        var sensitivity = ${sensitivity};

        // Intercept wheel events to modify delta values for sensitivity
        function handleWheelSensitivity(event) {
          if (!event.deltaY && !event.deltaX) return;

          // Modify delta values based on sensitivity - smaller values = more sensitive (smaller steps)
          event.deltaX *= sensitivity;
          event.deltaY *= sensitivity;

          // Let browser handle the scrolling with CSS scroll-behavior - preserves scrollbar functionality
        }

        // Add wheel event listener (use capturing phase to intercept before CSS scroll-behavior)
        document.addEventListener('wheel', handleWheelSensitivity, { passive: false, capture: true });

        console.log('Mouse wheel sensitivity set to: ' + sensitivity + ' (compatible with CSS scroll-behavior)');
      })();
    ''';
  }

}

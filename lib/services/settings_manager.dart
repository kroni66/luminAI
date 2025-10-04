import 'dart:async';
import 'dart:convert';
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

enum ColorSchemeType {
  zinc,
  slate,
  stone,
  gray,
  neutral,
  red,
  rose,
  orange,
  green,
  blue,
  yellow,
  violet,
}

class ThemeCustomization {
  final ColorSchemeType colorScheme;
  final Color? accentColor;
  final Color? backgroundColor;
  final Color? surfaceColor;

  const ThemeCustomization({
    this.colorScheme = ColorSchemeType.zinc,
    this.accentColor,
    this.backgroundColor,
    this.surfaceColor,
  });

  ThemeCustomization copyWith({
    ColorSchemeType? colorScheme,
    Color? accentColor,
    Color? backgroundColor,
    Color? surfaceColor,
  }) {
    return ThemeCustomization(
      colorScheme: colorScheme ?? this.colorScheme,
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'colorScheme': colorScheme.toString().split('.').last,
      'accentColor': accentColor?.value,
      'backgroundColor': backgroundColor?.value,
      'surfaceColor': surfaceColor?.value,
    };
  }

  factory ThemeCustomization.fromJson(Map<String, dynamic> json) {
    return ThemeCustomization(
      colorScheme: ColorSchemeType.values.firstWhere(
        (e) => e.toString().split('.').last == json['colorScheme'],
        orElse: () => ColorSchemeType.zinc,
      ),
      accentColor: json['accentColor'] != null ? Color(json['accentColor']) : null,
      backgroundColor: json['backgroundColor'] != null ? Color(json['backgroundColor']) : null,
      surfaceColor: json['surfaceColor'] != null ? Color(json['surfaceColor']) : null,
    );
  }
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
  ThemeCustomization _themeCustomization = const ThemeCustomization();

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
  ThemeCustomization get themeCustomization => _themeCustomization;

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

      // Load theme customization
      final themeCustomizationValue = await _dbHelper.getSetting('theme_customization');
      if (themeCustomizationValue != null) {
        try {
          final json = jsonDecode(themeCustomizationValue);
          _themeCustomization = ThemeCustomization.fromJson(json);
        } catch (e) {
          debugPrint('Error loading theme customization: $e');
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

  Future<void> updateThemeCustomization(ThemeCustomization customization) async {
    debugPrint('Updating theme customization: ${customization.toJson()}');
    _themeCustomization = customization;

    // Save to database
    try {
      final json = jsonEncode(customization.toJson());
      await _dbHelper.setSetting('theme_customization', json);
      debugPrint('Theme customization saved to database: $json');
    } catch (e) {
      debugPrint('Error saving theme customization to database: $e');
    }

    debugPrint('Calling onSettingsChanged callback');
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

  // Enhanced smooth scrolling setup using advanced CSS and JavaScript
  String getWebViewSmoothScrollingJavaScript() {
    if (!_smoothScrolling) {
      return '';
    }

    return '''
      // Enhanced smooth scrolling implementation with momentum and advanced behavior
      (function() {
        // Remove any existing smooth scrolling styles
        var existingStyle = document.getElementById('browser2-smooth-scroll-style');
        if (existingStyle) {
          existingStyle.remove();
        }

        // Create enhanced smooth scrolling CSS
        var style = document.createElement('style');
        style.id = 'browser2-smooth-scroll-style';
        style.textContent = \`
          html, body {
            scroll-behavior: smooth !important;
            -webkit-overflow-scrolling: touch !important;
            overscroll-behavior: contain !important;
            scroll-snap-type: none !important;
          }

          /* Apply to all scrollable elements */
          * {
            scroll-behavior: smooth !important;
          }

          /* Enhanced scrolling for better momentum */
          [style*="overflow"] {
            -webkit-overflow-scrolling: touch !important;
            overscroll-behavior: contain !important;
          }

          /* Improve scrollbar appearance and behavior */
          ::-webkit-scrollbar {
            width: 12px;
            height: 12px;
          }

          ::-webkit-scrollbar-track {
            background: rgba(0, 0, 0, 0.1);
            border-radius: 6px;
          }

          ::-webkit-scrollbar-thumb {
            background: rgba(0, 0, 0, 0.3);
            border-radius: 6px;
            border: 2px solid transparent;
            background-clip: content-box;
          }

          ::-webkit-scrollbar-thumb:hover {
            background: rgba(0, 0, 0, 0.5);
            background-clip: content-box;
          }

          /* Smooth transitions for better UX */
          * {
            transition: scroll-behavior 0.3s ease !important;
          }
        \`;
        document.head.appendChild(style);

        // Apply styles directly for immediate effect
        var elements = [document.documentElement, document.body];
        elements.forEach(function(el) {
          if (el) {
            el.style.scrollBehavior = 'smooth';
            el.style.webkitOverflowScrolling = 'touch';
            el.style.overscrollBehavior = 'contain';
            el.style.scrollSnapType = 'none';
          }
        });

        // Enhanced wheel event handling for better smooth scrolling
        var wheelTimeout;
        var lastWheelTime = 0;
        var accumulatedDeltaX = 0;
        var accumulatedDeltaY = 0;

        function handleWheel(event) {
          // Prevent default smooth scrolling conflicts
          if (event.deltaY !== 0 || event.deltaX !== 0) {
            var currentTime = Date.now();
            var timeDiff = currentTime - lastWheelTime;

            // Accumulate small movements for smoother scrolling
            if (timeDiff < 16) { // ~60fps
              accumulatedDeltaX += event.deltaX * 0.3;
              accumulatedDeltaY += event.deltaY * 0.3;

              // Apply accumulated scroll with easing
              if (Math.abs(accumulatedDeltaX) > 1 || Math.abs(accumulatedDeltaY) > 1) {
                window.scrollBy({
                  left: accumulatedDeltaX,
                  top: accumulatedDeltaY,
                  behavior: 'smooth'
                });
                accumulatedDeltaX *= 0.7; // Decay accumulation
                accumulatedDeltaY *= 0.7;
                event.preventDefault();
              }
            } else {
              // Reset accumulation for new scroll gesture
              accumulatedDeltaX = 0;
              accumulatedDeltaY = 0;
            }

            lastWheelTime = currentTime;

            // Clear timeout for smooth ending
            clearTimeout(wheelTimeout);
            wheelTimeout = setTimeout(function() {
              accumulatedDeltaX = 0;
              accumulatedDeltaY = 0;
            }, 100);
          }
        }

        // Add enhanced wheel event listener
        document.addEventListener('wheel', handleWheel, { passive: false });

        // Add touch scrolling enhancements for mobile-like behavior
        var touchStartY = 0;
        var touchStartX = 0;
        var touchMomentum = { x: 0, y: 0 };
        var touchMomentumTimeout;

        function handleTouchStart(event) {
          touchStartY = event.touches[0].clientY;
          touchStartX = event.touches[0].clientX;
          touchMomentum = { x: 0, y: 0 };
          clearTimeout(touchMomentumTimeout);
        }

        function handleTouchMove(event) {
          if (event.touches.length === 1) {
            var touchCurrentY = event.touches[0].clientY;
            var touchCurrentX = event.touches[0].clientX;
            var deltaY = touchStartY - touchCurrentY;
            var deltaX = touchStartX - touchCurrentX;

            // Calculate momentum
            touchMomentum.y = deltaY * 0.1;
            touchMomentum.x = deltaX * 0.1;

            touchStartY = touchCurrentY;
            touchStartX = touchCurrentX;
          }
        }

        function handleTouchEnd(event) {
          // Apply momentum scrolling
          if (Math.abs(touchMomentum.y) > 0.5 || Math.abs(touchMomentum.x) > 0.5) {
            applyMomentumScroll();
          }
        }

        function applyMomentumScroll() {
          var friction = ${_scrollFriction};
          var deceleration = ${_scrollDeceleration};
          var minVelocity = ${_scrollMinVelocity};
          var maxVelocity = ${_scrollMaxVelocity};

          function animate() {
            // Apply friction
            touchMomentum.x *= friction;
            touchMomentum.y *= friction;

            // Apply deceleration
            touchMomentum.x *= deceleration;
            touchMomentum.y *= deceleration;

            // Clamp velocity
            touchMomentum.x = Math.max(-maxVelocity, Math.min(maxVelocity, touchMomentum.x));
            touchMomentum.y = Math.max(-maxVelocity, Math.min(maxVelocity, touchMomentum.y));

            // Stop if velocity is too low
            if (Math.abs(touchMomentum.x) < minVelocity && Math.abs(touchMomentum.y) < minVelocity) {
              return;
            }

            // Apply scroll
            window.scrollBy(touchMomentum.x, touchMomentum.y);

            // Continue animation
            requestAnimationFrame(animate);
          }

          requestAnimationFrame(animate);
        }

        // Add touch event listeners
        document.addEventListener('touchstart', handleTouchStart, { passive: true });
        document.addEventListener('touchmove', handleTouchMove, { passive: true });
        document.addEventListener('touchend', handleTouchEnd, { passive: true });

        console.log('Enhanced smooth scrolling enabled with momentum and advanced behavior');
      })();
    ''';
  }

  // Enhanced mouse wheel sensitivity control that works with advanced smooth scrolling
  String getWebViewMouseSensitivityJavaScript() {
    final sensitivity = _mouseSensitivity;

    return '''
      // Enhanced mouse wheel sensitivity control that works with advanced smooth scrolling
      (function() {
        var sensitivity = ${sensitivity};
        var isSmoothScrollingEnabled = ${_smoothScrolling};

        // Enhanced wheel event handling for sensitivity and smooth behavior
        function handleWheelSensitivity(event) {
          if (!event.deltaY && !event.deltaX) return;

          // Apply sensitivity multiplier
          var modifiedDeltaX = event.deltaX * sensitivity;
          var modifiedDeltaY = event.deltaY * sensitivity;

          if (isSmoothScrollingEnabled) {
            // For smooth scrolling, let the enhanced smooth scrolling handler manage the event
            // Just apply sensitivity to the event for the smooth scrolling system
            event.deltaX = modifiedDeltaX;
            event.deltaY = modifiedDeltaY;
          } else {
            // For non-smooth scrolling, apply direct scroll with sensitivity
            event.preventDefault();
            window.scrollBy({
              left: modifiedDeltaX,
              top: modifiedDeltaY,
              behavior: 'auto'
            });
          }
        }

        // Add wheel event listener with appropriate priority
        // Use capturing phase to ensure sensitivity is applied before other handlers
        document.addEventListener('wheel', handleWheelSensitivity, {
          passive: false,
          capture: true,
          once: false
        });

        console.log('Enhanced mouse wheel sensitivity set to: ' + sensitivity +
                   ' (smooth scrolling: ' + isSmoothScrollingEnabled + ')');
      })();
    ''';
  }

  // Get scrolling configuration status for debugging
  Map<String, dynamic> getScrollingConfiguration() {
    return {
      'smoothScrolling': _smoothScrolling,
      'mouseSensitivity': _mouseSensitivity,
      'scrollFriction': _scrollFriction,
      'scrollDeceleration': _scrollDeceleration,
      'scrollMinVelocity': _scrollMinVelocity,
      'scrollMaxVelocity': _scrollMaxVelocity,
    };
  }

  // Reset smooth scrolling to default state (removes custom styles and event listeners)
  String getWebViewSmoothScrollingResetJavaScript() {
    return '''
      // Reset smooth scrolling to default state
      (function() {
        // Remove custom smooth scrolling styles
        var style = document.getElementById('browser2-smooth-scroll-style');
        if (style) {
          style.remove();
        }

        // Reset element styles
        var elements = [document.documentElement, document.body];
        elements.forEach(function(el) {
          if (el) {
            el.style.scrollBehavior = '';
            el.style.webkitOverflowScrolling = '';
            el.style.overscrollBehavior = '';
            el.style.scrollSnapType = '';
          }
        });

        // Remove all custom event listeners by reloading event handlers
        // This is a simplified approach - in production, we'd track and remove specific listeners

        console.log('Smooth scrolling reset to default state');
      })();
    ''';
  }

}

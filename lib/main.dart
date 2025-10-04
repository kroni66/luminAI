import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'browser_screen.dart';
import 'services/settings_manager.dart';
import 'services/ollama_service.dart';
import 'services/adblock_service.dart';
import 'services/notification_service.dart';
import 'database_helper.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database and settings
  final dbHelper = DatabaseHelper();

  // Initialize notification service
  await NotificationService.initialize();

  // Initialize services
  final ollamaService = OllamaService();
  final adBlockService = AdBlockService();
  final settingsManager = SettingsManager(
    ollamaService: ollamaService,
    adBlockService: adBlockService,
    dbHelper: dbHelper,
  );
  await settingsManager.initialize();

  runApp(MyApp(settingsManager: settingsManager));

  // Configure bitsdojo window with stored size
  doWhenWindowReady(() {
    final initialSize = Size(settingsManager.windowWidth, settingsManager.windowHeight);
    appWindow.minSize = const Size(800, 600);
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.title = "Lumin";
    appWindow.show();

    // Periodically check and save window size changes
    Size lastSavedSize = initialSize;
    Timer.periodic(const Duration(seconds: 2), (timer) {
      final currentSize = appWindow.size;
      // Only save if size has changed, window is not maximized, and size is valid
      if (!appWindow.isMaximized &&
          currentSize != Size.zero &&
          currentSize != lastSavedSize &&
          (currentSize.width - lastSavedSize.width).abs() > 10 ||
          (currentSize.height - lastSavedSize.height).abs() > 10) {
        settingsManager.updateWindowSize(currentSize.width, currentSize.height);
        lastSavedSize = currentSize;
      }
    });
  });
}

class MyApp extends StatefulWidget {
  final SettingsManager settingsManager;

  const MyApp({super.key, required this.settingsManager});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _currentThemeMode;
  late ShadThemeData _currentLightTheme;
  late ShadThemeData _currentDarkTheme;

  @override
  void initState() {
    super.initState();
    _currentThemeMode = _getThemeModeFromAppTheme(widget.settingsManager.appTheme);
    _currentLightTheme = _buildLightTheme(widget.settingsManager.themeCustomization);
    _currentDarkTheme = _buildDarkTheme(widget.settingsManager.themeCustomization);

    // Listen for theme changes
    widget.settingsManager.onSettingsChanged = () {
      debugPrint('Theme settings changed - rebuilding themes');
      debugPrint('Current theme customization: ${widget.settingsManager.themeCustomization.toJson()}');
      setState(() {
        _currentThemeMode = _getThemeModeFromAppTheme(widget.settingsManager.appTheme);
        _currentLightTheme = _buildLightTheme(widget.settingsManager.themeCustomization);
        _currentDarkTheme = _buildDarkTheme(widget.settingsManager.themeCustomization);
      });
    };
  }

  ThemeMode _getThemeModeFromAppTheme(AppTheme appTheme) {
    switch (appTheme) {
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.dark:
        return ThemeMode.dark;
      case AppTheme.system:
        return ThemeMode.system;
    }
  }

  ShadThemeData _buildLightTheme(ThemeCustomization customization) {
    ShadColorScheme baseScheme = const ShadZincColorScheme.light();

    // Create a completely new color scheme with customized colors
    final colorScheme = ShadColorScheme(
      background: customization.backgroundColor ?? baseScheme.background,
      foreground: baseScheme.foreground,
      card: customization.backgroundColor ?? baseScheme.card,
      cardForeground: baseScheme.cardForeground,
      popover: baseScheme.popover,
      popoverForeground: baseScheme.popoverForeground,
      primary: customization.accentColor ?? baseScheme.primary,
      primaryForeground: baseScheme.primaryForeground,
      secondary: baseScheme.secondary,
      secondaryForeground: baseScheme.secondaryForeground,
      muted: baseScheme.muted,
      mutedForeground: baseScheme.mutedForeground,
      accent: customization.accentColor ?? baseScheme.accent,
      accentForeground: baseScheme.accentForeground,
      destructive: baseScheme.destructive,
      destructiveForeground: baseScheme.destructiveForeground,
      border: baseScheme.border,
      input: baseScheme.input,
      ring: customization.accentColor ?? baseScheme.ring,
      selection: baseScheme.selection,
    );

    return ShadThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
    );
  }

  ShadThemeData _buildDarkTheme(ThemeCustomization customization) {
    ShadColorScheme baseScheme = const ShadZincColorScheme.dark();

    // Create a completely new color scheme with customized colors
    final colorScheme = ShadColorScheme(
      background: customization.backgroundColor ?? baseScheme.background,
      foreground: baseScheme.foreground,
      card: customization.backgroundColor ?? baseScheme.card,
      cardForeground: baseScheme.cardForeground,
      popover: baseScheme.popover,
      popoverForeground: baseScheme.popoverForeground,
      primary: customization.accentColor ?? baseScheme.primary,
      primaryForeground: baseScheme.primaryForeground,
      secondary: baseScheme.secondary,
      secondaryForeground: baseScheme.secondaryForeground,
      muted: baseScheme.muted,
      mutedForeground: baseScheme.mutedForeground,
      accent: customization.accentColor ?? baseScheme.accent,
      accentForeground: baseScheme.accentForeground,
      destructive: baseScheme.destructive,
      destructiveForeground: baseScheme.destructiveForeground,
      border: baseScheme.border,
      input: baseScheme.input,
      ring: customization.accentColor ?? baseScheme.ring,
      selection: baseScheme.selection,
    );

    return ShadThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
    );
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ShadApp(
      key: ValueKey('shad_app_${_currentThemeMode}_${_currentLightTheme.colorScheme.primary.value}_${_currentDarkTheme.colorScheme.primary.value}'),
      title: 'Lumin',
      theme: _currentLightTheme,
      darkTheme: _currentDarkTheme,
      themeMode: _currentThemeMode,
      home: BrowserScreen(settingsManager: widget.settingsManager),
    );
  }
}

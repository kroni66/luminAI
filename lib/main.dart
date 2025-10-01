import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:async';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'browser_screen.dart';
import 'services/settings_manager.dart';
import 'services/ollama_service.dart';
import 'services/adblock_service.dart';
import 'database_helper.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database and settings
  final dbHelper = DatabaseHelper();

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
    appWindow.maximize(); // Start in fullscreen
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

  @override
  void initState() {
    super.initState();
    _currentThemeMode = _getThemeModeFromAppTheme(widget.settingsManager.appTheme);

    // Listen for theme changes
    widget.settingsManager.onSettingsChanged = () {
      setState(() {
        _currentThemeMode = _getThemeModeFromAppTheme(widget.settingsManager.appTheme);
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

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'Lumin',
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadZincColorScheme.light(),
      ),
      darkTheme: ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: const ShadZincColorScheme.dark(),
      ),
      themeMode: _currentThemeMode,
      home: BrowserScreen(settingsManager: widget.settingsManager),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_windows/webview_windows.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'models/tab_info.dart';
import 'widgets/browser_app_bar.dart';
import 'database_helper.dart';
import 'services/browser_controller.dart';
import 'widgets/tab_sidebar.dart';
import 'widgets/chat_sidebar.dart';
import 'widgets/web_view_area.dart';
import 'widgets/bookmark_window.dart';
import 'widgets/history_window.dart';
import 'widgets/new_tab_page.dart';
import 'widgets/settings_window.dart';
import 'widgets/download_window.dart';
import 'widgets/compact_tab_bar.dart';
import 'widgets/tab_selection_dialog.dart';
import 'services/tab_manager.dart';
import 'services/settings_manager.dart';
import 'services/bookmark_manager.dart';
import 'services/history_manager.dart';
import 'services/navigation_manager.dart';
import 'services/chat_manager.dart';
import 'services/ai_recommendation_service.dart';
import 'services/hover_preview_manager.dart';
import 'services/ollama_service.dart';
import 'services/openrouter_service.dart';
import 'services/ai_service.dart';
import 'services/adblock_service.dart';
import 'services/download_manager.dart';
import 'services/contextual_highlights_manager.dart';
import 'services/browser_automation_service.dart';
import 'services/function_calling_service.dart';
import 'services/screenshot_manager.dart';
import 'services/update_service.dart';
import 'services/notification_service.dart';
import 'widgets/hover_preview_widget.dart';
import 'widgets/screenshot_overlay.dart';
import 'widgets/screenshot_preview_dialog.dart';
import 'widgets/smart_notes_window.dart';
import 'models/smart_note.dart';
import 'package:dyn_mouse_scroll/dyn_mouse_scroll.dart';
import 'package:blurbox/blurbox.dart';
import 'models/widget_data.dart';
import 'package:uuid/uuid.dart';

class WindowButtons extends StatelessWidget {
  const WindowButtons({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final buttonColors = WindowButtonColors(
      iconNormal: ShadTheme.of(context).colorScheme.mutedForeground,
      mouseOver: ShadTheme.of(context).colorScheme.muted,
      mouseDown: ShadTheme.of(context).colorScheme.primary.withOpacity(0.8),
      iconMouseOver: ShadTheme.of(context).colorScheme.foreground,
      iconMouseDown: ShadTheme.of(context).colorScheme.primaryForeground,
    );

    final closeButtonColors = WindowButtonColors(
      mouseOver: const Color(0xFFD32F2F),
      mouseDown: const Color(0xFFB71C1C),
      iconNormal: ShadTheme.of(context).colorScheme.mutedForeground,
      iconMouseOver: Colors.white,
      iconMouseDown: Colors.white,
    );

    return Row(
      children: [
        MinimizeWindowButton(colors: buttonColors),
        MaximizeWindowButton(colors: buttonColors),
        CloseWindowButton(colors: closeButtonColors),
      ],
    );
  }
}

class BrowserScreen extends StatefulWidget {
  final SettingsManager? settingsManager;

  const BrowserScreen({super.key, this.settingsManager});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  // Service managers using composition
  late final TabManager _tabManager;
  late final SettingsManager _settingsManager;
  late final BookmarkManager _bookmarkManager;
  late final HistoryManager _historyManager;
  late final NavigationManager _navigationManager;
  late final ChatManager _chatManager;
  late final AIRecommendationService _aiRecommendationService;
  late final HoverPreviewManager _hoverPreviewManager;
  late final DownloadManager _downloadManager;
  late final ContextualHighlightsManager _contextualHighlightsManager;
  late final OpenRouterService _openRouterService;
  late final AIService _aiService;
  late final BrowserAutomationService _browserAutomationService;
  late final FunctionCallingService _functionCallingService;
  late final ScreenshotManager _screenshotManager;
  late final UpdateService _updateService;

  // Database helper
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Favorite apps for the New Tab Page
  final List<Map<String, String>> _favoriteApps = const [
    {'title': 'YouTube', 'url': 'https://www.youtube.com', 'bg': '#FF000022', 'fg': '#FF0000'},
    {'title': 'Gmail', 'url': 'https://mail.google.com', 'bg': '#0B57D022', 'fg': '#0B57D0'},
    {'title': 'GitHub', 'url': 'https://github.com', 'bg': '#24292E22', 'fg': '#24292E'},
    {'title': 'Reddit', 'url': 'https://www.reddit.com', 'bg': '#FF450022', 'fg': '#FF4500'},
    {'title': 'Twitter', 'url': 'https://twitter.com', 'bg': '#1DA1F222', 'fg': '#1DA1F2'},
    {'title': 'StackOverflow', 'url': 'https://stackoverflow.com', 'bg': '#F4802422', 'fg': '#F48024'},
  ];

  // Custom favorites persisted in DB
  List<Map<String, String>> _customFavorites = [];

  // UI Constants
  static const double _sidebarWidth = 250.0;
  static const double _chatWidth = 350.0;

  // Keys for accessing widget state
  final GlobalKey<TabSidebarState> _tabSidebarKey = GlobalKey<TabSidebarState>();
  final GlobalKey<BrowserAppBarState> _browserAppBarKey = GlobalKey<BrowserAppBarState>();


  // Context mode state
  bool _isContextModeEnabled = false;

  // Contextual highlights state
  bool _isContextualHighlightsActive = false;

  // Logo data
  String? _logoDataUri;

  // URL controller for the address bar
  final TextEditingController _urlController = TextEditingController();

  // Force rebuild counter for WebViewArea
  int _webViewRebuildCounter = 0;

  // Download window state
  bool _isDownloadWindowOpen = false;

  // Suggestions state
  List<HistoryEntry> _currentSuggestions = [];
  String _currentQuery = '';
  int _selectedSuggestionIndex = -1;

  // Widgets state
  List<WidgetData> _widgets = [];
  final Uuid _uuid = const Uuid();

  // Smart notes state
  List<SmartNote> _smartNotes = [];
  bool _isSmartNotesWindowOpen = false;

  // Update state
  bool _updateAvailable = false;
  bool _updateDownloaded = false;

  void _showSuggestions(List<HistoryEntry> suggestions, String query) {
    setState(() {
      _currentSuggestions = suggestions;
      _currentQuery = query;
      _selectedSuggestionIndex = -1; // Reset selection when showing new suggestions
    });
  }

  void _hideSuggestions() {
    setState(() {
      _currentSuggestions = [];
      _currentQuery = '';
      _selectedSuggestionIndex = -1; // Reset selection when hiding suggestions
    });
  }

  void _navigateSuggestionsUp() {
    if (_currentSuggestions.isEmpty) return;
    setState(() {
      if (_selectedSuggestionIndex <= 0) {
        _selectedSuggestionIndex = _currentSuggestions.length - 1; // Wrap to bottom
      } else {
        _selectedSuggestionIndex--;
      }
    });
  }

  void _navigateSuggestionsDown() {
    if (_currentSuggestions.isEmpty) return;
    setState(() {
      if (_selectedSuggestionIndex >= _currentSuggestions.length - 1) {
        _selectedSuggestionIndex = 0; // Wrap to top
      } else {
        _selectedSuggestionIndex++;
      }
    });
  }

  void _selectCurrentSuggestion() {
    if (_currentSuggestions.isEmpty || _selectedSuggestionIndex < 0 || _selectedSuggestionIndex >= _currentSuggestions.length) {
      // No suggestions or invalid selection, use current text
      final url = _urlController.text.trim();
      if (url.isNotEmpty) {
        _hideSuggestions();
        _navigateToUrl(url);
      }
      return;
    }

    final selectedSuggestion = _currentSuggestions[_selectedSuggestionIndex];
    _hideSuggestions();
    _navigateToUrl(selectedSuggestion.url);
  }

  Widget _buildSuggestionItem(HistoryEntry suggestion, String query, BuildContext context, bool isSelected) {
    // Highlight the matching parts of the text
    List<TextSpan> _highlightMatches(String text, String query) {
      if (query.isEmpty) {
        return [TextSpan(text: text, style: const TextStyle(color: Colors.black))];
      }

      final lowercaseText = text.toLowerCase();
      final lowercaseQuery = query.toLowerCase();
      final spans = <TextSpan>[];
      var start = 0;

      while (true) {
        final index = lowercaseText.indexOf(lowercaseQuery, start);
        if (index == -1) {
          // Add remaining text
          if (start < text.length) {
            spans.add(TextSpan(
              text: text.substring(start),
              style: TextStyle(color: ShadTheme.of(context).colorScheme.foreground),
            ));
          }
          break;
        }

        // Add text before match
        if (index > start) {
          spans.add(TextSpan(
            text: text.substring(start, index),
            style: TextStyle(color: ShadTheme.of(context).colorScheme.foreground),
          ));
        }

        // Add highlighted match
        spans.add(TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            color: ShadTheme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ));

        start = index + query.length;
      }

      return spans;
    }

    final urlSpans = _highlightMatches(suggestion.url, query);
    final titleSpans = _highlightMatches(suggestion.title, query);

    return InkWell(
      onTap: () {
        _hideSuggestions();
        _navigateToUrl(suggestion.url);
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: isSelected ? BoxDecoration(
          color: ShadTheme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ) : null,
        child: Row(
          children: [
            // Favicon or globe icon
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 12),
              child: suggestion.faviconUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Image.network(
                        suggestion.faviconUrl,
                        width: 20,
                        height: 20,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            HeroiconsOutline.globeAlt,
                            size: 16,
                            color: ShadTheme.of(context).colorScheme.mutedForeground,
                          );
                        },
                      ),
                    )
                  : Icon(
                      HeroiconsOutline.globeAlt,
                      size: 16,
                      color: ShadTheme.of(context).colorScheme.mutedForeground,
                    ),
            ),
            // Title and URL
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title (if available)
                  if (suggestion.title.isNotEmpty)
                    RichText(
                      text: TextSpan(children: titleSpans),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  // URL
                  RichText(
                    text: TextSpan(
                      children: urlSpans,
                      style: TextStyle(
                        fontSize: 12,
                        color: suggestion.title.isNotEmpty
                            ? ShadTheme.of(context).colorScheme.mutedForeground
                            : ShadTheme.of(context).colorScheme.foreground,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }




  Future<void> _ensureLogoLoaded() async {
    if (_logoDataUri != null) return;
    try {
      final bytes = await rootBundle.load('lib/assets/LUMIN.png');
      final b64 = base64Encode(bytes.buffer.asUint8List());
      _logoDataUri = 'data:image/png;base64,'+b64;
    } catch (e) {
      debugPrint('Failed to load LUMIN.png: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize service managers
    _tabManager = TabManager(_dbHelper);
    _openRouterService = OpenRouterService();
    final ollamaService = OllamaService();
    _settingsManager = widget.settingsManager ?? SettingsManager(
      ollamaService: ollamaService,
      adBlockService: AdBlockService(),
      dbHelper: _dbHelper,
    );
    _aiService = AIService(ollamaService, _openRouterService, _settingsManager);
    _bookmarkManager = BookmarkManager(_dbHelper);
    _historyManager = HistoryManager(_dbHelper);
    _navigationManager = NavigationManager();
    _browserAutomationService = BrowserAutomationService(_tabManager, _navigationManager);
    _functionCallingService = FunctionCallingService(_aiService, _browserAutomationService);
    _chatManager = ChatManager(_aiService, _settingsManager, _functionCallingService);
    _aiRecommendationService = AIRecommendationService(_aiService);
    _hoverPreviewManager = HoverPreviewManager(_aiService);
    _downloadManager = DownloadManager(_dbHelper, _settingsManager);
    _contextualHighlightsManager = ContextualHighlightsManager(_aiService);
    _screenshotManager = ScreenshotManager();
    _updateService = UpdateService();

    // Set up screenshot manager callbacks
    _screenshotManager.onModeChanged = () {
      debugPrint('BrowserScreen: Mode changed to ${_screenshotManager.mode}');
      Future.microtask(() => setState(() {}));
    };
    _screenshotManager.onScreenshotTaken = () {
      debugPrint('BrowserScreen: Screenshot taken, mode: ${_screenshotManager.mode}');
      Future.microtask(() => setState(() {}));
    };
    _screenshotManager.onScreenshotCleared = () {
      debugPrint('BrowserScreen: Screenshot cleared');
      Future.microtask(() => setState(() {}));
    };

    // Set up callbacks
    _tabManager.onTabsChanged = () => setState(() {});
    _contextualHighlightsManager.onHighlightStateChanged = () => setState(() {});
    _contextualHighlightsManager.highlightStateStream.listen((isActive) {
      setState(() {
        _isContextualHighlightsActive = isActive;
      });
    });

    // Initialize AI services with settings - chain with main app's theme callback
    final existingCallback = _settingsManager.onSettingsChanged;
    _settingsManager.onSettingsChanged = () {
      // Call the existing callback (theme updates from main app)
      existingCallback?.call();
      // Initialize services with new settings
      _initializeServicesWithSettings();
    };

    _tabManager.onActiveTabChanged = (index) {
      // Update navigation manager with active tab's controller
      _navigationManager.browserController = _tabManager.activeTab?.browserController;
      // Also set the windows controller for direct webview access (fallback for navigation)
      if (Platform.isWindows && _tabManager.activeTab?.browserController != null) {
        _navigationManager.windowsController = (_tabManager.activeTab!.browserController as WindowsBrowserController).controller;
      }
      // Update the current URL in navigation manager when active tab changes
      if (_tabManager.activeTab != null) {
        _navigationManager.updateCurrentUrl(_tabManager.activeTab!.url);
      }

      // Force WebView rebuild when switching tabs to ensure content is visible
      _webViewRebuildCounter++;
      setState(() {});
    };
    _tabManager.onNavigationTracked = (fromUrl, toUrl, toTitle, faviconUrl) {
      _tabSidebarKey.currentState?.trackNavigation(fromUrl, toUrl, toTitle, faviconUrl: faviconUrl);
    };
    _tabManager.onPageLoaded = (url, title, faviconUrl) {
      // Add to history when page loads with correct title
      _historyManager.addHistoryEntry(
        url: url,
        title: title,
        faviconUrl: faviconUrl,
      );
    };
    _tabManager.onUrlChanged = (url) async {
      _navigationManager.updateCurrentUrl(url);
      // Update navigation state when URL changes (important for back/forward button state)
      await _navigationManager.updateNavigationState();
      // Update the address bar text when URL changes from hyperlink clicks
      if (_urlController.text != url) {
        _browserAppBarKey.currentState?.setUrlProgrammatically(url);
      }
    };

    // Set up download interception
    _tabManager.onDownloadRequested = _downloadFile;
    _tabManager.onNodeTitleUpdated = (url, newTitle) {
      _tabSidebarKey.currentState?.updateNodeTitle(url, newTitle);
    };


    _bookmarkManager.onBookmarksChanged = () => setState(() {});
    _historyManager.onHistoryChanged = () => setState(() {});
    _navigationManager.onNavigationStateChanged = () => setState(() {});
    _chatManager.onChatStateChanged = () => setState(() {});
    _chatManager.onMessagesChanged = () => setState(() {});
    _aiRecommendationService.onRecommendationsChanged = () => setState(() {});
    _aiRecommendationService.onOrganizationStateChanged = () => setState(() {});
    _aiRecommendationService.onRecommendationLoadingStateChanged = () => setState(() {});
    _hoverPreviewManager.onPreviewStateChanged = () => setState(() {});

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _ensureLogoLoaded();
    await _tabManager.initialize();
    await _settingsManager.initialize();

    // Initialize services with loaded settings
    _initializeServicesWithSettings();

    await _bookmarkManager.initialize();
    await _historyManager.initialize();
    await _downloadManager.initialize();

    // Set up download manager callbacks
    _downloadManager.onDownloadCompleted = (filename, success) {
      if (success) {
        _showNotification(
          'Download Completed',
          '$filename has been downloaded successfully',
          isError: false,
        );
      } else {
        _showNotification(
          'Download Failed',
          '$filename failed to download',
          isError: true,
        );
      }
    };

    await _loadCustomFavorites();
    await _loadWidgetsFromDatabase();
    await _loadSmartNotes();

    // Connect the active tab's controller to navigation manager
    _navigationManager.browserController = _tabManager.activeTab?.browserController;
    // Also set the windows controller for direct webview access (fallback for navigation)
    if (Platform.isWindows && _tabManager.activeTab?.browserController != null) {
      _navigationManager.windowsController = (_tabManager.activeTab!.browserController as WindowsBrowserController).controller;
    }
    // Set the current URL from the active tab
    if (_tabManager.activeTab != null) {
      _navigationManager.updateCurrentUrl(_tabManager.activeTab!.url);
    }

    // Update navigation state after setting up controllers
    await _navigationManager.updateNavigationState();

    // Generate initial AI recommendations
    if (_tabManager.tabs.isNotEmpty) {
      await _aiRecommendationService.generateAIRecommendations(
        _tabManager.tabs,
        _tabManager.activeTabIndex,
      );
    }

    // Set up periodic update checking
    _setupUpdateChecking();
  }

  void _setupUpdateChecking() {
    // Check for updates immediately if auto-check is enabled
    if (_settingsManager.autoCheckForUpdates) {
      _checkForUpdates();
    }

    // Set up periodic checking based on user preferences
    Timer.periodic(_settingsManager.updateCheckInterval, (timer) {
      if (_settingsManager.autoCheckForUpdates) {
        _checkForUpdates();
      }
    });
  }

  Future<void> _autoDownloadUpdate(ReleaseInfo release) async {
    try {
      final downloadUrl = await _updateService.getDownloadUrlForCurrentPlatform();

      if (downloadUrl == null) {
        debugPrint('No download URL available for auto-download');
        return;
      }

      final filePath = await _updateService.downloadUpdate(
        downloadUrl,
        (progress) {
          // Update progress if needed for background download
          debugPrint('Auto-download progress: ${(progress * 100).toStringAsFixed(1)}%');
        },
      );

      if (filePath != null) {
        // Show notification that update was downloaded
        await NotificationService.showUpdateDownloadedNotification();

        // Update UI state
        setState(() {
          _updateDownloaded = true;
        });

        debugPrint('Auto-download completed: $filePath');
        // Note: Installation still requires user action for safety
      } else {
        debugPrint('Auto-download failed');
      }
    } catch (e) {
      debugPrint('Error during auto-download: $e');
    }
  }

  Future<void> _checkForUpdates() async {
    try {
      final result = await _updateService.checkForUpdates();

      // Update last check time
      _settingsManager.updateLastUpdateCheck(DateTime.now());

      if (result.updateAvailable && result.latestRelease != null) {
        setState(() {
          _updateAvailable = true;
        });

        // Show notification if enabled
        if (_settingsManager.showUpdateNotifications) {
          await NotificationService.showUpdateAvailableNotification(
            result.latestRelease!.version,
          );
        }

        // Auto-download if enabled
        if (_settingsManager.autoDownloadUpdates) {
          _autoDownloadUpdate(result.latestRelease!);
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  Future<void> _loadCustomFavorites() async {
    try {
      final favorites = await _dbHelper.getFavoriteApps();
      if (mounted) {
        setState(() {
          _customFavorites = favorites;
        });
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> _addCustomFavorite({required String title, required String url, String? bg, String? fg}) async {
    try {
      await _dbHelper.insertFavorite(title: title, url: url, bg: bg, fg: fg);
      await _loadCustomFavorites();
    } catch (e) {
      debugPrint('Error adding favorite: $e');
    }
  }

  Future<void> _removeCustomFavorite(String url) async {
    try {
      await _dbHelper.deleteFavoriteByUrl(url);
      await _loadCustomFavorites();
    } catch (e) {
      debugPrint('Error deleting favorite: $e');
    }
  }

  void _updateScrollSettings(double scrollSpeed, bool smoothScrolling) {
    _settingsManager.updateScrollSettings(
      scrollSpeed: scrollSpeed,
      smoothScrolling: smoothScrolling,
    );
  }

  void _updateScrollPhysics(double friction, double deceleration, double minVelocity, double maxVelocity) {
    _settingsManager.updateScrollPhysics(
      friction: friction,
      deceleration: deceleration,
      minVelocity: minVelocity,
      maxVelocity: maxVelocity,
    );
  }

  void _updateAISettings(String baseUrl, String model) {
    _settingsManager.updateAISettings(baseUrl: baseUrl, model: model);
  }

  void _updateAIProviderSettings(AIProvider provider, String apiKey, String model) async {
    await _settingsManager.updateAIProviderSettings(
      provider: provider,
      openRouterApiKey: apiKey,
      openRouterModel: model,
    );
    // Re-initialize services with new settings
    _initializeServicesWithSettings();
  }

  void _updateAdBlockSettings(bool enabled) async {
    await _settingsManager.updateAdBlockSettings(enabled);
  }

  void _updateUpdateSettings(bool autoCheck, Duration interval, bool autoDownload, bool showNotifications) {
    _settingsManager.updateAutoCheckForUpdates(autoCheck);
    _settingsManager.updateUpdateCheckInterval(interval);
    _settingsManager.updateAutoDownloadUpdates(autoDownload);
    _settingsManager.updateShowUpdateNotifications(showNotifications);
  }

  void _updateThemeSettings(AppTheme theme) async {
    await _settingsManager.updateAppTheme(theme);
    // Theme change is handled by the main app via settingsManager.onSettingsChanged callback
  }

  void _updateThemeCustomization(ThemeCustomization customization) async {
    await _settingsManager.updateThemeCustomization(customization);
    // Theme customization change is handled by the main app via settingsManager.onSettingsChanged callback
  }

  void _showSettings() {
    showDialog(
      context: context,
      builder: (context) => SettingsWindow(
        mouseSensitivity: _settingsManager.mouseSensitivity,
        trackpadSensitivity: _settingsManager.mouseSensitivity, // Use same value for both
        smoothScrolling: _settingsManager.smoothScrolling,
        scrollFriction: _settingsManager.scrollFriction,
        scrollDeceleration: _settingsManager.scrollDeceleration,
        scrollMinVelocity: _settingsManager.scrollMinVelocity,
        scrollMaxVelocity: _settingsManager.scrollMaxVelocity,
        appTheme: _settingsManager.appTheme,
        themeCustomization: _settingsManager.themeCustomization,
        aiProvider: _settingsManager.aiProvider,
        ollamaBaseUrl: _settingsManager.ollamaBaseUrl,
        ollamaModel: _settingsManager.ollamaModel,
        openRouterApiKey: _settingsManager.openRouterApiKey,
        openRouterModel: _settingsManager.openRouterModel,
        ollamaService: _settingsManager.ollamaService,
        openRouterService: _openRouterService,
        adBlockingEnabled: _settingsManager.adBlockingEnabled,
        adBlockService: _settingsManager.adBlockService,
        autoCheckForUpdates: _settingsManager.autoCheckForUpdates,
        updateCheckInterval: _settingsManager.updateCheckInterval,
        autoDownloadUpdates: _settingsManager.autoDownloadUpdates,
        showUpdateNotifications: _settingsManager.showUpdateNotifications,
        lastUpdateCheck: _settingsManager.lastUpdateCheck,
        updateService: _updateService,
        updateDownloaded: _updateDownloaded,
        onSettingsChanged: _updateScrollSettings,
        onScrollPhysicsChanged: _updateScrollPhysics,
        onThemeSettingsChanged: _updateThemeSettings,
        onThemeCustomizationChanged: _updateThemeCustomization,
        onAISettingsChanged: _updateAISettings,
        onAIProviderSettingsChanged: _updateAIProviderSettings,
        onAdBlockSettingsChanged: _updateAdBlockSettings,
        onUpdateSettingsChanged: _updateUpdateSettings,
      ),
    );
  }

  void _navigateToUrl(String url) async {
    if (url.isEmpty) return;

    // Handle about:blank specially - show favorites page
    if (url == 'about:blank') {
      if (_tabManager.activeTabIndex >= 0 && _tabManager.activeTabIndex < _tabManager.tabs.length) {
        _tabManager.updateTab(_tabManager.activeTabIndex, showNewTabOverlay: true);
      }
      _urlController.text = url;
      await _navigationManager.updateNavigationState();
      return;
    }

    var uriString = url.startsWith('http') ? url : 'https://$url';

    // First ensure the webview controller loads the URL directly
    if (_tabManager.activeTab?.controller != null) {
      try {
        await _tabManager.activeTab!.controller!.loadUrl(uriString);
      } catch (e) {
        debugPrint('Error loading URL directly in controller: $e');
      }
    }

    // Then use navigation manager
    await _navigationManager.navigateToUrl(uriString);

    // Hide the new tab overlay and update tab URL
    if (_tabManager.activeTabIndex >= 0 && _tabManager.activeTabIndex < _tabManager.tabs.length) {
      _tabManager.updateTab(_tabManager.activeTabIndex,
        showNewTabOverlay: false,
        url: uriString,
      );
    }

    // History will be added when the page loads with the correct title
    // (via onPageLoaded callback)

    // Force rebuild
    setState(() {
      _webViewRebuildCounter++;
    });

    _browserAppBarKey.currentState?.setUrlProgrammatically(uriString);
  }


  void _addNewTab() async {
    await _tabManager.addNewTab(url: _navigationManager.homepageUrl, title: 'New Tab');

    // Generate AI recommendations if we now have >3 tabs
    await _aiRecommendationService.generateAIRecommendations(
      _tabManager.tabs,
      _tabManager.activeTabIndex,
    );
  }

  Future<void> _createFolder(String name, {String? color}) async {
    await _tabManager.createFolder(name, color: color);
  }

  Future<void> _updateFolder(String folderId, {String? name, String? color}) async {
    await _tabManager.updateFolder(folderId, name: name, color: color);
  }

  Future<void> _deleteFolder(String folderId) async {
    await _tabManager.deleteFolder(folderId);
  }

  Future<void> _moveTabToFolder(int tabIndex, String? folderId) async {
    await _tabManager.moveTabToFolder(tabIndex, folderId);
  }

  Future<void> _autoOrganizeTabs() async {
    try {
      // Get AI-generated folder organization
      final folderOrganization = await _aiRecommendationService.organizeTabsIntoFolders(
        _tabManager.tabs,
        _tabManager.activeTabIndex,
      );

      if (folderOrganization.isNotEmpty) {
        // Apply the organization to create folders and move tabs
        await _tabManager.autoOrganizeTabsIntoFolders(folderOrganization);

        // Show success message
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: Text('Successfully organized tabs into ${folderOrganization.length} folders!'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        // Show message when no organization was possible
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Organization Possible'),
            content: const Text('Not enough tabs to organize or no suitable categories found.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error during auto-organization: $e');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Failed to organize tabs. Please try again.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _deleteContextNode(String url) {
    _tabSidebarKey.currentState?.deleteContextNode(url);
  }

  void _closeTab(int index) async {
    await _tabManager.closeTab(index);

    // Update AI recommendations based on new tab count
    await _aiRecommendationService.generateAIRecommendations(
      _tabManager.tabs,
      _tabManager.activeTabIndex,
    );
  }

  // AI-powered tab organization
  Future<void> _organizeTabsWithAI() async {
    final newOrder = await _aiRecommendationService.organizeTabsWithAI(
      _tabManager.tabs,
      _tabManager.activeTabIndex,
    );

    // Apply new order to tab manager
    final oldActiveTabId = _tabManager.activeTab!.id;
        final reorderedTabs = List<TabInfo>.generate(
          newOrder.length,
      (i) => _tabManager.tabs[newOrder[i]]
    );

    // Update tabs in manager (this is a bit hacky - ideally the manager would handle reordering)
    // For now, we'll recreate the tabs
    for (int i = 0; i < reorderedTabs.length; i++) {
      _tabManager.publicTabs[i] = reorderedTabs[i];
    }

        // Find new index of the previously active tab
    final newActiveIndex = _tabManager.tabs.indexWhere((tab) => tab.id == oldActiveTabId);
    if (newActiveIndex != -1) {
      _tabManager.publicActiveTabIndex = newActiveIndex;
    }

    _tabManager.onTabsChanged?.call();
    _tabManager.onActiveTabChanged?.call(_tabManager.activeTabIndex);

      // Update database with new order
    await _tabManager.saveAllTabs();

      debugPrint('Tabs organized successfully using AI');
  }

  // Manually regenerate AI recommendations
  Future<void> _regenerateAIRecommendations() async {
    await _aiRecommendationService.regenerateAIRecommendations(
      _tabManager.tabs,
      _tabManager.activeTabIndex,
    );
  }


  // Open URL in new tab
  void _openUrlInNewTab(String url) {
    _tabManager.openUrlInNewTab(url);
    _navigateToUrl(url);
  }

  Future<void> _switchToTab(int index) async {
    await _tabManager.switchToTab(index);
    _browserAppBarKey.currentState?.setUrlProgrammatically(_tabManager.tabs[index].url);
    // TODO: Update navigation state when navigation manager is connected to webview
  }


  void _toggleChat() {
    _chatManager.toggleChat();
  }

  void _clearChat() {
    _chatManager.clearChat();
  }

  void _sendMessage() async {
    await _chatManager.sendMessage();
  }

  void _addTabContext() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return TabSelectionDialog(
          tabs: _tabManager.tabs,
          onTabsSelected: (selectedTabs) {
            _chatManager.addTabContext(selectedTabs);
          },
        );
      },
    );
  }

  void _addContextNodes(List<ContextNode> selectedNodes) {
    _chatManager.addContextNodeContext(selectedNodes);
  }

  List<ContextNode> _getContextNodes() {
    final tabSidebarState = _tabSidebarKey.currentState;
    if (tabSidebarState != null) {
      return tabSidebarState.getAllContextNodes();
    }
    return [];
  }

  void _updateContextMode(bool isEnabled) {
    setState(() {
      _isContextModeEnabled = isEnabled;
    });
  }

  void _onScreenshotButtonPressed() async {
    debugPrint('BrowserScreen: Screenshot button pressed');
    await _screenshotManager.enterScreenshotMode();
    debugPrint('BrowserScreen: Mode after enterScreenshotMode: ${_screenshotManager.mode}');
    setState(() {});
  }


  void _sendScreenshotToAI() {
    debugPrint('BrowserScreen: _sendScreenshotToAI called');
    final base64Image = _screenshotManager.getScreenshotAsBase64();
    debugPrint('BrowserScreen: base64Image is null: ${base64Image == null}');
    if (base64Image != null) {
      debugPrint('BrowserScreen: Sending screenshot to AI chat, base64 length: ${base64Image.length}');
      debugPrint('BrowserScreen: base64Image starts with: ${base64Image.substring(0, 50)}');

      _chatManager.sendImageToAIChat(base64Image, 'Please describe this screenshot');
      _screenshotManager.deleteScreenshot(); // Clear the screenshot after sending
      setState(() {});
    } else {
      debugPrint('BrowserScreen: No screenshot data available');
    }
  }

  void _closeScreenshotPreview() {
    _screenshotManager.exitScreenshotMode();
    setState(() {});
  }
  
  
  // Extract content from current website

  
  
  
  


  
  



  void _showBookmarks() {
    showDialog(
      context: context,
      builder: (context) {
        return BookmarkWindow(
          bookmarks: _bookmarkManager.bookmarks,
          onBookmarkTap: _navigateToUrl,
          onDeleteBookmark: (index) async {
            await _bookmarkManager.removeBookmark(index);
          },
        );
      },
    );
  }

  void _showHistory() {
    showDialog(
      context: context,
      builder: (context) {
        return HistoryWindow(
          history: _historyManager.history,
          onHistoryTap: _navigateToUrl,
          onDeleteHistoryEntry: (index) async {
            await _historyManager.removeHistoryEntry(index);
          },
          onClearHistory: () async {
            await _historyManager.clearHistory();
          },
        );
      },
    );
  }

  void _showDownloads() {
    setState(() {
      _isDownloadWindowOpen = true;
    });

    debugPrint('Opening download window');

    showDialog(
      context: context,
      builder: (context) {
        return DownloadWindow(
          downloadManager: _downloadManager,
          onClose: () {
            setState(() {
              _isDownloadWindowOpen = false;
            });
          },
        );
      },
    ).then((_) {
      setState(() {
        _isDownloadWindowOpen = false;
      });
    });
  }

  void _showNotification(String title, String message, {bool isError = false}) {
    if (!mounted) return;

    final theme = ShadTheme.of(context);
    final backgroundColor = isError
        ? theme.colorScheme.destructive
        : theme.colorScheme.primary;
    final foregroundColor = isError
        ? theme.colorScheme.destructiveForeground
        : theme.colorScheme.primaryForeground;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message,
              style: TextStyle(
                color: foregroundColor.withOpacity(0.9),
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _downloadFile(String url) async {
    try {
      debugPrint('BrowserScreen: Starting download process for: $url');

      await _downloadManager.startDownload(url);

      // Show success message
      debugPrint('BrowserScreen: Download started successfully: $url');

      // Show success notification
      _showNotification(
        'Download Started',
        'Download has been added to the queue',
        isError: false,
      );

      // Auto-show downloads window immediately if not already open
      if (!_isDownloadWindowOpen) {
        debugPrint('BrowserScreen: Download window not open, opening immediately');
        if (mounted) {
          _showDownloads();
        }
      } else {
        debugPrint('BrowserScreen: Download window already open');
      }
    } catch (e) {
      debugPrint('BrowserScreen: Failed to start download: $e');
      // Show error notification
      _showNotification(
        'Download Failed',
        'Failed to start download: ${e.toString()}',
        isError: true,
      );
    }
  }

  Future<void> _downloadPage() async {
    final currentUrl = _navigationManager.currentUrl;
    if (currentUrl.isNotEmpty && currentUrl != 'about:blank') {
      await _downloadFile(currentUrl);
    }
  }

  // Widget management methods
  void _addWidget(WidgetType type) {
    // Calculate a good default position (center of screen with some offset)
    final screenSize = MediaQuery.of(context).size;
    final defaultPosition = Offset(
      (screenSize.width - 300) / 2, // Center horizontally
      200 + (_widgets.length * 50), // Stack vertically with some offset
    );

    final widgetData = WidgetData(
      id: _uuid.v4(),
      type: type,
      position: defaultPosition,
      settings: _getDefaultWidgetSettings(type),
    );

    setState(() {
      _widgets.add(widgetData);
    });

    // Save to database
    _saveWidgetsToDatabase();
  }

  Map<String, dynamic> _getDefaultWidgetSettings(WidgetType type) {
    switch (type) {
      case WidgetType.rssFeed:
        return {
          'title': 'RSS Feed',
          'feedUrl': 'https://rss.cnn.com/rss/edition.rss',
        };
    }
  }

  void _removeWidget(String widgetId) {
    setState(() {
      _widgets.removeWhere((widget) => widget.id == widgetId);
    });
    _saveWidgetsToDatabase();
  }

  void _updateWidget(WidgetData updatedWidget) {
    setState(() {
      final index = _widgets.indexWhere((widget) => widget.id == updatedWidget.id);
      if (index != -1) {
        _widgets[index] = updatedWidget;
      }
    });
    _saveWidgetsToDatabase();
  }

  Future<void> _saveWidgetsToDatabase() async {
    try {
      final widgetMaps = _widgets.map((widget) => widget.toJson()).toList();
      await _dbHelper.saveWidgets(widgetMaps);
    } catch (e) {
      debugPrint('Error saving widgets: $e');
    }
  }

  Future<void> _loadWidgetsFromDatabase() async {
    try {
      final widgetMaps = await _dbHelper.getWidgets();
      setState(() {
        _widgets = widgetMaps.map((map) => WidgetData.fromJson(map)).toList();
      });
    } catch (e) {
      debugPrint('Error loading widgets: $e');
    }
  }

  // Smart notes management methods
  Future<void> _loadSmartNotes() async {
    try {
      // Ensure the smart notes table exists
      await _dbHelper.ensureSmartNotesTableExists();
      final notes = await _dbHelper.getAllSmartNotes();
      if (mounted) {
        setState(() {
          _smartNotes = notes;
        });
      }
    } catch (e) {
      debugPrint('Error loading smart notes: $e');
    }
  }

  Future<void> _addSmartNote(String content, {String? sourceUrl, String? sourceTitle}) async {
    try {
      // Ensure the smart notes table exists
      await _dbHelper.ensureSmartNotesTableExists();
      final note = SmartNote.create(
        content: content,
        sourceUrl: sourceUrl,
        sourceTitle: sourceTitle,
      );
      await _dbHelper.insertSmartNote(note);
      await _loadSmartNotes();
    } catch (e) {
      debugPrint('Error adding smart note: $e');
    }
  }

  Future<void> _deleteSmartNote(SmartNote note) async {
    try {
      // Ensure the smart notes table exists
      await _dbHelper.ensureSmartNotesTableExists();
      await _dbHelper.deleteSmartNote(note.id);
      await _loadSmartNotes();
    } catch (e) {
      debugPrint('Error deleting smart note: $e');
    }
  }

  Future<void> _editSmartNote(SmartNote note) async {
    try {
      // Ensure the smart notes table exists
      await _dbHelper.ensureSmartNotesTableExists();
      await _dbHelper.updateSmartNote(note);
      await _loadSmartNotes();
    } catch (e) {
      debugPrint('Error editing smart note: $e');
    }
  }

  void _showSmartNotesWindow() {
    setState(() {
      _isSmartNotesWindowOpen = true;
    });
  }

  void _closeSmartNotesWindow() {
    setState(() {
      _isSmartNotesWindowOpen = false;
    });
  }

  void _initializeServicesWithSettings() {
    // Initialize OpenRouter service with current settings
    _openRouterService.initialize(
      apiKey: _settingsManager.openRouterApiKey,
      model: _settingsManager.openRouterModel,
    );

    // Test connection in background for OpenRouter if API key is set
    if (_settingsManager.openRouterApiKey.isNotEmpty) {
      _openRouterService.testConnection();
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('BrowserScreen: build() called, screenshot mode: ${_screenshotManager.mode}');
    return Stack(
        children: [
          // Main UI
          Scaffold(
            backgroundColor: Colors.black, // Dark base behind gradient
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F0F10), Color(0xFF000000)],
                ),
              ),
              child: WindowBorder(
                color: ShadTheme.of(context).colorScheme.border,
                width: 1,
                child: Column(
          children: [
            Column(
          children: [
                SizedBox(
                  height: 72,
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: BrowserAppBar(
                            key: _browserAppBarKey,
                            canGoBack: _navigationManager.canGoBack,
                            canGoForward: _navigationManager.canGoForward,
                            urlController: _urlController,
                            onGoHome: () => _navigationManager.goHome(),
                            onGoBack: () => _navigationManager.goBack(),
                            onGoForward: () => _navigationManager.goForward(),
                            onRefresh: () => _navigationManager.refresh(),
                            onNavigateToUrl: _navigateToUrl,
                            onAddBookmark: () {
                              final url = _navigationManager.currentUrl;
                              debugPrint('Adding bookmark for URL: $url');
                              _bookmarkManager.addBookmark(url);
                            },
                            onShowBookmarks: _showBookmarks,
                            onShowHistory: _showHistory,
                            onShowDownloads: _showDownloads,
                            onAddNewTab: _addNewTab,
                            onToggleChat: _toggleChat,
                            onShowSettings: _showSettings,
                            currentFaviconUrl: _tabManager.activeTab?.faviconUrl,
                            historyManager: _historyManager,
                            onShowSuggestions: _showSuggestions,
                            onHideSuggestions: _hideSuggestions,
                            onToggleHighlights: () => _contextualHighlightsManager.toggleHighlights(),
                            onArrowUp: _navigateSuggestionsUp,
                            onArrowDown: _navigateSuggestionsDown,
                            onEnterKey: _selectCurrentSuggestion,
                            updateAvailable: _updateAvailable,
                          ),
                        ),
                      ),
                      const WindowButtons(),
                    ],
                  ),
                ),
                // Compact Tab Bar
                CompactTabBar(
                  tabs: _tabManager.tabs,
                  activeTabIndex: _tabManager.activeTabIndex,
                  onSwitchTab: _switchToTab,
                  onCloseTab: _closeTab,
                  onAddNewTab: _addNewTab,
                  onOrganizeTabsWithAI: _organizeTabsWithAI,
                  isOrganizingTabs: _aiRecommendationService.isOrganizingTabs,
                ),
              ],
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: Stack(
                  children: [
                    TabSidebar(
                      key: _tabSidebarKey,
                      tabs: _tabManager.tabs,
                      folders: _tabManager.folders,
                      activeTabIndex: _tabManager.activeTabIndex,
                      sidebarWidth: _sidebarWidth,
                      onSwitchTab: _switchToTab,
                      onCloseTab: _closeTab,
                      onAddNewTab: _addNewTab,
                      onOpenUrlInNewTab: _openUrlInNewTab,
                      onCreateFolder: _createFolder,
                      onUpdateFolder: _updateFolder,
                      onDeleteFolder: _deleteFolder,
                      onMoveTabToFolder: _moveTabToFolder,
                      onDeleteContextNode: _deleteContextNode,
                      onContextModeChanged: _updateContextMode,
                      onAutoOrganizeTabs: _autoOrganizeTabs,
                      onScreenshotButtonPressed: _onScreenshotButtonPressed,
                      onSmartNotesButtonPressed: _showSmartNotesWindow,
                    ),
                    WebViewArea(
                          key: ValueKey('webview_${_tabManager.activeTab?.id ?? 'none'}_${_webViewRebuildCounter}'),
                          sidebarWidth: _sidebarWidth,
                          controller: _tabManager.activeTab?.controller,
                          settingsManager: _settingsManager,
                          contextualHighlightsManager: _contextualHighlightsManager,
                          onSendImageToChat: _chatManager.sendImageToAIChat,
                          onAnalyzeImage: _chatManager.analyzeImageWithAI,
                          onSendTextToChat: _chatManager.sendTextToAIChat,
                          onOpenLink: _navigateToUrl,
                          onSummarizeWebsite: () {
                            debugPrint('BrowserScreen: onSummarizeWebsite called');
                            _chatManager.handleQuickAction('Summarize Website', _tabManager.activeTab?.controller);
                          },
                          onFindKeyPoints: () => _chatManager.handleQuickAction('Top 10 Key Points', _tabManager.activeTab?.controller),
                          onShowLinkPreview: (url, position) => _hoverPreviewManager.showHoverPreviewForUrl(url, position, _navigationManager.currentUrl),
                          onHideLinkPreview: () => _hoverPreviewManager.hideHoverPreview(),
                          onDownloadFile: _downloadFile,
                          onDownloadPage: _downloadPage,
                          onAddToSmartNotes: _addSmartNote,
                          onPermissionRequested: _onPermissionRequested,
                          screenshotController: _screenshotManager.screenshotController,
                        ),
                    // New Tab overlay
                    if (_tabManager.activeTabIndex >= 0 && _tabManager.activeTabIndex < _tabManager.tabs.length && _tabManager.tabs[_tabManager.activeTabIndex].showNewTabOverlay)
                      Positioned(
                        left: _sidebarWidth,
                        right: _chatManager.isChatOpen ? _chatWidth : 0,
                        top: 0,
                        bottom: 0,
                        child: NewTabPage(
                          defaults: _favoriteApps.map((app) => FavoriteAppItem(
                            title: app['title']!,
                            url: app['url']!,
                            bg: app['bg']!,
                            fg: app['fg']!,
                          )).toList(),
                          customs: _customFavorites.map((app) => FavoriteAppItem(
                            title: app['title']!,
                            url: app['url']!,
                            bg: app['bg']!,
                            fg: app['fg']!,
                          )).toList(),
                          tabs: _tabManager.tabs,
                          aiRecommendations: _aiRecommendationService.aiRecommendations,
                          isGeneratingRecommendations: _aiRecommendationService.isGeneratingRecommendations,
                          onOpen: (url) {
                            _navigateToUrl(url);
                          },
                          onRemoveCustom: (item) {
                            _removeCustomFavorite(item.url);
                          },
                          onAddRequest: () {
                            showDialog(
                              context: context,
                              builder: (context) => AddFavoriteDialog(
                                onSave: (title, url, bg, fg) {
                                  _addCustomFavorite(title: title, url: url, bg: bg, fg: fg);
                                },
                              ),
                            );
                          },
                          onRegenerateRecommendations: _regenerateAIRecommendations,
                          widgets: _widgets,
                          onAddWidget: _addWidget,
                          onRemoveWidget: _removeWidget,
                          onUpdateWidget: _updateWidget,
                        ),
                      ),
                    ChatSidebar(
                      isChatOpen: _chatManager.isChatOpen,
                      chatWidth: _chatWidth,
                      chatMessages: _chatManager.chatMessages,
                      chatController: _chatManager.chatController,
                      chatScrollController: _chatManager.chatScrollController,
                      onToggleChat: _toggleChat,
                      onSendMessage: _sendMessage,
                      onQuickAction: (action) => _chatManager.handleQuickAction(action, _tabManager.activeTab?.controller),
                      onClearChat: _clearChat,
                      onAddTabContext: _addTabContext,
                      settingsManager: _settingsManager,
                      getLocalizedString: _chatManager.getLocalizedString,
                      isContextModeEnabled: _isContextModeEnabled,
                      contextNodes: _getContextNodes(),
                      onAddContextNodes: _addContextNodes,
                      isStreaming: _chatManager.isStreaming,
                      onStopStreaming: _chatManager.cancelStreaming,
                      toolModeEnabled: _chatManager.toolModeEnabled,
                      onToggleToolMode: _chatManager.toggleToolMode,
                    ),
                    
                    // Hover preview overlay
                    if (_hoverPreviewManager.showHoverPreview && _hoverPreviewManager.previewData != null)
                      HoverPreviewWidget(
                        url: _hoverPreviewManager.previewData!.url,
                        summary: _hoverPreviewManager.previewData!.summary,
                        title: _hoverPreviewManager.previewData!.title,
                        screenshotUrl: _hoverPreviewManager.previewData!.screenshotUrl,
                        position: _hoverPreviewManager.hoverPosition,
                        onClose: _hoverPreviewManager.hideHoverPreview,
                      ),
                    
                    // Loading indicator for hover preview
                    ...[
                      if (_hoverPreviewManager.showHoverPreview && _hoverPreviewManager.previewData == null)
                        Positioned(
                          left: _hoverPreviewManager.hoverPosition.dx,
                          top: _hoverPreviewManager.hoverPosition.dy,
                          child: BlurBox(
                            blur: 12.0,
                            color: ShadTheme.of(context).colorScheme.background.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: ShadTheme.of(context).colorScheme.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Loading preview...',
                                    style: ShadTheme.of(context).textTheme.small,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          ),
        ),
      ),
    ),

        // Suggestions overlay - positioned above everything
        if (_currentSuggestions.isNotEmpty)
          Positioned(
            left: 192, // Align with address bar start (navigation buttons width + spacing)
            right: 146, // Align with address bar end (bookmark buttons width + spacing)
            top: 72, // Position right below the window title bar
            child: BlurBox(
              blur: 10.0,
              color: ShadTheme.of(context).colorScheme.background.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: ShadTheme.of(context).colorScheme.border.withOpacity(0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DynMouseScroll(
                  builder: (context, controller, physics) => ListView.builder(
                    controller: controller,
                    physics: physics,
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: _currentSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = _currentSuggestions[index];
                      return _buildSuggestionItem(suggestion, _currentQuery, context, index == _selectedSuggestionIndex);
                    },
                  ),
                ),
              ),
            ),
          ),

        // Contextual highlights indicator - positioned in top right
        if (_isContextualHighlightsActive)
          Positioned(
            top: 80, // Below the title bar
            right: 16,
            child: BlurBox(
              blur: 12.0,
              color: ShadTheme.of(context).colorScheme.background.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.yellow.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.yellow,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Highlights Active',
                      style: ShadTheme.of(context).textTheme.small.copyWith(
                        color: Colors.yellow,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // Screenshot overlay - covers entire screen when in screenshot mode
        if (_screenshotManager.mode == ScreenshotMode.capturing) ...[
          ScreenshotOverlay(
            screenshotManager: _screenshotManager,
            sidebarWidth: _sidebarWidth,
            onCancel: () {
              debugPrint('BrowserScreen: Cancel pressed, exiting screenshot mode');
              _screenshotManager.exitScreenshotMode();
              debugPrint('BrowserScreen: Mode after cancel: ${_screenshotManager.mode}');
              Future.microtask(() => setState(() {}));
              debugPrint('BrowserScreen: setState scheduled after cancel');
            },
          ),
        ],

        // Screenshot preview dialog - shows when screenshot is taken
        if (_screenshotManager.mode == ScreenshotMode.preview)
          ScreenshotPreviewDialog(
            screenshotManager: _screenshotManager,
            onSendToAI: _sendScreenshotToAI,
            onClose: _closeScreenshotPreview,
          ),

        // Smart notes window
        if (_isSmartNotesWindowOpen)
          SmartNotesWindow(
            notes: _smartNotes,
            onDeleteNote: _deleteSmartNote,
            onEditNote: _editSmartNote,
            onClose: _closeSmartNotesWindow,
          ),
      ],
    );
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(
      String url, WebviewPermissionKind kind, bool isUserInitiated) async {

    // Handle different permission types
    switch (kind) {
      case WebviewPermissionKind.camera:
      case WebviewPermissionKind.microphone:
        // Silently deny camera and microphone permissions
        debugPrint('Auto-denied permission: $kind for $url');
        return WebviewPermissionDecision.deny;

      case WebviewPermissionKind.unknown:
        // Allow unknown permissions to ensure website compatibility
        debugPrint('Allowed unknown permission for $url');
        return WebviewPermissionDecision.allow;

      default:
        // For other known permissions (geolocation, notifications, etc.), deny to avoid popups
        debugPrint('Auto-denied permission: $kind for $url');
        return WebviewPermissionDecision.deny;
    }
  }

  @override
  void dispose() {
    // Save tabs before disposing
    _tabManager.saveAllTabs();

    _urlController.dispose();
    _chatManager.dispose();
    _tabManager.dispose();
    _contextualHighlightsManager.dispose();
    _dbHelper.close();
    _settingsManager.ollamaService.dispose();
    super.dispose();
  }
}

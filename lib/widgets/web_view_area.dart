import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_windows/webview_windows.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:screenshot/screenshot.dart';
import '../services/settings_manager.dart';
import '../services/contextual_highlights_manager.dart';
import '../services/web_scraping_service.dart';
import '../services/web_view_javascript_manager.dart';
import '../services/link_preview_handler.dart';
import '../widgets/web_view_context_menu.dart';
import '../widgets/web_view_constants.dart';

/// A widget that provides a web view area with integrated context menu functionality,
/// hover previews, link analysis, and various web interaction features.
///
/// This widget handles:
/// - WebView display and management
/// - Context menu with various actions (summarize, analyze, download, etc.)
/// - Hover previews for links (with Shift key)
/// - Link analysis and preview functionality
/// - Image and text extraction for AI chat integration
/// - Download link interception
///
/// The widget requires a [WebviewController] and various callback functions
/// to handle different user interactions and web page events.
class WebViewArea extends StatefulWidget {
  /// The width of the sidebar to properly position hover previews
  final double sidebarWidth;

  /// The webview controller for managing the web content
  final WebviewController? controller;

  /// Settings manager for webview configuration (smooth scrolling, etc.)
  final SettingsManager? settingsManager;

  /// Contextual highlights manager for highlighting key information
  final ContextualHighlightsManager? contextualHighlightsManager;

  /// Callback for handling webview permission requests
  final Future<WebviewPermissionDecision> Function(String url, WebviewPermissionKind kind, bool isUserInitiated) onPermissionRequested;

  /// Callback for sending images to AI chat
  final Function(String, String)? onSendImageToChat;

  /// Callback for analyzing images with AI
  final Function(String, String)? onAnalyzeImage;

  /// Callback for sending selected text to AI chat
  final Function(String)? onSendTextToChat;

  /// Callback for opening links (currently unused)
  final Function(String)? onOpenLink;

  /// Callback for summarizing the current website
  final Function()? onSummarizeWebsite;

  /// Callback for finding key points in the current website
  final Function()? onFindKeyPoints;

  /// Callback for showing link previews at specific positions
  final Function(String, Offset)? onShowLinkPreview;

  /// Callback for hiding link previews
  final Function()? onHideLinkPreview;

  /// Callback for downloading files from links
  final Function(String)? onDownloadFile;

  /// Callback for downloading the current page
  final Function()? onDownloadPage;

  /// Callback for adding selected text to smart notes
  final Function(String, {String? sourceUrl, String? sourceTitle})? onAddToSmartNotes;

  /// Screenshot controller for capturing the webview
  final ScreenshotController screenshotController;

  const WebViewArea({
    Key? key,
    required this.sidebarWidth,
    required this.controller,
    this.settingsManager,
    this.contextualHighlightsManager,
    required this.onPermissionRequested,
    this.onSendImageToChat,
    this.onAnalyzeImage,
    this.onSendTextToChat,
    this.onOpenLink,
    this.onSummarizeWebsite,
    this.onFindKeyPoints,
    this.onShowLinkPreview,
    this.onHideLinkPreview,
    this.onDownloadFile,
    this.onDownloadPage,
    this.onAddToSmartNotes,
    required this.screenshotController,
  }) : super(key: key);

  @override
  State<WebViewArea> createState() => _WebViewAreaState();
}

/// State class for [WebViewArea] that manages the web view lifecycle,
/// JavaScript injection, hover polling, and context menu interactions.
class _WebViewAreaState extends State<WebViewArea> {
  // ==================== Properties ====================

  /// Flag to prevent multiple rapid context menu actions
  bool _isProcessingAction = false;

  /// Subscription to listen for URL changes in the webview
  StreamSubscription? _controllerSubscription;

  /// Subscription to listen for contextual highlights state changes
  StreamSubscription? _highlightsSubscription;

  /// Service for web scraping and metadata extraction
  late final WebScrapingService _webScrapingService;

  /// Manager for JavaScript operations
  late final WebViewJavaScriptManager _javascriptManager;

  /// Handler for link preview functionality
  late final LinkPreviewHandler _linkPreviewHandler;

  /// Context menu builder
  late final WebViewContextMenu _contextMenu;

  /// Unique key for WebView to ensure proper recreation
  String? _webViewKey;

  /// Stable identifier for the current controller
  String? _currentControllerId;


  // ==================== Lifecycle Methods ====================

  /// Initializes the widget state and sets up all necessary listeners and timers
  @override
  void initState() {
    super.initState();

    // Initialize services
    _webScrapingService = WebScrapingService();
    _javascriptManager = WebViewJavaScriptManager(
      controller: widget.controller,
      settingsManager: widget.settingsManager,
    );
    _linkPreviewHandler = LinkPreviewHandler(
      webScrapingService: _webScrapingService,
      javascriptManager: _javascriptManager,
      sidebarWidth: widget.sidebarWidth,
    );
    _contextMenu = WebViewContextMenu();

    // Initialize WebView key based on controller identity
    _currentControllerId = widget.controller?.hashCode.toString() ?? 'none';
    _webViewKey = 'webview_${_currentControllerId}';

    // Initialize JavaScript tracking when the widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _javascriptManager.initializeJavaScriptTracking();
    });

    // Set up URL listener if controller exists
    _setupUrlListener();

    // Set up contextual highlights listener
    _setupHighlightsListener();
  }

  /// Sets up a listener for URL changes in the webview to re-initialize JavaScript tracking
  void _setupUrlListener() {
    _controllerSubscription?.cancel();

    if (widget.controller != null) {
      try {
        _controllerSubscription = widget.controller!.url.listen((url) {
          if (url.isNotEmpty && mounted) {
            // Re-initialize JavaScript tracking after navigation
            Future.delayed(WebViewConstants.scriptDelay, () {
              if (mounted) {
                _javascriptManager.initializeJavaScriptTracking();
              }
            });
          }
        });
      } catch (e) {
        debugPrint('Error setting up URL listener: $e');
      }
    }
  }

  /// Sets up a listener for contextual highlights state changes
  void _setupHighlightsListener() {
    _highlightsSubscription?.cancel();

    if (widget.contextualHighlightsManager != null) {
      _highlightsSubscription = widget.contextualHighlightsManager!.highlightStateStream.listen((isActive) {
        if (isActive) {
          // Inject highlighting scripts when highlights are enabled
          widget.contextualHighlightsManager!.injectHighlightingScript(widget.controller);
        } else {
          // Remove highlighting scripts when highlights are disabled
          widget.contextualHighlightsManager!.removeHighlightingScript(widget.controller);
        }
      });
    }
  }

  @override
  void didUpdateWidget(WebViewArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If controller changed, update the listener and re-initialize JavaScript tracking
    if (oldWidget.controller != widget.controller) {
      _javascriptManager = WebViewJavaScriptManager(
        controller: widget.controller,
        settingsManager: widget.settingsManager,
      );
      _linkPreviewHandler = LinkPreviewHandler(
        webScrapingService: _webScrapingService,
        javascriptManager: _javascriptManager,
        sidebarWidth: widget.sidebarWidth,
      );
      // Update controller identity and generate new stable key for WebView recreation
      _currentControllerId = widget.controller?.hashCode.toString() ?? 'none';
      _webViewKey = 'webview_${_currentControllerId}';

      _setupUrlListener();

      // Initialize JavaScript tracking with a small delay to ensure WebView is ready
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && widget.controller != null) {
          _javascriptManager.initializeJavaScriptTracking();
        }
      });

    }

    // If contextual highlights manager changed, update the listener
    if (oldWidget.contextualHighlightsManager != widget.contextualHighlightsManager) {
      _setupHighlightsListener();
    }
  }

  // Hover functionality removed - using web scraping approach instead

  /// Cleans up resources when the widget is disposed
  @override
  void dispose() {
    _controllerSubscription?.cancel();
    _highlightsSubscription?.cancel();
    super.dispose();
  }

  // JavaScript management is now handled by WebViewJavaScriptManager

  // Web scraping approach - no JavaScript injection needed for link detection

  // ==================== Context Menu Management ====================

  /// Builds the context menu with all available actions
  ContextMenu _buildContextMenu() {
    return _contextMenu.buildContextMenu();
  }

  // ==================== Context Menu Actions ====================

  /// Handles context menu item selection and executes the appropriate action
  void _handleContextMenuSelection(dynamic value) {
    debugPrint('Context menu selection: $value');
    // Prevent multiple rapid clicks
    if (_isProcessingAction) {
      debugPrint('Context menu: Ignoring duplicate action');
      return;
    }

    _isProcessingAction = true;

    switch (value) {
      case WebViewContextMenu.summarizeWebsite:
        widget.onSummarizeWebsite?.call();
        break;
      case WebViewContextMenu.findKeyPoints:
        widget.onFindKeyPoints?.call();
        break;
      case WebViewContextMenu.sendImageToChat:
        _handleImageAction('send');
        break;
      case WebViewContextMenu.analyzeImage:
        _handleImageAction('analyze');
        break;
      case WebViewContextMenu.askAboutText:
        _handleTextAction();
        break;
      case WebViewContextMenu.addToSmartNotes:
        _handleAddToSmartNotes();
        break;
      case WebViewContextMenu.askAboutLink:
        _linkPreviewHandler.handleLinkAnalysis(onSendTextToChat: widget.onSendTextToChat);
        break;
      case WebViewContextMenu.previewLink:
        _linkPreviewHandler.handleLinkPreview(onShowLinkPreview: widget.onShowLinkPreview);
        break;
      case WebViewContextMenu.downloadLink:
        _handleDownloadLink();
        break;
      case WebViewContextMenu.downloadPage:
        widget.onDownloadPage?.call();
        break;
    }

    // Reset the flag after a short delay
    Future.delayed(WebViewConstants.actionDelay, () {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    });
  }

  void _handleImageAction(String action) async {
    if (widget.controller == null) return;

    try {
      // Get the current URL and fetch page content to find images
      final currentUrl = await _javascriptManager.getCurrentUrl();
      if (currentUrl == null) {
        const errorMessage = 'No page loaded for image analysis';
        if (action == 'send') {
          widget.onSendImageToChat?.call('', errorMessage);
        } else if (action == 'analyze') {
          widget.onAnalyzeImage?.call('', errorMessage);
        }
        return;
      }

      // Fetch page content and extract image information
      final metadata = await _webScrapingService.fetchWebPageMetadata(currentUrl);
      if (metadata != null && metadata['image'] != null && metadata['image'].isNotEmpty) {
        const imageAlt = 'Image from webpage';
        if (action == 'send') {
          widget.onSendImageToChat?.call(metadata['image'], imageAlt);
        } else if (action == 'analyze') {
          widget.onAnalyzeImage?.call(metadata['image'], imageAlt);
        }
      } else {
        const noImageMessage = 'No image found on this page';
        if (action == 'send') {
          widget.onSendImageToChat?.call('', noImageMessage);
        } else if (action == 'analyze') {
          widget.onAnalyzeImage?.call('', noImageMessage);
        }
      }
    } catch (e) {
      debugPrint('Error getting image info: $e');
      const errorMessage = 'Error processing image action';
      if (action == 'send') {
        widget.onSendImageToChat?.call('', errorMessage);
      } else if (action == 'analyze') {
        widget.onAnalyzeImage?.call('', errorMessage);
      }
    }
  }

  void _handleTextAction() async {
    if (widget.controller == null) return;

    try {
      // Get the current URL and fetch page content
      final currentUrl = await _javascriptManager.getCurrentUrl();
      if (currentUrl == null) {
        widget.onSendTextToChat?.call('No page loaded. Please load a webpage first.');
        return;
      }

      // Fetch page content and extract some text
      final metadata = await _webScrapingService.fetchWebPageMetadata(currentUrl);
      if (metadata != null && metadata['description'] != null && metadata['description'].isNotEmpty) {
        widget.onSendTextToChat?.call('Page description: ${metadata['description']}');
      } else {
        widget.onSendTextToChat?.call('No text content available on this page');
      }
    } catch (e) {
      debugPrint('Error getting page text: $e');
      widget.onSendTextToChat?.call('Error getting page text. Please try again.');
    }
  }

  void _handleAddToSmartNotes() async {
    if (widget.controller == null) return;

    try {
      // Get the selected text
      final selectedText = await _javascriptManager.getSelectedText();
      if (selectedText == null || selectedText.trim().isEmpty) {
        // If no text is selected, show a message
        debugPrint('No text selected for smart notes');
        return;
      }

      // Get current page info for context
      final currentUrl = await _javascriptManager.getCurrentUrl();
      String? pageTitle;

      if (currentUrl != null) {
        final metadata = await _webScrapingService.fetchWebPageMetadata(currentUrl);
        pageTitle = metadata?['title'];
      }

      // Call the callback to add to smart notes with source information
      widget.onAddToSmartNotes?.call(
        selectedText.trim(),
        sourceUrl: currentUrl,
        sourceTitle: pageTitle,
      );
    } catch (e) {
      debugPrint('Error adding text to smart notes: $e');
    }
  }

  // Web scraping functionality is now handled by WebScrapingService

  void _handleDownloadLink() async {
    if (widget.controller == null) return;

    try {
      // Get the current URL from the webview
      final currentUrl = await _javascriptManager.getCurrentUrl();
      if (currentUrl == null) {
        debugPrint('No current URL available for download');
        return;
      }

      // Check if it's a downloadable file
      if (_webScrapingService.isDownloadableUrl(currentUrl)) {
        widget.onDownloadFile?.call(currentUrl);
      } else {
        debugPrint('URL is not downloadable: $currentUrl');
      }
    } catch (e) {
      debugPrint('Error getting link URL for download: $e');
    }
  }





  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.sidebarWidth,
      right: 0,
      top: 0,
      bottom: 0,
      child: Stack(
        children: [
          // Main WebView content
          kIsWeb
              ? const Center(
                  child: Text(
                    'Web platform does not support embedded webview. '
                    'Consider using url_launcher to open URLs in the default browser.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : (Platform.isAndroid || Platform.isIOS)
                  ? const Center(
                      child: Text(
                        'Mobile webview temporarily unavailable - flutter_inappwebview removed for testing',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                    )
                      : Platform.isWindows
                          ? widget.controller != null && widget.controller!.value.isInitialized
                              ? SizedBox.expand(
                                  child: Screenshot(
                                    controller: widget.screenshotController,
                                    child: ContextMenuRegion(
                                      contextMenu: _buildContextMenu(),
                                      onItemSelected: (value) {
                                        _handleContextMenuSelection(value);
                                      },
                                      child: Container(
                                        key: ValueKey(_webViewKey ?? 'webview_default'),
                                        child: Webview(
                                          widget.controller!,
                                          permissionRequested: widget.onPermissionRequested,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(),
                                      SizedBox(height: 16),
                                      Text('Loading webview...', style: TextStyle(fontSize: 14)),
                                    ],
                                  ),
                                )
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Desktop WebView opened in separate window.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Back/Forward buttons disabled; use browser controls in the webview window.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
          
        ],
      ),
    );
  }
}


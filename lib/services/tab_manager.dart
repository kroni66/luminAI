import 'dart:async';
import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/tab_info.dart';
import '../models/tab_folder.dart';
import '../services/browser_controller.dart';
import 'dart:io' show Platform;

class TabManager {
  final DatabaseHelper _dbHelper;

  List<TabInfo> _tabs = [];
  List<TabFolder> _folders = [];
  int _activeTabIndex = 0;
  int _nextTabId = 1;
  int _nextFolderId = 1;

  // Helper method to get WebviewController from BrowserController
  dynamic _getWebviewController(BrowserController browserController) {
    if (Platform.isWindows) {
      return (browserController as WindowsBrowserController).controller;
    }
    // For other platforms, return the controller directly if available
    return null;
  }

  // Initialize controller for a tab if not already initialized
  Future<void> _initializeTabController(TabInfo tab) async {
    if (tab.browserController == null) {
      final browserController = BrowserController.create();
      await browserController.initialize();
      tab.controller = _getWebviewController(browserController);
      tab.browserController = browserController;
      _setupTabEventListening(tab);
    }
  }

  // Set up title and URL listening for a tab
  void _setupTabEventListening(TabInfo tab) {
    String? previousUrl;

    if (tab.browserController != null) {
      // Listen to title changes
      tab.browserController!.titleStream.listen((title) {
        if (title.isNotEmpty && title != tab.title) {
          final tabIndex = _tabs.indexWhere((t) => t.id == tab.id);
          if (tabIndex != -1) {
            updateTab(tabIndex, title: title);
            // Notify context tree of title update
            onNodeTitleUpdated?.call(tab.url, title);
            // Notify that page has loaded with title (for history tracking)
            onPageLoaded?.call(tab.url, title, tab.faviconUrl);
          }
        }
      });

      // Listen to URL changes
           tab.browserController!.urlStream.listen((url) {
             if (url.isNotEmpty && url != tab.url) {
               final tabIndex = _tabs.indexWhere((t) => t.id == tab.id);
               if (tabIndex != -1) {
                 updateTab(tabIndex, url: url);
                 // Notify navigation manager of URL change
                 onUrlChanged?.call(url);
                 // Notify context tree of navigation
                 if (previousUrl != null && previousUrl != url) {
                   onNavigationTracked?.call(previousUrl!, url, tab.title, tab.faviconUrl);
                 }
                 previousUrl = url;
               }
             }
           });

      // Set up download interception
      tab.browserController!.onDownloadRequested = (url) {
        // Forward download requests to the tab manager's callback
        onDownloadRequested?.call(url);
      };
    }
  }

  // Getters
  List<TabInfo> get tabs => _tabs;
  List<TabFolder> get folders => _folders;
  int get activeTabIndex => _activeTabIndex;
  int get nextTabId => _nextTabId;
  int get nextFolderId => _nextFolderId;
  TabInfo? get activeTab => _tabs.isNotEmpty ? _tabs[_activeTabIndex] : null;

  // Public access for reordering (temporary - should be refactored)
  List<TabInfo> get publicTabs => _tabs;
  set publicActiveTabIndex(int index) => _activeTabIndex = index;

  // Callbacks
  VoidCallback? onTabsChanged;
  Function(int)? onActiveTabChanged;
  Function(String)? onUrlChanged; // newUrl
  Function(String, String, String, String?)? onNavigationTracked; // fromUrl, toUrl, toTitle, faviconUrl
  Function(String, String)? onNodeTitleUpdated; // url, newTitle
  Function(String, String, String?)? onPageLoaded; // url, title, faviconUrl
  Function(String)? onDownloadRequested; // downloadUrl

  TabManager(this._dbHelper);

  Future<void> initialize() async {
    await _loadFolders();
    await _loadTabs();
  }

  Future<void> _loadFolders() async {
    try {
      final foldersData = await _dbHelper.getFolders();
      if (foldersData.isNotEmpty) {
        final loadedFolders = foldersData.map((data) => TabFolder.fromMap(data)).toList();

        // Update the next folder ID to avoid conflicts
        final maxId = foldersData.map((data) => int.tryParse(data['id'] as String) ?? 0).fold(0, (a, b) => a > b ? a : b);
        _nextFolderId = maxId + 1;

        _folders = loadedFolders;
      } else {
        _folders = [];
        _nextFolderId = 1;
      }
    } catch (e) {
      debugPrint('Error loading folders: $e');
      _folders = [];
      _nextFolderId = 1;
    }
  }

  Future<void> _loadTabs() async {
    try {
      final tabsData = await _dbHelper.getTabs();
      if (tabsData.isNotEmpty) {
        // Load tabs from database
        final loadedTabs = tabsData.map((data) => TabInfo.fromMap(data)).toList();

        // Find the active tab index
        int activeIndex = 0;
        for (int i = 0; i < tabsData.length; i++) {
          if (tabsData[i]['is_active'] == 1) {
            activeIndex = i;
            break;
          }
        }

        // Update the next tab ID to avoid conflicts
        final maxId = tabsData.map((data) => int.tryParse(data['id'] as String) ?? 0).fold(0, (a, b) => a > b ? a : b);
        _nextTabId = maxId + 1;

        _tabs = loadedTabs;
        _activeTabIndex = activeIndex;

        // Initialize controllers for all loaded tabs
        for (final tab in _tabs) {
          await _initializeTabController(tab);
        }

        // Load the URL for the active tab if it's not about:blank
        if (_tabs.isNotEmpty) {
          final activeTab = _tabs[_activeTabIndex];
          if (activeTab.controller != null && activeTab.url != 'about:blank' && activeTab.url.isNotEmpty) {
            try {
              // Small delay to ensure webview is fully ready
              await Future.delayed(const Duration(milliseconds: 100));
              await activeTab.controller!.loadUrl(activeTab.url);
            } catch (e) {
              debugPrint('Error loading URL ${activeTab.url}: $e');
            }
          }
        }
      } else {
        // No saved tabs, create default tab
        await _createDefaultTab();
      }
    } catch (e) {
      debugPrint('Error loading tabs: $e');
      // Fallback to default tab on error
      await _createDefaultTab();
    }

    onTabsChanged?.call();
  }

  Future<void> _createDefaultTab() async {
    final browserController = BrowserController.create();
    await browserController.initialize();

    const defaultUrl = 'https://www.google.com';
    final defaultTab = TabInfo(
      id: '0',
      url: defaultUrl,
      title: 'Google',
      controller: _getWebviewController(browserController),
      browserController: browserController
    );
    _tabs = [defaultTab];
    _activeTabIndex = 0;
    _nextTabId = 1;

    // Set up title and URL listening
    _setupTabEventListening(defaultTab);

    // Navigate to the default URL after controller is ready
    if (defaultTab.controller != null) {
      try {
        // Small delay to ensure webview is fully ready
        await Future.delayed(const Duration(milliseconds: 100));
        await defaultTab.controller!.loadUrl(defaultUrl);
      } catch (e) {
        debugPrint('Error loading default URL: $e');
      }
    }

    // Save the default tab to database
    try {
      await _dbHelper.insertTab(
        id: defaultTab.id,
        url: defaultTab.url,
        title: defaultTab.title,
        faviconUrl: defaultTab.faviconUrl,
        isActive: true,
        order: 0,
      );
    } catch (e) {
      debugPrint('Error saving default tab: $e');
    }

    onTabsChanged?.call();
  }

  Future<void> addNewTab({String? url, String? title, String? folderId}) async {
    String tabId = _nextTabId.toString();

    // Create and initialize controller for new tab
    final browserController = BrowserController.create();
    await browserController.initialize();

    final newTab = TabInfo(
      id: tabId,
      url: url ?? 'about:blank',
      title: title ?? 'New Tab',
      folderId: folderId,
      controller: _getWebviewController(browserController),
      browserController: browserController,
      showNewTabOverlay: url == null || url == 'about:blank'
    );

    // Set up title and URL listening
    _setupTabEventListening(newTab);

    // Navigate to URL if provided and controller is available
    if (newTab.controller != null) {
      try {
        // Small delay to ensure webview is fully ready
        await Future.delayed(const Duration(milliseconds: 100));
        if (url != null && url != 'about:blank' && url.isNotEmpty) {
          await newTab.controller!.loadUrl(url);
        } else {
          // Load about:blank to initialize the webview with some content
          await newTab.controller!.loadUrl('about:blank');
        }
      } catch (e) {
        debugPrint('Error loading URL ${url ?? 'about:blank'}: $e');
      }
    }

    _tabs.add(newTab);
    _activeTabIndex = _tabs.length - 1;
    _nextTabId++;

    // Save new tab to database
    try {
      await _dbHelper.insertTab(
        id: newTab.id,
        url: newTab.url,
        title: newTab.title,
        faviconUrl: newTab.faviconUrl,
        folderId: newTab.folderId,
        isActive: true,
        order: _tabs.length - 1,
      );
      // Update active tab in database
      await _dbHelper.setActiveTab(newTab.id);
    } catch (e) {
      debugPrint('Error saving new tab: $e');
    }

    onTabsChanged?.call();
    onActiveTabChanged?.call(_activeTabIndex);
  }

  Future<void> closeTab(int index) async {
    if (_tabs.length <= 1) return; // Don't close the last tab

    final tabToClose = _tabs[index];

    // Remove tab from database
    try {
      await _dbHelper.deleteTab(tabToClose.id);
    } catch (e) {
      debugPrint('Error deleting tab from database: $e');
    }

    _tabs[index].controller?.dispose();
    _tabs.removeAt(index);

    if (_activeTabIndex >= index && _activeTabIndex > 0) {
      _activeTabIndex--;
    } else if (_activeTabIndex >= _tabs.length) {
      _activeTabIndex = _tabs.length - 1;
    }

    onTabsChanged?.call();
    onActiveTabChanged?.call(_activeTabIndex);
  }

  Future<void> switchToTab(int index) async {
    if (index < 0 || index >= _tabs.length) return;

    _activeTabIndex = index;
    final tab = _tabs[index];

    // Re-initialize the controller for the new active tab if needed
    if (tab.controller == null && tab.browserController == null) {
      await _initializeTabController(tab);
    }

    // Ensure the webview shows the correct content by loading the URL if needed
    if (tab.controller != null && tab.url != 'about:blank' && tab.url.isNotEmpty) {
      try {
        // Load the URL to ensure the webview displays the correct content
        await tab.controller!.loadUrl(tab.url);
      } catch (e) {
        debugPrint('Error loading URL ${tab.url} when switching tabs: $e');
      }
    }

    _updateActiveTabInDatabase(tab.id);
    onActiveTabChanged?.call(_activeTabIndex);
  }

  Future<void> _updateActiveTabInDatabase(String tabId) async {
    try {
      await _dbHelper.setActiveTab(tabId);
    } catch (e) {
      debugPrint('Error updating active tab: $e');
    }
  }

  Future<void> openUrlInNewTab(String url) async {
    // Create proper title from URL
    String initialTitle = 'New Tab';
    try {
      final host = Uri.parse(url).host;
      initialTitle = host.isNotEmpty ? host : url;
    } catch (_) {
      initialTitle = url;
    }

    await addNewTab(url: url, title: initialTitle);
  }

  Future<void> updateTab(int index, {
    String? url,
    String? title,
    String? faviconUrl,
    String? folderId,
    bool? showNewTabOverlay
  }) async {
    if (index < 0 || index >= _tabs.length) return;

    final tab = _tabs[index];
    if (url != null) tab.url = url;
    if (title != null) tab.title = title;
    if (faviconUrl != null) tab.faviconUrl = faviconUrl;
    // Always update folderId, including when setting to null (moving to root)
    tab.folderId = folderId;
    if (showNewTabOverlay != null) tab.showNewTabOverlay = showNewTabOverlay;

    // Update tab in database
    try {
      await _dbHelper.updateTab(
        id: tab.id,
        url: tab.url,
        title: tab.title,
        faviconUrl: tab.faviconUrl,
        folderId: tab.folderId,
      );
    } catch (e) {
      debugPrint('Error updating tab in database: $e');
    }

    onTabsChanged?.call();
  }

  Future<void> saveAllTabs() async {
    try {
      // Clear existing tabs and save current state
      await _dbHelper.clearAllTabs();

      for (int i = 0; i < _tabs.length; i++) {
        final tab = _tabs[i];
        await _dbHelper.insertTab(
          id: tab.id,
          url: tab.url,
          title: tab.title,
          faviconUrl: tab.faviconUrl,
          isActive: i == _activeTabIndex,
          order: i,
        );
      }
    } catch (e) {
      debugPrint('Error saving tabs: $e');
    }
  }

  // Folder management methods
  Future<void> createFolder(String name, {String? color}) async {
    final folderId = _nextFolderId.toString();
    final folder = TabFolder(
      id: folderId,
      name: name,
      color: color,
      order: _folders.length,
    );

    _folders.add(folder);
    _nextFolderId++;

    // Save folder to database
    try {
      await _dbHelper.insertFolder(
        id: folder.id,
        name: folder.name,
        color: folder.color,
        order: folder.order,
      );
    } catch (e) {
      debugPrint('Error saving folder: $e');
    }

    onTabsChanged?.call();
  }

  Future<void> updateFolder(String folderId, {String? name, String? color}) async {
    final folderIndex = _folders.indexWhere((f) => f.id == folderId);
    if (folderIndex == -1) return;

    final folder = _folders[folderIndex];
    if (name != null) folder.name = name;
    if (color != null) folder.color = color;

    // Update folder in database
    try {
      await _dbHelper.updateFolder(
        id: folder.id,
        name: folder.name,
        color: folder.color,
      );
    } catch (e) {
      debugPrint('Error updating folder: $e');
    }

    onTabsChanged?.call();
  }

  Future<void> deleteFolder(String folderId) async {
    final folderIndex = _folders.indexWhere((f) => f.id == folderId);
    if (folderIndex == -1) return;

    _folders.removeAt(folderIndex);

    // Remove folder from database (this also sets folder_id to null for all tabs in that folder)
    try {
      await _dbHelper.deleteFolder(folderId);
    } catch (e) {
      debugPrint('Error deleting folder: $e');
    }

    onTabsChanged?.call();
  }

  // Move tab to a folder
  Future<void> moveTabToFolder(int tabIndex, String? folderId) async {
    if (tabIndex < 0 || tabIndex >= _tabs.length) return;

    await updateTab(tabIndex, folderId: folderId);
  }

  // Get tabs for a specific folder (null means root level tabs)
  List<TabInfo> getTabsForFolder(String? folderId) {
    return _tabs.where((tab) => tab.folderId == folderId).toList();
  }

  // Get all root level tabs (tabs not in any folder)
  List<TabInfo> get rootTabs => getTabsForFolder(null);

  // AI-powered automatic folder organization
  Future<void> autoOrganizeTabsIntoFolders(Map<String, List<int>> folderOrganization) async {
    if (folderOrganization.isEmpty) {
      // No folders to create
      return;
    }

    try {
      // Create folders and move tabs
      for (final entry in folderOrganization.entries) {
        final folderName = entry.key;
        final tabIndices = entry.value;

        // Create the folder
        await createFolder(folderName);

        // Get the newly created folder ID (it will be the last one in the list)
        final newFolderId = _folders.last.id;

        // Move tabs to the folder
        for (final tabIndex in tabIndices) {
          if (tabIndex >= 0 && tabIndex < _tabs.length) {
            await moveTabToFolder(tabIndex, newFolderId);
          }
        }
      }

      debugPrint('Auto-organized tabs into ${folderOrganization.length} folders');
    } catch (e) {
      debugPrint('Error during auto-organization: $e');
    }
  }

  void dispose() {
    for (final tab in _tabs) {
      tab.controller?.dispose();
      tab.browserController?.dispose();
    }
    _tabs.clear();
  }
}

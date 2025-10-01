import 'package:webview_windows/webview_windows.dart';
import '../services/browser_controller.dart';

class TabInfo {
  static const String _defaultTitle = 'New Tab';

  final String id;
  String url;
  String title;
  String? faviconUrl;
  String? folderId; // ID of the folder this tab belongs to, null means root level
  WebviewController? controller;
  BrowserController? browserController; // For listening to events
  bool isLoading;
  bool showNewTabOverlay;

  TabInfo({
    required this.id,
    required this.url,
    String? title,
    this.faviconUrl,
    this.folderId,
    this.controller,
    this.browserController,
    this.isLoading = false,
    this.showNewTabOverlay = false,
  }) : title = title ?? _defaultTitle;

  // Convert TabInfo to Map for database storage
  Map<String, dynamic> toMap(int order, {bool isActive = false}) {
    return {
      'id': id,
      'url': url,
      'title': title,
      'favicon_url': faviconUrl,
      'folder_id': folderId,
      'is_active': isActive ? 1 : 0,
      'tab_order': order,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // Create TabInfo from database Map
  static TabInfo fromMap(Map<String, dynamic> map) {
    return TabInfo(
      id: map['id'] as String,
      url: map['url'] as String,
      title: map['title'] as String? ?? _defaultTitle,
      faviconUrl: map['favicon_url'] as String?,
      folderId: map['folder_id'] as String?,
      // Note: controllers will be initialized separately
      // isLoading and showNewTabOverlay will use default values
      showNewTabOverlay: (map['url'] as String) == 'about:blank',
    );
  }

  // Create a copy of this TabInfo with updated values
  TabInfo copyWith({
    String? url,
    String? title,
    String? faviconUrl,
    String? folderId,
    WebviewController? controller,
    BrowserController? browserController,
    bool? isLoading,
    bool? showNewTabOverlay,
  }) {
    return TabInfo(
      id: id,
      url: url ?? this.url,
      title: title ?? this.title,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      folderId: folderId ?? this.folderId,
      controller: controller ?? this.controller,
      browserController: browserController ?? this.browserController,
      isLoading: isLoading ?? this.isLoading,
      showNewTabOverlay: showNewTabOverlay ?? this.showNewTabOverlay,
    );
  }
}

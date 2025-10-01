import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';

/// Handler for building and managing WebView context menus
class WebViewContextMenu {
  /// Builds the complete context menu with all available actions
  ContextMenu buildContextMenu() {
    return ContextMenu(
      entries: _buildContextMenuEntries(),
      padding: const EdgeInsets.all(8.0),
    );
  }

  /// Builds all context menu entries
  List<ContextMenuEntry> _buildContextMenuEntries() {
    return [
      _buildHeader(),
      ..._buildAnalysisActions(),
      _buildDivider(),
      ..._buildImageActions(),
      _buildDivider(),
      ..._buildTextActions(),
      _buildDivider(),
      ..._buildLinkActions(),
      _buildDivider(),
      ..._buildDownloadActions(),
    ];
  }

  /// Builds the menu header
  ContextMenuEntry _buildHeader() {
    return const MenuHeader(text: "WebView Actions");
  }

  /// Builds analysis-related menu items
  List<MenuItem> _buildAnalysisActions() {
    return [
      MenuItem(
        label: 'Summarize Website',
        icon: HeroiconsOutline.documentText,
        value: 'summarize_website',
      ),
      MenuItem(
        label: 'Find Key Points',
        icon: HeroiconsOutline.listBullet,
        value: 'find_key_points',
      ),
    ];
  }

  /// Builds image-related menu items
  List<MenuItem> _buildImageActions() {
    return [
      MenuItem(
        label: 'Send Image to AI Chat',
        icon: HeroiconsOutline.photo,
        value: 'send_image_to_chat',
      ),
      MenuItem(
        label: 'Analyze Image',
        icon: HeroiconsOutline.magnifyingGlass,
        value: 'analyze_image',
      ),
    ];
  }

  /// Builds text-related menu items
  List<MenuItem> _buildTextActions() {
    return [
      MenuItem(
        label: 'Ask AI about selected text',
        icon: HeroiconsOutline.chatBubbleLeftRight,
        value: 'ask_about_text',
      ),
      MenuItem(
        label: 'Add to Smart Notes',
        icon: HeroiconsOutline.documentText,
        value: 'add_to_smart_notes',
      ),
    ];
  }

  /// Builds link-related menu items
  List<MenuItem> _buildLinkActions() {
    return [
      MenuItem(
        label: 'Ask AI about this link',
        icon: HeroiconsOutline.link,
        value: 'ask_about_link',
      ),
      MenuItem(
        label: 'Preview Link',
        icon: HeroiconsOutline.eye,
        value: 'preview_link',
      ),
    ];
  }

  /// Builds download-related menu items
  List<MenuItem> _buildDownloadActions() {
    return [
      MenuItem(
        label: 'Download Link',
        icon: HeroiconsOutline.arrowDownTray,
        value: 'download_link',
      ),
      MenuItem(
        label: 'Download Page',
        icon: HeroiconsOutline.documentArrowDown,
        value: 'download_page',
      ),
    ];
  }

  /// Builds a menu divider
  ContextMenuEntry _buildDivider() {
    return const MenuDivider();
  }

  /// Context menu action types
  static const String summarizeWebsite = 'summarize_website';
  static const String findKeyPoints = 'find_key_points';
  static const String sendImageToChat = 'send_image_to_chat';
  static const String analyzeImage = 'analyze_image';
  static const String askAboutText = 'ask_about_text';
  static const String addToSmartNotes = 'add_to_smart_notes';
  static const String askAboutLink = 'ask_about_link';
  static const String previewLink = 'preview_link';
  static const String downloadLink = 'download_link';
  static const String downloadPage = 'download_page';
}

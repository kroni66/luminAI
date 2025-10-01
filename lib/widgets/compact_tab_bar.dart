import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../models/tab_info.dart';

class CompactTabBar extends StatefulWidget {
  final List<TabInfo> tabs;
  final int activeTabIndex;
  final void Function(int index) onSwitchTab;
  final void Function(int index) onCloseTab;
  final void Function() onAddNewTab;
  final void Function()? onOrganizeTabsWithAI;
  final bool isOrganizingTabs;

  const CompactTabBar({
    super.key,
    required this.tabs,
    required this.activeTabIndex,
    required this.onSwitchTab,
    required this.onCloseTab,
    required this.onAddNewTab,
    this.onOrganizeTabsWithAI,
    this.isOrganizingTabs = false,
  });

  @override
  State<CompactTabBar> createState() => _CompactTabBarState();
}

class _CompactTabBarState extends State<CompactTabBar> {
  int? _hoveredIndex;
  bool _isPlusButtonHovered = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getTabTitle(TabInfo tab) {
    // Always use the tab's title if it's set and not the default
    if (tab.title.isNotEmpty && tab.title != 'New Tab') {
      return tab.title;
    }
    // For about:blank URLs, show New Tab
    if (tab.url == 'about:blank') {
      return 'New Tab';
    }
    // For other URLs, try to extract host or use URL as fallback
    try {
      final uri = Uri.parse(tab.url);
      return uri.host.isNotEmpty ? uri.host : tab.url;
    } catch (e) {
      return tab.url.isNotEmpty ? tab.url : 'New Tab';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MoveWindow(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: ShadTheme.of(context).colorScheme.background,
          border: Border(
            bottom: BorderSide(
              color: ShadTheme.of(context).colorScheme.border,
              width: 1,
            ),
          ),
        ),
      child: Row(
        children: [
          // Scrollable tabs
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    for (final entry in widget.tabs.asMap().entries)
                      Builder(
                        builder: (context) {
                          final index = entry.key;
                          final tab = entry.value;
                          final isActive = index == widget.activeTabIndex;
                          final isHovered = _hoveredIndex == index;
                          final title = _getTabTitle(tab);

                          return MouseRegion(
                        onEnter: (_) => setState(() => _hoveredIndex = index),
                        onExit: (_) => setState(() => _hoveredIndex = null),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 2),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => widget.onSwitchTab(index),
                              borderRadius: BorderRadius.circular(6),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                constraints: const BoxConstraints(
                                  minWidth: 120,
                                  maxWidth: 200,
                                ),
                                height: 32,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? ShadTheme.of(context).colorScheme.accent
                                      : isHovered
                                          ? ShadTheme.of(context).colorScheme.muted
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: isActive
                                      ? Border.all(
                                          color: ShadTheme.of(context).colorScheme.ring,
                                          width: 1,
                                        )
                                      : null,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Favicon
                                    if (tab.faviconUrl != null)
                                      Container(
                                        width: 16,
                                        height: 16,
                                        margin: const EdgeInsets.only(right: 8),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(2),
                                          child: Image.network(
                                            tab.faviconUrl!,
                                            width: 16,
                                            height: 16,
                                            fit: BoxFit.contain,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Icon(
                                                Icons.public,
                                                size: 16,
                                                color: ShadTheme.of(context).colorScheme.mutedForeground,
                                              );
                                            },
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        width: 16,
                                        height: 16,
                                        margin: const EdgeInsets.only(right: 8),
                                        child: Icon(
                                          tab.url == 'about:blank' ? Icons.add : Icons.public,
                                          size: 16,
                                          color: ShadTheme.of(context).colorScheme.mutedForeground,
                                        ),
                                      ),
                                    // Title
                                    Flexible(
                                      child: Text(
                                        title,
                                        style: ShadTheme.of(context).textTheme.small.copyWith(
                                          color: isActive
                                              ? ShadTheme.of(context).colorScheme.accentForeground
                                              : ShadTheme.of(context).colorScheme.foreground,
                                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    // Close button
                                    if (widget.tabs.length > 1)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        child: InkWell(
                                          onTap: () => widget.onCloseTab(index),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Container(
                                            width: 16,
                                            height: 16,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(4),
                                              color: isHovered
                                                  ? ShadTheme.of(context).colorScheme.destructive.withOpacity(0.1)
                                                  : Colors.transparent,
                                            ),
                                            child: Icon(
                                              Icons.close,
                                              size: 12,
                                              color: isHovered
                                                  ? ShadTheme.of(context).colorScheme.destructive
                                                  : ShadTheme.of(context).colorScheme.mutedForeground,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                        },
                      ),
                    // Plus button after last tab
                    MouseRegion(
                      onEnter: (_) => setState(() => _isPlusButtonHovered = true),
                      onExit: (_) => setState(() => _isPlusButtonHovered = false),
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        child: InkWell(
                          onTap: widget.onAddNewTab,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: _isPlusButtonHovered
                                  ? ShadTheme.of(context).colorScheme.primary.withOpacity(0.1)
                                  : Colors.transparent,
                              border: Border.all(
                                color: _isPlusButtonHovered
                                    ? ShadTheme.of(context).colorScheme.primary.withOpacity(0.4)
                                    : ShadTheme.of(context).colorScheme.border.withOpacity(0.6),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 14,
                              color: _isPlusButtonHovered
                                  ? ShadTheme.of(context).colorScheme.primary
                                  : ShadTheme.of(context).colorScheme.foreground.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ),
            ),
          ),
          // Action buttons
          Row(
            children: [
              // AI Organization button
              if (widget.onOrganizeTabsWithAI != null)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  child: ShadButton.ghost(
                    onPressed: widget.isOrganizingTabs ? null : widget.onOrganizeTabsWithAI,
                    size: ShadButtonSize.sm,
                    child: widget.isOrganizingTabs
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          )
                        : const Icon(
                            Icons.auto_awesome,
                            size: 16,
                            color: Colors.blue,
                          ),
                  ),
                ),
              // Add new tab button
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: widget.onAddNewTab,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.transparent,
                    ),
                    child: Icon(
                      Icons.add,
                      size: 16,
                      color: ShadTheme.of(context).colorScheme.foreground.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
}

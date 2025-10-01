import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import '../models/tab_info.dart';
import '../models/tab_folder.dart';

// Context Tree Node
class ContextNode {
  final String url;
  String title;
  final List<ContextNode> children;
  final DateTime visitedAt;
  final String? faviconUrl;
  bool isExpanded;

  ContextNode({
    required this.url,
    required this.title,
    required this.visitedAt,
    this.faviconUrl,
    List<ContextNode>? children,
    this.isExpanded = false,
  }) : children = children ?? [];
}

// Context Tree Builder
class ContextTreeBuilder {
  final List<ContextNode> roots = [];
  final Map<String, ContextNode> _urlToNode = {};

  void addNavigation(String fromUrl, String toUrl, String toTitle, {String? faviconUrl}) {
    // Normalize URLs by removing trailing slashes
    final normalizedFromUrl = fromUrl.isEmpty ? '' : _normalizeUrl(fromUrl);
    final normalizedToUrl = _normalizeUrl(toUrl);

    // Handle case where fromUrl is empty (new root node for manually opened tab)
    if (normalizedFromUrl.isEmpty) {
      if (!_urlToNode.containsKey(normalizedToUrl)) {
        final node = ContextNode(
          url: normalizedToUrl,
          title: toTitle,
          visitedAt: DateTime.now(),
          faviconUrl: faviconUrl,
        );
        _urlToNode[normalizedToUrl] = node;

        // Add as a separate root node
        if (!roots.any((root) => root.url == normalizedToUrl)) {
          roots.add(node);
        }
      }
      return;
    }

    final fromDomain = _extractDomain(normalizedFromUrl);
    final toDomain = _extractDomain(normalizedToUrl);

    // If navigating within same domain, add as child
    if (fromDomain == toDomain && _urlToNode.containsKey(normalizedFromUrl)) {
      final parentNode = _urlToNode[normalizedFromUrl]!;
      final childNode = ContextNode(
        url: normalizedToUrl,
        title: toTitle,
        visitedAt: DateTime.now(),
        faviconUrl: faviconUrl,
      );
      _urlToNode[normalizedToUrl] = childNode;

      // Add as child if not already present
      if (!parentNode.children.any((child) => child.url == normalizedToUrl)) {
        parentNode.children.add(childNode);
      }
      return;
    }

    // If different domain or no parent, create new root
    if (!_urlToNode.containsKey(normalizedToUrl)) {
      final node = ContextNode(
        url: normalizedToUrl,
        title: toTitle,
        visitedAt: DateTime.now(),
        faviconUrl: faviconUrl,
      );
      _urlToNode[normalizedToUrl] = node;

      // Add as a new root node
      if (!roots.any((root) => root.url == normalizedToUrl)) {
        roots.add(node);
      }
    }
  }

  void clear() {
    roots.clear();
    _urlToNode.clear();
  }

  // Update the title of an existing node
  void updateNodeTitle(String url, String newTitle) {
    final normalizedUrl = _normalizeUrl(url);
    if (_urlToNode.containsKey(normalizedUrl)) {
      _urlToNode[normalizedUrl]!.title = newTitle;
    }
  }

  // Delete a node from the context tree
  void deleteNode(String url) {
    final normalizedUrl = _normalizeUrl(url);
    if (_urlToNode.containsKey(normalizedUrl)) {
      // Remove from roots if it's a root node
      roots.removeWhere((root) => root.url == normalizedUrl);

      // Remove from parent children if it's a child node
      for (final root in roots) {
        _removeNodeFromTree(root, normalizedUrl);
      }

      // Remove from the URL map
      _urlToNode.remove(normalizedUrl);
    }
  }

  void _removeNodeFromTree(ContextNode node, String urlToRemove) {
    node.children.removeWhere((child) => child.url == urlToRemove);
    for (final child in node.children) {
      _removeNodeFromTree(child, urlToRemove);
    }
  }

  List<ContextNode> getAllNodes() {
    final result = <ContextNode>[];
    for (final root in roots) {
      result.addAll(_flattenTree(root));
    }
    return result;
  }

  List<ContextNode> _flattenTree(ContextNode node) {
    final result = [node];
    for (final child in node.children) {
      result.addAll(_flattenTree(child));
    }
    return result;
  }

  String _normalizeUrl(String url) {
    // Remove trailing slash to normalize URLs
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.scheme}://${uri.host}';
    } catch (e) {
      return url;
    }
  }
}

class TabSidebar extends StatefulWidget {
  final List<TabInfo> tabs;
  final List<TabFolder> folders;
  final int activeTabIndex;
  final double sidebarWidth;
  final ValueChanged<int> onSwitchTab;
  final ValueChanged<int> onCloseTab;
  final VoidCallback onAddNewTab;
  final Function(String)? onOpenUrlInNewTab;
  final Function(TabSidebarState)? onStateCreated;
  final Function(String, {String? color})? onCreateFolder;
  final Function(String, {String? name, String? color})? onUpdateFolder;
  final Function(String)? onDeleteFolder;
  final Function(int, String?)? onMoveTabToFolder;
  final Function(String)? onDeleteContextNode;
  final Function(bool)? onContextModeChanged;
  final VoidCallback? onAutoOrganizeTabs;
  final VoidCallback? onScreenshotButtonPressed;
  final VoidCallback? onSmartNotesButtonPressed;

  const TabSidebar({
    super.key,
    required this.tabs,
    required this.folders,
    required this.activeTabIndex,
    required this.sidebarWidth,
    required this.onSwitchTab,
    required this.onCloseTab,
    required this.onAddNewTab,
    this.onOpenUrlInNewTab,
    this.onStateCreated,
    this.onCreateFolder,
    this.onUpdateFolder,
    this.onDeleteFolder,
    this.onMoveTabToFolder,
    this.onDeleteContextNode,
    this.onContextModeChanged,
    this.onAutoOrganizeTabs,
    this.onScreenshotButtonPressed,
    this.onSmartNotesButtonPressed,
  });

  @override
  State<TabSidebar> createState() => TabSidebarState();
}

class TabSidebarState extends State<TabSidebar> {
  int? _hoveredTabIndex;
  bool _isContextButtonHovered = false;
  bool _isFolderButtonHovered = false;
  bool _isCleanerButtonHovered = false;
  bool _isAddTabButtonHovered = false;
  bool _isContextMode = false;
  final ContextTreeBuilder _contextTreeBuilder = ContextTreeBuilder();
  final Map<String, bool> _expandedFolders = {}; // folderId -> isExpanded
  final TextEditingController _folderNameController = TextEditingController();
  bool _isScreenshotButtonHovered = false;
  bool _isSmartNotesButtonHovered = false;

  String _getDomainFromUrl(String url) {
    if (url.isEmpty || url == 'about:blank') return 'New Tab';
    try {
      final uri = Uri.parse(url);
      final domain = uri.host.isNotEmpty ? uri.host : url.replaceFirst('https://', '').replaceFirst('http://', '');
      return domain.length > 20 ? '${domain.substring(0, 17)}...' : domain;
    } catch (e) {
      return url.length > 20 ? '${url.substring(0, 17)}...' : url;
    }
  }

  @override
  void initState() {
    super.initState();
    widget.onStateCreated?.call(this);
    // Initialize all folders as expanded by default
    for (final folder in widget.folders) {
      _expandedFolders[folder.id] = true;
    }
  }

  List<TabInfo> _getTabsForFolder(String? folderId) {
    return widget.tabs.where((tab) => tab.folderId == folderId).toList();
  }

  List<TabInfo> get _rootTabs => _getTabsForFolder(null);

  void _toggleFolderExpansion(String folderId) {
    setState(() {
      _expandedFolders[folderId] = !(_expandedFolders[folderId] ?? true);
    });
  }

  void _showCreateFolderDialog() {
    _folderNameController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: _folderNameController,
          decoration: const InputDecoration(
            hintText: 'Enter folder name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _folderNameController.text.trim();
              if (name.isNotEmpty && widget.onCreateFolder != null) {
                widget.onCreateFolder!(name);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameFolderDialog(TabFolder folder) {
    _folderNameController.text = folder.name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: _folderNameController,
          decoration: const InputDecoration(
            hintText: 'Enter new folder name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _folderNameController.text.trim();
              if (name.isNotEmpty && name != folder.name && widget.onUpdateFolder != null) {
                widget.onUpdateFolder!(folder.id, name: name);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: Container(
        width: widget.sidebarWidth,
        decoration: BoxDecoration(
          color: ShadTheme.of(context).colorScheme.card,
          border: Border(
            right: BorderSide(
              color: ShadTheme.of(context).colorScheme.border,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: Column(
          children: [
            // Tabs header
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: ShadTheme.of(context).colorScheme.border,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    _isContextMode ? 'Context Tree' : 'Tabs',
                    style: ShadTheme.of(context).textTheme.h4.copyWith(
                      color: ShadTheme.of(context).colorScheme.foreground,
                    ),
                  ),
                  const Spacer(),
                  // Context Mode Toggle
                  MouseRegion(
                    onEnter: (_) => setState(() => _isContextButtonHovered = true),
                    onExit: (_) => setState(() => _isContextButtonHovered = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: _isContextButtonHovered
                          ? [
                              BoxShadow(
                                color: (_isContextMode ? Colors.blue : Colors.grey).withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                      ),
                      child:                         OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _isContextMode = !_isContextMode;
                              if (!_isContextMode) {
                                _contextTreeBuilder.clear();
                              }
                            });
                            // Notify parent of context mode change
                            widget.onContextModeChanged?.call(_isContextMode);
                          },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(20, 20),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          side: BorderSide(
                            color: _isContextMode
                              ? Colors.blue
                              : _isContextButtonHovered
                                ? ShadTheme.of(context).colorScheme.primary
                                : ShadTheme.of(context).colorScheme.border,
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          foregroundColor: _isContextMode
                            ? Colors.blue
                            : _isContextButtonHovered
                              ? ShadTheme.of(context).colorScheme.primary
                              : ShadTheme.of(context).colorScheme.foreground,
                          backgroundColor: _isContextMode
                            ? Colors.blue.withOpacity(0.1)
                            : _isContextButtonHovered
                              ? ShadTheme.of(context).colorScheme.primary.withOpacity(0.1)
                              : ShadTheme.of(context).colorScheme.card,
                        ),
                        child: Tooltip(
                          message: _isContextMode ? 'Exit Context Mode' : 'Enter Context Mode',
                          child: Icon(
                            _isContextMode ? HeroiconsOutline.eyeSlash : HeroiconsOutline.eye,
                            size: 12
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Folder creation button
                  if (!_isContextMode)
                    MouseRegion(
                      onEnter: (_) => setState(() => _isFolderButtonHovered = true),
                      onExit: (_) => setState(() => _isFolderButtonHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: _isFolderButtonHovered
                            ? LinearGradient(
                                colors: [
                                  Colors.blue.withOpacity(0.2),
                                  Colors.blue.withOpacity(0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.transparent,
                                ],
                              ),
                          border: Border.all(
                            color: _isFolderButtonHovered
                              ? Colors.blue.withOpacity(0.4)
                              : ShadTheme.of(context).colorScheme.border.withOpacity(0.6),
                            width: 1.5,
                          ),
                          boxShadow: _isFolderButtonHovered
                            ? [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                        ),
                        child: InkWell(
                          onTap: _showCreateFolderDialog,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            child: Icon(
                              HeroiconsOutline.folderPlus,
                              size: 14,
                              color: _isFolderButtonHovered
                                ? Colors.blue
                                : ShadTheme.of(context).colorScheme.foreground.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // AI Cleaner button
                  if (!_isContextMode)
                    MouseRegion(
                      onEnter: (_) => setState(() => _isCleanerButtonHovered = true),
                      onExit: (_) => setState(() => _isCleanerButtonHovered = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: _isCleanerButtonHovered
                            ? LinearGradient(
                                colors: [
                                  Colors.green.withOpacity(0.2),
                                  Colors.green.withOpacity(0.1),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.transparent,
                                ],
                              ),
                          border: Border.all(
                            color: _isCleanerButtonHovered
                              ? Colors.green.withOpacity(0.4)
                              : ShadTheme.of(context).colorScheme.border.withOpacity(0.6),
                            width: 1.5,
                          ),
                          boxShadow: _isCleanerButtonHovered
                            ? [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                        ),
                        child: InkWell(
                          onTap: widget.onAutoOrganizeTabs,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            child: Icon(
                              HeroiconsOutline.sparkles,
                              size: 14,
                              color: _isCleanerButtonHovered
                                ? Colors.green
                                : ShadTheme.of(context).colorScheme.foreground.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  MouseRegion(
                    onEnter: (_) => setState(() => _isAddTabButtonHovered = true),
                    onExit: (_) => setState(() => _isAddTabButtonHovered = false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: _isAddTabButtonHovered
                          ? LinearGradient(
                              colors: [
                                ShadTheme.of(context).colorScheme.primary.withOpacity(0.2),
                                ShadTheme.of(context).colorScheme.primary.withOpacity(0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                              ],
                            ),
                        border: Border.all(
                          color: _isAddTabButtonHovered
                            ? ShadTheme.of(context).colorScheme.primary.withOpacity(0.4)
                            : ShadTheme.of(context).colorScheme.border.withOpacity(0.6),
                          width: 1.5,
                        ),
                        boxShadow: _isAddTabButtonHovered
                          ? [
                              BoxShadow(
                                color: ShadTheme.of(context).colorScheme.primary.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                      ),
                      child: InkWell(
                        onTap: widget.onAddNewTab,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          child: Icon(
                            HeroiconsOutline.plus,
                            size: 14,
                            color: _isAddTabButtonHovered
                              ? ShadTheme.of(context).colorScheme.primary
                              : ShadTheme.of(context).colorScheme.foreground.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content area - either tabs list or context tree
            Expanded(
              child: _isContextMode
                ? _buildContextTreeView()
                : _buildFoldersAndTabsView(),
            ),

            // Bottom buttons (Smart Notes and Screenshot)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: ShadTheme.of(context).colorScheme.border,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  _buildSmartNotesButton(),
                  const SizedBox(height: 8),
                  _buildScreenshotButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoldersAndTabsView() {
    final List<Widget> items = [];

    // Add root tabs area (with drop target for moving tabs to root)
    if (_rootTabs.isNotEmpty) {
      items.add(_buildRootTabsArea());
    }

    // Add folders with their tabs
    for (final folder in widget.folders) {
      items.add(_buildFolderItem(folder));
      if (_expandedFolders[folder.id] ?? true) {
        final folderTabs = _getTabsForFolder(folder.id);
        for (int i = 0; i < folderTabs.length; i++) {
          final tabIndex = widget.tabs.indexOf(folderTabs[i]);
          items.add(_buildTabItem(folderTabs[i], tabIndex, isInFolder: true));
        }
      }
    }

    return ListView(
      children: items,
    );
  }

  Widget _buildRootTabsArea() {
    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final tabIndex = details.data;
        if (widget.onMoveTabToFolder != null) {
          widget.onMoveTabToFolder!(tabIndex, null); // Move to root (no folder)
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isBeingDraggedOver = candidateData.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drop target indicator when dragging
            if (isBeingDraggedOver)
              Container(
                margin: const EdgeInsets.only(left: 6, right: 6, top: 4, bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.blue.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      HeroiconsOutline.home,
                      size: 12,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Drop to move to root',
                      style: ShadTheme.of(context).textTheme.small.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),

            // Root tabs
            ..._rootTabs.map((tab) {
              final tabIndex = widget.tabs.indexOf(tab);
              return _buildTabItem(tab, tabIndex);
            }),
          ],
        );
      },
    );
  }

  Widget _buildFolderItem(TabFolder folder) {
    final folderTabs = _getTabsForFolder(folder.id);
    final isExpanded = _expandedFolders[folder.id] ?? true;
    final isHovered = _hoveredTabIndex == 'folder_${folder.id}'.hashCode;

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final tabIndex = details.data;
        if (widget.onMoveTabToFolder != null) {
          widget.onMoveTabToFolder!(tabIndex, folder.id);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isBeingDraggedOver = candidateData.isNotEmpty;

        return MouseRegion(
          onEnter: (_) => setState(() => _hoveredTabIndex = 'folder_${folder.id}'.hashCode),
          onExit: (_) => setState(() => _hoveredTabIndex = null),
          child: GestureDetector(
            onTap: () => _toggleFolderExpansion(folder.id),
            onDoubleTap: () => _showRenameFolderDialog(folder),
            onSecondaryTapDown: (details) => _showFolderContextMenu(details.globalPosition, folder),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isBeingDraggedOver
                  ? Colors.blue.withOpacity(0.1)
                  : isHovered
                    ? Colors.blue.withOpacity(0.05)
                    : Colors.transparent,
                border: Border.all(
                  color: isBeingDraggedOver
                    ? Colors.blue.withOpacity(0.4)
                    : isHovered
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? HeroiconsOutline.folderOpen : HeroiconsOutline.folder,
                    size: 16,
                    color: (isBeingDraggedOver || isHovered)
                      ? Colors.blue
                      : ShadTheme.of(context).colorScheme.foreground.withOpacity(0.8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      folder.name,
                      style: ShadTheme.of(context).textTheme.small.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (isBeingDraggedOver || isHovered)
                          ? Colors.blue
                          : ShadTheme.of(context).colorScheme.foreground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${folderTabs.length}',
                    style: ShadTheme.of(context).textTheme.muted.copyWith(
                      fontSize: 10,
                      color: ShadTheme.of(context).colorScheme.mutedForeground.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isExpanded ? HeroiconsOutline.chevronDown : HeroiconsOutline.chevronRight,
                    size: 12,
                    color: ShadTheme.of(context).colorScheme.mutedForeground.withOpacity(0.6),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabItem(TabInfo tab, int tabIndex, {bool isInFolder = false}) {
    final isActive = tabIndex == widget.activeTabIndex;
    final isHovered = _hoveredTabIndex == tabIndex;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredTabIndex = tabIndex),
      onExit: (_) => setState(() => _hoveredTabIndex = null),
      child: Draggable<int>(
        data: tabIndex,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: widget.sidebarWidth - (isInFolder ? 26 : 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: ShadTheme.of(context).colorScheme.card.withOpacity(0.9),
              border: Border.all(
                color: ShadTheme.of(context).colorScheme.primary.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: ShadTheme.of(context).colorScheme.primary.withOpacity(0.2),
                  ),
                  child: tab.faviconUrl != null && tab.faviconUrl!.isNotEmpty
                    ? Image.network(tab.faviconUrl!, fit: BoxFit.contain)
                    : Center(
                        child: Text(
                          tab.title.isNotEmpty ? tab.title[0].toUpperCase() : '•',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: ShadTheme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                ),
                Expanded(
                  child: Text(
                    tab.title.isEmpty ? 'New Tab' : tab.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ShadTheme.of(context).textTheme.small.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ShadTheme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: _buildTabItemContent(tab, tabIndex, isActive, isHovered, isInFolder),
        ),
        child: _buildTabItemContent(tab, tabIndex, isActive, isHovered, isInFolder),
      ),
    );
  }

  Widget _buildTabItemContent(TabInfo tab, int tabIndex, bool isActive, bool isHovered, bool isInFolder) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: EdgeInsets.only(
        left: isInFolder ? 20 : 6,
        right: 6,
        top: 2,
        bottom: 2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: isActive
          ? LinearGradient(
              colors: [
                ShadTheme.of(context).colorScheme.primary.withOpacity(0.2),
                ShadTheme.of(context).colorScheme.primary.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : isHovered
            ? LinearGradient(
                colors: [
                  ShadTheme.of(context).colorScheme.muted.withOpacity(0.6),
                  ShadTheme.of(context).colorScheme.muted.withOpacity(0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.transparent, Colors.transparent],
              ),
        border: Border.all(
          color: isActive
            ? ShadTheme.of(context).colorScheme.primary.withOpacity(0.5)
            : isHovered
              ? ShadTheme.of(context).colorScheme.primary.withOpacity(0.2)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isActive
          ? [
              BoxShadow(
                color: ShadTheme.of(context).colorScheme.primary.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
                spreadRadius: 1,
              ),
            ]
          : isHovered
            ? [
                BoxShadow(
                  color: ShadTheme.of(context).colorScheme.primary.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: GestureDetector(
        onSecondaryTapDown: (details) => _showTabContextMenu(details.globalPosition, tabIndex),
        child: InkWell(
          onTap: () => widget.onSwitchTab(tabIndex),
          borderRadius: BorderRadius.circular(10),
          child: Row(
          children: [
            // Enhanced favicon with better styling
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: isActive
                  ? ShadTheme.of(context).colorScheme.primary.withOpacity(0.2)
                  : ShadTheme.of(context).colorScheme.muted.withOpacity(0.8),
                border: Border.all(
                  color: isActive
                    ? ShadTheme.of(context).colorScheme.primary.withOpacity(0.4)
                    : isHovered
                      ? ShadTheme.of(context).colorScheme.primary.withOpacity(0.2)
                      : Colors.transparent,
                  width: 1,
                ),
                boxShadow: isActive || isHovered
                  ? [
                      BoxShadow(
                        color: ShadTheme.of(context).colorScheme.primary.withOpacity(0.15),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: tab.faviconUrl != null && tab.faviconUrl!.isNotEmpty
                ? Image.network(
                    tab.faviconUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        tab.title.isNotEmpty ? tab.title[0].toUpperCase() : '•',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: ShadTheme.of(context).colorScheme.foreground,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      tab.title.isNotEmpty ? tab.title[0].toUpperCase() : '•',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isActive
                          ? ShadTheme.of(context).colorScheme.primary
                          : ShadTheme.of(context).colorScheme.foreground,
                      ),
                    ),
                  ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: ShadTheme.of(context).textTheme.small.copyWith(
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                            color: isActive
                              ? ShadTheme.of(context).colorScheme.primary
                              : isHovered
                                ? ShadTheme.of(context).colorScheme.primary.withOpacity(0.8)
                                : ShadTheme.of(context).colorScheme.foreground,
                            height: 1.2,
                          ),
                          child: Text(
                            tab.title.isEmpty ? 'New Tab' : tab.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (tab.controller == null)
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                          ),
                        ),
                    ],
                  ),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    style: ShadTheme.of(context).textTheme.muted.copyWith(
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      color: isActive
                        ? ShadTheme.of(context).colorScheme.primary.withOpacity(0.7)
                        : isHovered
                          ? ShadTheme.of(context).colorScheme.mutedForeground.withOpacity(0.8)
                          : ShadTheme.of(context).colorScheme.mutedForeground.withOpacity(0.6),
                      letterSpacing: 0.2,
                    ),
                    child: Text(
                      _getDomainFromUrl(tab.url),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.tabs.length > 1)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: isHovered || isActive ? 1.0 : 0.4,
                child: Tooltip(
                  message: 'Close tab',
                  preferBelow: false,
                  child: Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isHovered
                        ? ShadTheme.of(context).colorScheme.destructive.withOpacity(0.1)
                        : Colors.transparent,
                    ),
                    child: IconButton(
                      onPressed: () => widget.onCloseTab(tabIndex),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 20, height: 20),
                      iconSize: 14,
                      splashRadius: 12,
                      hoverColor: ShadTheme.of(context).colorScheme.destructive.withOpacity(0.1),
                      icon: Icon(
                        HeroiconsOutline.xMark,
                        size: 14,
                        color: isHovered
                          ? ShadTheme.of(context).colorScheme.destructive
                          : ShadTheme.of(context).colorScheme.mutedForeground.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildContextTreeView() {
    final allRoots = _contextTreeBuilder.roots;
    if (allRoots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              HeroiconsOutline.eye,
              size: 48,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Start browsing to build your context tree',
              style: ShadTheme.of(context).textTheme.small.copyWith(
                color: Colors.grey.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView(
      children: allRoots.map((root) => _buildTreeNode(root, 0)).toList(),
    );
  }

  Widget _buildTreeNode(ContextNode node, int depth) {
    final isHovered = _hoveredTabIndex == node.url.hashCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _hoveredTabIndex = node.url.hashCode),
          onExit: (_) => setState(() => _hoveredTabIndex = null),
            child: GestureDetector(
            onTap: () {
              // Find if this URL is already open in a tab
              final tabIndex = widget.tabs.indexWhere((tab) => tab.url == node.url);
              if (tabIndex >= 0) {
                widget.onSwitchTab(tabIndex);
              } else {
                // Open URL in new tab
                if (widget.onOpenUrlInNewTab != null) {
                  widget.onOpenUrlInNewTab!(node.url);
                } else {
                  // Fallback to creating empty new tab
                  widget.onAddNewTab();
                }
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(left: depth * 16.0, top: 2, bottom: 2, right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: isHovered
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.transparent,
                border: Border(
                  left: BorderSide(
                    color: Colors.blue.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Expand/collapse icon for nodes with children
                  if (node.children.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          // Update the node in the tree
                          _toggleNodeExpansion(node);
                        });
                      },
                      child: Icon(
                        node.isExpanded ? HeroiconsOutline.chevronDown : HeroiconsOutline.chevronRight,
                        size: 12,
                        color: Colors.blue,
                      ),
                    )
                  else
                    const SizedBox(width: 12),

                  // Favicon
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(left: 4, right: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: Colors.grey.withOpacity(0.3),
                    ),
                    child: node.faviconUrl != null && node.faviconUrl!.isNotEmpty
                      ? Image.network(node.faviconUrl!, fit: BoxFit.contain)
                      : Center(
                          child: Text(
                            node.title.isNotEmpty ? node.title[0] : '•',
                            style: const TextStyle(fontSize: 8),
                          ),
                        ),
                  ),

                  // Title
                  Expanded(
                    child: Text(
                      node.title,
                      style: TextStyle(
                        fontSize: 11,
                        color: isHovered ? Colors.blue : Colors.white,
                        fontWeight: isHovered ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Visit time
                  Text(
                    _formatTimeAgo(node.visitedAt),
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.withOpacity(0.6),
                    ),
                  ),

                  // Delete button (available for all nodes in context tree)
                  Tooltip(
                    message: 'Delete from context tree',
                    preferBelow: false,
                    child: Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: isHovered
                          ? ShadTheme.of(context).colorScheme.destructive.withOpacity(0.1)
                          : Colors.transparent,
                      ),
                      child: IconButton(
                        onPressed: () {
                          if (widget.onDeleteContextNode != null) {
                            widget.onDeleteContextNode!(node.url);
                          } else {
                            // Fallback: call the state method directly
                            deleteContextNode(node.url);
                          }
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(width: 18, height: 18),
                        iconSize: 14,
                        splashRadius: 12,
                        hoverColor: ShadTheme.of(context).colorScheme.destructive.withOpacity(0.1),
                        icon: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: isHovered ? 1.0 : 0.4,
                          child: Icon(
                            HeroiconsOutline.xMark,
                            size: 14,
                            color: isHovered
                              ? ShadTheme.of(context).colorScheme.destructive
                              : ShadTheme.of(context).colorScheme.mutedForeground.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Children (only if expanded)
        if (node.isExpanded && node.children.isNotEmpty)
          ...node.children.map((child) => _buildTreeNode(child, depth + 1)),
      ],
    );
  }

  void _toggleNodeExpansion(ContextNode node) {
    // Find and update the node in our tree
    final allNodes = _contextTreeBuilder.getAllNodes();
    final targetNode = allNodes.firstWhere(
      (n) => n.url == node.url,
      orElse: () => node,
    );

    targetNode.isExpanded = !targetNode.isExpanded;
  }

  String _formatTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    return '${difference.inDays}d';
  }

  void _showTabContextMenu(Offset position, int tabIndex) {
    final tab = widget.tabs[tabIndex];
    final currentFolderId = tab.folderId;

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        // Move to root option (only show if tab is in a folder)
        if (currentFolderId != null)
          PopupMenuItem<String>(
            value: 'move_to_root',
            child: Row(
              children: [
                Icon(HeroiconsOutline.home, size: 16),
                const SizedBox(width: 8),
                const Text('Move to Root'),
              ],
            ),
          ),

        // Move to folder options
        ...widget.folders.where((folder) => folder.id != currentFolderId).map((folder) {
          return PopupMenuItem<String>(
            value: 'move_to_folder_${folder.id}',
            child: Row(
              children: [
                Icon(HeroiconsOutline.folder, size: 16),
                const SizedBox(width: 8),
                Text('Move to ${folder.name}'),
              ],
            ),
          );
        }),
      ],
    ).then((value) {
      if (value != null && widget.onMoveTabToFolder != null) {
        if (value == 'move_to_root') {
          widget.onMoveTabToFolder!(tabIndex, null);
        } else if (value.startsWith('move_to_folder_')) {
          final folderId = value.substring('move_to_folder_'.length);
          widget.onMoveTabToFolder!(tabIndex, folderId);
        }
      }
    });
  }

  void _showFolderContextMenu(Offset position, TabFolder folder) {
    print('Showing folder context menu for folder: ${folder.name} at position: $position');
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        PopupMenuItem<String>(
          value: 'rename',
          child: Row(
            children: [
              Icon(HeroiconsOutline.documentText, size: 16),
              const SizedBox(width: 8),
              const Text('Rename Folder'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(HeroiconsOutline.trash, size: 16, color: ShadTheme.of(context).colorScheme.destructive),
              const SizedBox(width: 8),
              Text('Delete Folder', style: TextStyle(color: ShadTheme.of(context).colorScheme.destructive)),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null) {
        switch (value) {
          case 'rename':
            _showRenameFolderDialog(folder);
            break;
          case 'delete':
            if (widget.onDeleteFolder != null) {
              widget.onDeleteFolder!(folder.id);
            }
            break;
        }
      }
    });
  }

  // Method to track navigation (called from browser_screen)
  void trackNavigation(String fromUrl, String toUrl, String toTitle, {String? faviconUrl}) {
    if (_isContextMode) {
      _contextTreeBuilder.addNavigation(fromUrl, toUrl, toTitle, faviconUrl: faviconUrl);
      setState(() {}); // Refresh the tree view
    }
  }

  // Method to update node title when page title loads
  void updateNodeTitle(String url, String newTitle) {
    if (_isContextMode) {
      _contextTreeBuilder.updateNodeTitle(url, newTitle);
      setState(() {}); // Refresh the tree view
    }
  }

  // Method to delete a node from the context tree
  void deleteContextNode(String url) {
    if (_isContextMode) {
      _contextTreeBuilder.deleteNode(url);
      setState(() {}); // Refresh the tree view
    }
  }

  // Method to get all context nodes (for external access)
  List<ContextNode> getAllContextNodes() {
    if (_isContextMode) {
      return _contextTreeBuilder.getAllNodes();
    }
    return [];
  }

  // Method to check if context mode is enabled
  bool get isContextModeEnabled => _isContextMode;

  Widget _buildSmartNotesButton() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isSmartNotesButtonHovered = true),
      onExit: (_) => setState(() => _isSmartNotesButtonHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: _isSmartNotesButtonHovered
            ? LinearGradient(
                colors: [
                  Colors.purple.withOpacity(0.2),
                  Colors.purple.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.transparent, Colors.transparent],
              ),
          border: Border.all(
            color: _isSmartNotesButtonHovered
              ? Colors.purple.withOpacity(0.4)
              : ShadTheme.of(context).colorScheme.border.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: _isSmartNotesButtonHovered
            ? [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                  spreadRadius: 1,
                ),
              ]
            : null,
        ),
        child: InkWell(
          onTap: widget.onSmartNotesButtonPressed,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                HeroiconsOutline.documentText,
                size: 16,
                color: _isSmartNotesButtonHovered
                  ? Colors.purple
                  : ShadTheme.of(context).colorScheme.foreground.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
              Text(
                'Smart Notes',
                style: ShadTheme.of(context).textTheme.small.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _isSmartNotesButtonHovered
                    ? Colors.purple
                    : ShadTheme.of(context).colorScheme.foreground.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreenshotButton() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isScreenshotButtonHovered = true),
      onExit: (_) => setState(() => _isScreenshotButtonHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: _isScreenshotButtonHovered
            ? LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.2),
                  Colors.blue.withOpacity(0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [Colors.transparent, Colors.transparent],
              ),
          border: Border.all(
            color: _isScreenshotButtonHovered
              ? Colors.blue.withOpacity(0.4)
              : ShadTheme.of(context).colorScheme.border.withOpacity(0.6),
            width: 1.5,
          ),
          boxShadow: _isScreenshotButtonHovered
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                  spreadRadius: 1,
                ),
              ]
            : null,
        ),
        child: InkWell(
          onTap: widget.onScreenshotButtonPressed,
          borderRadius: BorderRadius.circular(10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                HeroiconsOutline.camera,
                size: 16,
                color: _isScreenshotButtonHovered
                  ? Colors.blue
                  : ShadTheme.of(context).colorScheme.foreground.withOpacity(0.8),
              ),
              const SizedBox(width: 8),
              Text(
                'Screenshot',
                style: ShadTheme.of(context).textTheme.small.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _isScreenshotButtonHovered
                    ? Colors.blue
                    : ShadTheme.of(context).colorScheme.foreground.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

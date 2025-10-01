import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import '../services/history_manager.dart';

class BrowserAppBar extends StatefulWidget implements PreferredSizeWidget {
  final bool canGoBack;
  final bool canGoForward;
  final TextEditingController urlController;
  final VoidCallback onGoHome;
  final VoidCallback onGoBack;
  final VoidCallback onGoForward;
  final VoidCallback onRefresh;
  final ValueChanged<String> onNavigateToUrl;
  final VoidCallback onAddBookmark;
  final VoidCallback onShowBookmarks;
  final VoidCallback onShowHistory;
  final VoidCallback onShowDownloads;
  final VoidCallback onAddNewTab;
  final VoidCallback onToggleChat;
  final VoidCallback onShowSettings;
  final String? currentFaviconUrl;
  final HistoryManager historyManager;
  final Function(List<HistoryEntry>, String) onShowSuggestions;
  final VoidCallback onHideSuggestions;
  final VoidCallback? onToggleHighlights;
  final VoidCallback? onArrowUp;
  final VoidCallback? onArrowDown;
  final VoidCallback? onEnterKey;
  final bool updateAvailable;

  const BrowserAppBar({
    Key? key,
    required this.canGoBack,
    required this.canGoForward,
    required this.urlController,
    required this.onGoHome,
    required this.onGoBack,
    required this.onGoForward,
    required this.onRefresh,
    required this.onNavigateToUrl,
    required this.onAddBookmark,
    required this.onShowBookmarks,
    required this.onShowHistory,
    required this.onShowDownloads,
    required this.onAddNewTab,
    required this.onToggleChat,
    required this.onShowSettings,
    this.currentFaviconUrl,
    required this.historyManager,
    required this.onShowSuggestions,
    required this.onHideSuggestions,
    this.onToggleHighlights,
    this.onArrowUp,
    this.onArrowDown,
    this.onEnterKey,
    required this.updateAvailable,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  State<BrowserAppBar> createState() => BrowserAppBarState();
}


class BrowserAppBarState extends State<BrowserAppBar> {
  String _currentQuery = '';
  bool _isProgrammaticChange = false;
  bool _enterKeyHandled = false;

  @override
  void initState() {
    super.initState();
    // Listen to text changes to show suggestions
    widget.urlController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.urlController.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.urlController.text;
    if (text != _currentQuery) {
      _currentQuery = text;
      // Only update suggestions if this is not a programmatic change
      if (!_isProgrammaticChange) {
        _updateSuggestions();
      }
    }
  }

  void _updateSuggestions() {
    if (_currentQuery.isEmpty) {
      widget.onHideSuggestions();
      return;
    }

    final suggestions = widget.historyManager.searchHistory(_currentQuery);
    if (suggestions.isNotEmpty) {
      widget.onShowSuggestions(suggestions, _currentQuery);
    } else {
      widget.onHideSuggestions();
    }
  }

  void setUrlProgrammatically(String url) {
    _isProgrammaticChange = true;
    widget.urlController.text = url;
    _isProgrammaticChange = false;
  }

  @override
  Widget build(BuildContext context) {
    Widget outlinedIconButton({required VoidCallback? onPressed, required Widget child}) {
      final colors = ShadTheme.of(context).colorScheme;
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(32, 32),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          side: BorderSide(color: colors.border, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          foregroundColor: colors.foreground,
          backgroundColor: colors.card,
        ),
        child: child,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(
          children: [
            outlinedIconButton(onPressed: widget.onGoHome, child: Icon(HeroiconsOutline.home, size: 14)),
            MoveWindow(child: const SizedBox(width: 6)),
            Stack(
              clipBehavior: Clip.none,
              children: [
                outlinedIconButton(onPressed: widget.onShowSettings, child: Icon(HeroiconsOutline.cog6Tooth, size: 14)),
                if (widget.updateAvailable)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            MoveWindow(child: const SizedBox(width: 6)),
            outlinedIconButton(onPressed: widget.canGoBack ? widget.onGoBack : null, child: Icon(HeroiconsOutline.arrowLeft, size: 14, color: widget.canGoBack ? null : Colors.grey.withOpacity(0.5))),
            MoveWindow(child: const SizedBox(width: 6)),
            outlinedIconButton(onPressed: widget.canGoForward ? widget.onGoForward : null, child: Icon(HeroiconsOutline.arrowRight, size: 14, color: widget.canGoForward ? null : Colors.grey.withOpacity(0.5))),
            MoveWindow(child: const SizedBox(width: 6)),
            outlinedIconButton(onPressed: widget.onRefresh, child: Icon(HeroiconsOutline.arrowPath, size: 14)),
            MoveWindow(child: const SizedBox(width: 8)),
            Expanded(
              child: MoveWindow(
                child: SizedBox(
                  height: 48,
                  child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      // Delay dismissal to allow suggestion clicks
                      Future.delayed(const Duration(milliseconds: 150), () {
                        if (!mounted) return;
                        widget.onHideSuggestions();
                      });
                    }
                  },
                  child: GestureDetector(
                      onDoubleTap: () {
                        // Select all text when double-clicking instead of minimizing window
                        widget.urlController.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: widget.urlController.text.length,
                        );
                      },
                      child: KeyboardListener(
                        focusNode: FocusNode(),
                        onKeyEvent: (KeyEvent event) {
                          if (event is KeyDownEvent) {
                            final logicalKey = event.logicalKey;
                            if (logicalKey == LogicalKeyboardKey.arrowUp) {
                              widget.onArrowUp?.call();
                            } else if (logicalKey == LogicalKeyboardKey.arrowDown) {
                              widget.onArrowDown?.call();
                            } else if (logicalKey == LogicalKeyboardKey.enter) {
                              _enterKeyHandled = true;
                              widget.onEnterKey?.call();
                              // Reset the flag after this frame
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _enterKeyHandled = false;
                              });
                            }
                          }
                        },
                        child: TextField(
                          controller: widget.urlController,
                          onSubmitted: (value) {
                            // Don't handle submission if we already handled the Enter key
                            if (_enterKeyHandled) return;
                            widget.onHideSuggestions();
                            widget.onNavigateToUrl(value);
                          },
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                      color: ShadTheme.of(context).colorScheme.foreground,
                      height: 1.2,
                    ),
                    cursorColor: ShadTheme.of(context).colorScheme.primary,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: ShadTheme.of(context).colorScheme.background,
                      hintText: 'Search or enter website URL...',
                      hintStyle: TextStyle(color: ShadTheme.of(context).colorScheme.mutedForeground),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      prefixIcon: widget.currentFaviconUrl != null && widget.currentFaviconUrl!.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                widget.currentFaviconUrl!,
                                width: 16,
                                height: 16,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    HeroiconsOutline.globeAlt,
                                    size: 16,
                                    color: ShadTheme.of(context).colorScheme.mutedForeground,
                                  );
                                },
                              ),
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Icon(
                              HeroiconsOutline.globeAlt,
                              size: 16,
                              color: ShadTheme.of(context).colorScheme.mutedForeground,
                            ),
                          ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: ShadTheme.of(context).colorScheme.border, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: ShadTheme.of(context).colorScheme.primary, width: 1.5),
                        ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ),
          outlinedIconButton(
              onPressed: widget.onAddBookmark,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(HeroiconsOutline.bookmark, size: 14),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Icon(HeroiconsOutline.plus, size: 9, color: ShadTheme.of(context).colorScheme.primary),
                  ),
                ],
              ),
            ),
            MoveWindow(child: const SizedBox(width: 6)),
            outlinedIconButton(onPressed: widget.onShowBookmarks, child: Icon(HeroiconsOutline.bookmark, size: 14)),
            MoveWindow(child: const SizedBox(width: 6)),
            outlinedIconButton(onPressed: widget.onShowHistory, child: Icon(HeroiconsOutline.clock, size: 14)),
            MoveWindow(child: const SizedBox(width: 6)),
            outlinedIconButton(onPressed: widget.onShowDownloads, child: Icon(HeroiconsOutline.arrowDownTray, size: 14)),
            MoveWindow(child: const SizedBox(width: 6)),
            outlinedIconButton(onPressed: widget.onToggleChat, child: Icon(HeroiconsOutline.cpuChip, size: 14)),
            if (widget.onToggleHighlights != null) ...[
              MoveWindow(child: const SizedBox(width: 6)),
              outlinedIconButton(onPressed: widget.onToggleHighlights, child: Icon(HeroiconsOutline.eye, size: 14)),
            ],
          ],
        ),
      ],
    );
  }
}

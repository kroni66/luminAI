import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:blurbox/blurbox.dart';

class BookmarkWindow extends StatefulWidget {
  final List<String> bookmarks;
  final ValueChanged<String> onBookmarkTap;
  final Future<void> Function(int) onDeleteBookmark;

  const BookmarkWindow({
    Key? key,
    required this.bookmarks,
    required this.onBookmarkTap,
    required this.onDeleteBookmark,
  }) : super(key: key);

  @override
  State<BookmarkWindow> createState() => _BookmarkWindowState();
}

class _BookmarkWindowState extends State<BookmarkWindow> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _filteredBookmarks = [];

  @override
  void initState() {
    super.initState();
    _filteredBookmarks = widget.bookmarks;
    _searchController.addListener(_filterBookmarks);
  }

  @override
  void didUpdateWidget(BookmarkWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookmarks != widget.bookmarks) {
      _filterBookmarks();
    }
  }

  void _filterBookmarks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredBookmarks = widget.bookmarks
          .where((bookmark) => bookmark.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: BlurBox(
        blur: 20.0,
        color: ShadTheme.of(context).colorScheme.background.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 500,
          height: 450, // Increased height to accommodate header
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
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
                      'Bookmarks',
                      style: ShadTheme.of(context).textTheme.h4,
                    ),
                    const Spacer(),
                    ShadButton(
                      onPressed: () => Navigator.pop(context),
                      size: ShadButtonSize.sm,
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Search bar
                      ShadInput(
                        controller: _searchController,
                      ),
                      const SizedBox(height: 16),

                      // Bookmarks list
                      Expanded(
                        child: _filteredBookmarks.isEmpty
                            ? Center(
                                child: Text(
                                  widget.bookmarks.isEmpty
                                      ? 'No bookmarks yet'
                                      : 'No bookmarks match your search',
                                  style: ShadTheme.of(context).textTheme.muted,
                                ),
                              )
                            : ListView.builder(
                                itemCount: _filteredBookmarks.length,
                                itemBuilder: (context, index) {
                                  final bookmark = _filteredBookmarks[index];
                                  final originalIndex = widget.bookmarks.indexOf(bookmark);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: ShadTheme.of(context).colorScheme.border,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: GestureDetector(
                                      onTap: () {
                                        widget.onBookmarkTap(bookmark);
                                        Navigator.pop(context);
                                      },
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              bookmark,
                                              style: ShadTheme.of(context).textTheme.p,
                                            ),
                                          ),
                                          ShadButton(
                                            onPressed: () async {
                                              await widget.onDeleteBookmark(originalIndex);
                                            },
                                            size: ShadButtonSize.sm,
                                            child: Icon(HeroiconsOutline.trash, size: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

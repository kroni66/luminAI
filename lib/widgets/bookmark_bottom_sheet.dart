import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';

class BookmarkBottomSheet extends StatelessWidget {
  final List<String> bookmarks;
  final ValueChanged<String> onBookmarkTap;
  final Future<void> Function(int) onDeleteBookmark;

  const BookmarkBottomSheet({
    Key? key,
    required this.bookmarks,
    required this.onBookmarkTap,
    required this.onDeleteBookmark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ShadSheet(
      child: Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bookmarks',
              style: ShadTheme.of(context).textTheme.h3,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: bookmarks.isEmpty
                  ?                   Center(
                      child: Text(
                        'No bookmarks yet',
                        style: ShadTheme.of(context).textTheme.muted,
                      ),
                    )
                  : ListView.builder(
                      itemCount: bookmarks.length,
                      itemBuilder: (context, index) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: ShadTheme.of(context).colorScheme.border,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            title: Text(
                              bookmarks[index],
                              style: ShadTheme.of(context).textTheme.p,
                            ),
                            trailing: ShadButton(
                              onPressed: () async {
                                await onDeleteBookmark(index);
                                Navigator.pop(context);
                              },
                              size: ShadButtonSize.sm,
                              child: Icon(HeroiconsOutline.trash, size: 14),
                            ),
                            onTap: () {
                              onBookmarkTap(bookmarks[index]);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

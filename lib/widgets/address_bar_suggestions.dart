import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import '../services/history_manager.dart';

class AddressBarSuggestions extends StatelessWidget {
  final List<HistoryEntry> suggestions;
  final ValueChanged<String> onSuggestionSelected;
  final VoidCallback onDismiss;
  final String query;

  const AddressBarSuggestions({
    Key? key,
    required this.suggestions,
    required this.onSuggestionSelected,
    required this.onDismiss,
    required this.query,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colors = ShadTheme.of(context).colorScheme;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300), // Limit height
        decoration: BoxDecoration(
          color: colors.background.withOpacity(0.95), // Semi-transparent background
          border: Border.all(
            color: colors.border.withOpacity(0.3),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: suggestions.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Text(
                  'No results found',
                  style: TextStyle(
                    color: colors.mutedForeground,
                    fontSize: 14,
                  ),
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return _SuggestionItem(
                    suggestion: suggestion,
                    query: query,
                    onTap: () => onSuggestionSelected(suggestion.url),
                    colors: colors,
                  );
                },
              ),
      ),
    );
  }
}

class _SuggestionItem extends StatelessWidget {
  final HistoryEntry suggestion;
  final String query;
  final VoidCallback onTap;
  final ShadColorScheme colors;

  const _SuggestionItem({
    required this.suggestion,
    required this.query,
    required this.onTap,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    // Highlight the matching parts of the text
    final urlSpans = _highlightMatches(suggestion.url, query);
    final titleSpans = _highlightMatches(suggestion.title, query);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            color: colors.mutedForeground,
                          );
                        },
                      ),
                    )
                  : Icon(
                      HeroiconsOutline.globeAlt,
                      size: 16,
                      color: colors.mutedForeground,
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
                      text: TextSpan(
                        children: titleSpans,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.foreground,
                          height: 1.2,
                        ),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // URL
                  RichText(
                    text: TextSpan(
                      children: urlSpans,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.mutedForeground,
                        height: 1.3,
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Visit time (relative)
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Text(
                _formatRelativeTime(suggestion.visitedAt),
                style: TextStyle(
                  fontSize: 11,
                  color: colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _highlightMatches(String text, String query) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final lowercaseText = text.toLowerCase();
    final lowercaseQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final index = lowercaseText.indexOf(lowercaseQuery, start);
      if (index == -1) break;

      // Add text before match
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      // Add highlighted match
      final end = index + query.length;
      spans.add(TextSpan(
        text: text.substring(index, end),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          backgroundColor: Color(0xFFFFEB3B), // Light yellow highlight
        ),
      ));

      start = end;
    }

    // Add remaining text
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return spans;
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      final years = (difference.inDays / 365).floor();
      return '${years}y';
    } else if (difference.inDays > 30) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}

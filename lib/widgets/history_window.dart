import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:heroicons_flutter/heroicons_flutter.dart';
import 'package:intl/intl.dart';
import '../services/history_manager.dart';

class HistoryWindow extends StatefulWidget {
  final List<HistoryEntry> history;
  final ValueChanged<String> onHistoryTap;
  final Future<void> Function(int) onDeleteHistoryEntry;
  final Future<void> Function() onClearHistory;

  const HistoryWindow({
    Key? key,
    required this.history,
    required this.onHistoryTap,
    required this.onDeleteHistoryEntry,
    required this.onClearHistory,
  }) : super(key: key);

  @override
  State<HistoryWindow> createState() => _HistoryWindowState();
}

class _HistoryWindowState extends State<HistoryWindow> {
  final TextEditingController _searchController = TextEditingController();
  List<HistoryEntry> _filteredHistory = [];

  @override
  void initState() {
    super.initState();
    _filteredHistory = widget.history;
    _searchController.addListener(_filterHistory);
  }

  @override
  void didUpdateWidget(HistoryWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.history != widget.history) {
      _filterHistory();
    }
  }

  void _filterHistory() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredHistory = widget.history
          .where((entry) =>
              entry.url.toLowerCase().contains(query) ||
              (entry.title.isNotEmpty && entry.title.toLowerCase().contains(query)))
          .toList();
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Map<String, List<HistoryEntry>> _groupHistoryByDate() {
    final grouped = <String, List<HistoryEntry>>{};

    for (final entry in _filteredHistory) {
      final dateKey = _formatDate(entry.visitedAt);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(entry);
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedHistory = _groupHistoryByDate();

    return ShadDialog(
      title: const Text('Browsing History'),
      actions: [
        ShadButton(
          onPressed: () async {
            await widget.onClearHistory();
          },
          child: const Text('Clear All'),
        ),
        ShadButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
      child: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            // Search bar
            ShadInput(
              controller: _searchController,
              placeholder: Text('Search history...'),
            ),
            const SizedBox(height: 16),

            // History list
            Expanded(
              child: _filteredHistory.isEmpty
                  ? Center(
                      child: Text(
                        widget.history.isEmpty
                            ? 'No browsing history yet'
                            : 'No history entries match your search',
                        style: ShadTheme.of(context).textTheme.muted,
                      ),
                    )
                  : ListView.builder(
                      itemCount: groupedHistory.length,
                      itemBuilder: (context, groupIndex) {
                        final dateKey = groupedHistory.keys.elementAt(groupIndex);
                        final entries = groupedHistory[dateKey]!;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date header
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                dateKey,
                                style: ShadTheme.of(context).textTheme.small.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: ShadTheme.of(context).colorScheme.mutedForeground,
                                ),
                              ),
                            ),
                            // History entries for this date
                            ...entries.map((entry) {
                              final originalIndex = widget.history.indexOf(entry);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: ShadTheme.of(context).colorScheme.border,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: GestureDetector(
                                  onTap: () {
                                    widget.onHistoryTap(entry.url);
                                    Navigator.pop(context);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Favicon
                                        if (entry.faviconUrl.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 12),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: Image.network(
                                                entry.faviconUrl,
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
                                        else
                                          Padding(
                                            padding: const EdgeInsets.only(right: 12),
                                            child: Icon(
                                              HeroiconsOutline.globeAlt,
                                              size: 16,
                                              color: ShadTheme.of(context).colorScheme.mutedForeground,
                                            ),
                                          ),

                                        // Title and URL
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (entry.title.isNotEmpty)
                                                Text(
                                                  entry.title,
                                                  style: ShadTheme.of(context).textTheme.p.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              Text(
                                                entry.url,
                                                style: ShadTheme.of(context).textTheme.small.copyWith(
                                                  color: ShadTheme.of(context).colorScheme.mutedForeground,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Time
                                        Padding(
                                          padding: const EdgeInsets.only(right: 12),
                                          child: Text(
                                            DateFormat('HH:mm').format(entry.visitedAt),
                                            style: ShadTheme.of(context).textTheme.small.copyWith(
                                              color: ShadTheme.of(context).colorScheme.mutedForeground,
                                            ),
                                          ),
                                        ),

                                        // Delete button
                                        ShadButton(
                                          onPressed: () async {
                                            await widget.onDeleteHistoryEntry(originalIndex);
                                          },
                                          size: ShadButtonSize.sm,
                                          child: Icon(HeroiconsOutline.trash, size: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
            ),
          ],
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

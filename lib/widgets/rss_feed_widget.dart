import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:xml/xml.dart';
import '../models/widget_data.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RssFeedItem {
  final String title;
  final String description;
  final String link;
  final DateTime? pubDate;
  final String? author;

  RssFeedItem({
    required this.title,
    required this.description,
    required this.link,
    this.pubDate,
    this.author,
  });
}

class RssFeedWidget extends BaseWidget {
  const RssFeedWidget({
    super.key,
    required super.data,
    super.onRemove,
    super.onUpdate,
  });

  @override
  State<RssFeedWidget> createState() => _RssFeedWidgetState();
}

class _RssFeedWidgetState extends BaseWidgetState<RssFeedWidget> {
  List<RssFeedItem> _feedItems = [];
  bool _isLoading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = widget.data.settings['feedUrl'] as String? ?? 'https://rss.cnn.com/rss/edition.rss';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final items = document.findAllElements('item');

        _feedItems = items.map((item) {
          final title = item.findElements('title').firstOrNull?.text ?? 'No title';
          final description = item.findElements('description').firstOrNull?.text ?? 'No description';
          final link = item.findElements('link').firstOrNull?.text ?? '';
          final pubDateStr = item.findElements('pubDate').firstOrNull?.text;
          final author = item.findElements('author').firstOrNull?.text ??
                        item.findElements('dc:creator').firstOrNull?.text;

          DateTime? pubDate;
          if (pubDateStr != null) {
            try {
              pubDate = HttpDate.parse(pubDateStr);
            } catch (_) {
              // Ignore parsing errors
            }
          }

          return RssFeedItem(
            title: title,
            description: _stripHtml(description),
            link: link,
            pubDate: pubDate,
            author: author,
          );
        }).toList();
      } else {
        throw Exception('Failed to load RSS feed');
      }
    } catch (e) {
      _error = 'Failed to load RSS feed: $e';
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _stripHtml(String html) {
    // Simple HTML tag removal - replace with html package parsing if needed
    final RegExp exp = RegExp(r'<[^>]*>', multiLine: true);
    return html.replaceAll(exp, '').trim();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget buildContent(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.rss_feed,
                size: 16,
                color: ShadTheme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.data.settings['title'] ?? 'RSS Feed',
                  style: ShadTheme.of(context).textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ShadTheme.of(context).colorScheme.foreground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.onRemove != null)
                IconButton(
                  onPressed: widget.onRemove,
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: ShadTheme.of(context).colorScheme.mutedForeground,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          style: ShadTheme.of(context).textTheme.small.copyWith(
                            color: Colors.red.withOpacity(0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : _feedItems.isEmpty
                      ? Center(
                          child: Text(
                            'No items found',
                            style: ShadTheme.of(context).textTheme.small.copyWith(
                              color: ShadTheme.of(context).colorScheme.mutedForeground,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount: _feedItems.length,
                          itemBuilder: (context, index) {
                            final item = _feedItems[index];
                            return InkWell(
                              onTap: item.link.isNotEmpty
                                  ? () {
                                      // This will be handled by the parent
                                    }
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.05),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: ShadTheme.of(context).textTheme.small.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: ShadTheme.of(context).colorScheme.foreground,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (item.description.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        item.description,
                                        style: ShadTheme.of(context).textTheme.small.copyWith(
                                          color: ShadTheme.of(context).colorScheme.mutedForeground,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        if (item.author != null && item.author!.isNotEmpty)
                                          Expanded(
                                            child: Text(
                                              item.author!,
                                              style: ShadTheme.of(context).textTheme.small.copyWith(
                                                color: ShadTheme.of(context).colorScheme.mutedForeground.withOpacity(0.7),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        if (item.pubDate != null)
                                          Text(
                                            _formatDate(item.pubDate),
                                            style: ShadTheme.of(context).textTheme.small.copyWith(
                                              color: ShadTheme.of(context).colorScheme.mutedForeground.withOpacity(0.7),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../models/widget_data.dart';
import 'rss_feed_widget.dart';

class WidgetFactory {
  static Widget createWidget(
    WidgetData data, {
    VoidCallback? onRemove,
    Function(WidgetData)? onUpdate,
  }) {
    switch (data.type) {
      case WidgetType.rssFeed:
        return RssFeedWidget(
          data: data,
          onRemove: onRemove,
          onUpdate: onUpdate,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  static String getWidgetDisplayName(WidgetType type) {
    switch (type) {
      case WidgetType.rssFeed:
        return 'RSS Feed';
      default:
        return 'Unknown Widget';
    }
  }

  static String getWidgetDescription(WidgetType type) {
    switch (type) {
      case WidgetType.rssFeed:
        return 'Display RSS feed content from any URL';
      default:
        return 'Unknown widget type';
    }
  }

  static IconData getWidgetIcon(WidgetType type) {
    switch (type) {
      case WidgetType.rssFeed:
        return Icons.rss_feed;
      default:
        return Icons.widgets;
    }
  }
}

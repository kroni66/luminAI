import 'dart:async';
import 'package:flutter/material.dart';
import '../database_helper.dart';

class HistoryEntry {
  final int id;
  final String url;
  final String title;
  final String faviconUrl;
  final DateTime visitedAt;

  HistoryEntry({
    required this.id,
    required this.url,
    required this.title,
    required this.faviconUrl,
    required this.visitedAt,
  });

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      id: map[DatabaseHelper.historyId],
      url: map[DatabaseHelper.historyUrl],
      title: map[DatabaseHelper.historyTitle] ?? '',
      faviconUrl: map[DatabaseHelper.historyFaviconUrl] ?? '',
      visitedAt: DateTime.parse(map[DatabaseHelper.historyVisitedAt]),
    );
  }
}

class HistoryManager {
  final DatabaseHelper _dbHelper;

  List<HistoryEntry> _history = [];

  // Callbacks
  VoidCallback? onHistoryChanged;

  HistoryManager(this._dbHelper);

  // Getters
  List<HistoryEntry> get history => _history;

  Future<void> initialize() async {
    await _loadHistory();
    // Add some test data if history is empty
    if (_history.isEmpty) {
      await _addTestData();
    }
  }

  Future<void> _addTestData() async {
    final testEntries = [
      HistoryEntry(id: 1, url: 'https://google.com', title: 'Google', faviconUrl: '', visitedAt: DateTime.now().subtract(const Duration(hours: 1))),
      HistoryEntry(id: 2, url: 'https://github.com', title: 'GitHub', faviconUrl: '', visitedAt: DateTime.now().subtract(const Duration(hours: 2))),
      HistoryEntry(id: 3, url: 'https://flutter.dev', title: 'Flutter', faviconUrl: '', visitedAt: DateTime.now().subtract(const Duration(hours: 3))),
      HistoryEntry(id: 4, url: 'https://dart.dev', title: 'Dart', faviconUrl: '', visitedAt: DateTime.now().subtract(const Duration(hours: 4))),
      HistoryEntry(id: 5, url: 'https://stackoverflow.com', title: 'Stack Overflow', faviconUrl: '', visitedAt: DateTime.now().subtract(const Duration(hours: 5))),
    ];

    for (final entry in testEntries) {
      await _dbHelper.insertHistoryEntry(
        url: entry.url,
        title: entry.title,
        faviconUrl: entry.faviconUrl,
      );
    }

    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final historyData = await _dbHelper.getHistory(limit: 1000); // Limit to last 1000 entries
      _history = historyData.map((entry) => HistoryEntry.fromMap(entry)).toList();
      onHistoryChanged?.call();
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  Future<void> addHistoryEntry({
    required String url,
    String? title,
    String? faviconUrl,
  }) async {
    if (url.isEmpty) return;

    try {
      await _dbHelper.insertHistoryEntry(
        url: url,
        title: title,
        faviconUrl: faviconUrl,
      );
      await _loadHistory(); // Reload history from database
    } catch (e) {
      debugPrint('Error adding history entry: $e');
    }
  }

  Future<void> removeHistoryEntry(int index) async {
    if (index >= 0 && index < _history.length) {
      try {
        final entry = _history[index];
        await _dbHelper.deleteHistoryEntry(entry.id);
        await _loadHistory(); // Reload history from database
      } catch (e) {
        debugPrint('Error deleting history entry: $e');
      }
    }
  }

  Future<void> clearHistory() async {
    try {
      await _dbHelper.clearHistory();
      await _loadHistory(); // Reload history from database
    } catch (e) {
      debugPrint('Error clearing history: $e');
    }
  }

  Future<void> clearOldHistory(int daysToKeep) async {
    try {
      await _dbHelper.deleteOldHistory(daysToKeep);
      await _loadHistory(); // Reload history from database
    } catch (e) {
      debugPrint('Error clearing old history: $e');
    }
  }

  /// Search history entries based on a query string
  /// Returns up to 8 most relevant suggestions
  List<HistoryEntry> searchHistory(String query, {int maxResults = 8}) {
    if (query.isEmpty) return [];

    final lowercaseQuery = query.toLowerCase();

    // Filter entries that contain the query in URL or title
    final matches = _history.where((entry) {
      final url = entry.url.toLowerCase();
      final title = entry.title.toLowerCase();
      return url.contains(lowercaseQuery) || title.contains(lowercaseQuery);
    }).toList();

    // Sort by relevance: exact URL matches first, then title matches, then recency
    matches.sort((a, b) {
      final aUrl = a.url.toLowerCase();
      final bUrl = b.url.toLowerCase();
      final aTitle = a.title.toLowerCase();
      final bTitle = b.title.toLowerCase();

      // Exact URL match gets highest priority
      if (aUrl == lowercaseQuery && bUrl != lowercaseQuery) return -1;
      if (bUrl == lowercaseQuery && aUrl != lowercaseQuery) return 1;

      // URL starts with query gets priority
      if (aUrl.startsWith(lowercaseQuery) && !bUrl.startsWith(lowercaseQuery)) return -1;
      if (bUrl.startsWith(lowercaseQuery) && !aUrl.startsWith(lowercaseQuery)) return 1;

      // Title starts with query gets priority
      if (aTitle.startsWith(lowercaseQuery) && !bTitle.startsWith(lowercaseQuery)) return -1;
      if (bTitle.startsWith(lowercaseQuery) && !aTitle.startsWith(lowercaseQuery)) return 1;

      // Then sort by recency (most recent first)
      return b.visitedAt.compareTo(a.visitedAt);
    });

    return matches.take(maxResults).toList();
  }
}

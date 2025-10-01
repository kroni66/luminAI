import 'dart:async';
import 'package:flutter/material.dart';
import '../database_helper.dart';

class BookmarkManager {
  final DatabaseHelper _dbHelper;

  List<String> _bookmarks = [];

  // Callbacks
  VoidCallback? onBookmarksChanged;

  BookmarkManager(this._dbHelper);

  // Getters
  List<String> get bookmarks => _bookmarks;

  Future<void> initialize() async {
    await _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    try {
      final bookmarks = await _dbHelper.getBookmarkUrls();
      _bookmarks = bookmarks;
      onBookmarksChanged?.call();
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
    }
  }

  Future<void> addBookmark(String url) async {
    if (url.isNotEmpty && !_bookmarks.contains(url)) {
      try {
        await _dbHelper.insertBookmark(url);
        await _loadBookmarks(); // Reload bookmarks from database
      } catch (e) {
        debugPrint('Error adding bookmark: $e');
      }
    }
  }

  Future<void> removeBookmark(int index) async {
    if (index >= 0 && index < _bookmarks.length) {
      try {
        final url = _bookmarks[index];
        await _dbHelper.deleteBookmark(url);
        await _loadBookmarks(); // Reload bookmarks from database
      } catch (e) {
        debugPrint('Error deleting bookmark: $e');
      }
    }
  }

  Future<void> removeBookmarkByUrl(String url) async {
    try {
      await _dbHelper.deleteBookmark(url);
      await _loadBookmarks();
    } catch (e) {
      debugPrint('Error deleting bookmark: $e');
    }
  }
}

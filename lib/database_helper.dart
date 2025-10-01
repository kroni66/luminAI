import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'models/download_info.dart';
import 'models/smart_note.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal() {
    _initializeDatabaseFactory();
  }

  void _initializeDatabaseFactory() {
    // Initialize sqflite for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  static const String _databaseName = 'browser2.db';
  static const int _databaseVersion = 10;

  static const String tableBookmarks = 'bookmarks';
  static const String columnId = 'id';
  static const String columnUrl = 'url';
  static const String columnTitle = 'title';
  static const String columnCreatedAt = 'created_at';

  // Favorites table
  static const String tableFavorites = 'favorites';
  static const String favId = 'id';
  static const String favTitle = 'title';
  static const String favUrl = 'url';
  static const String favBg = 'bg';
  static const String favFg = 'fg';
  static const String favCreatedAt = 'created_at';

  // Folders table
  static const String tableFolders = 'folders';
  static const String folderId = 'id';
  static const String folderName = 'name';
  static const String folderColor = 'color';
  static const String folderOrder = 'folder_order';
  static const String folderCreatedAt = 'created_at';

  // Tabs table
  static const String tableTabs = 'tabs';
  static const String tabId = 'id';
  static const String tabUrl = 'url';
  static const String tabTitle = 'title';
  static const String tabFaviconUrl = 'favicon_url';
  static const String tabFolderId = 'folder_id';
  static const String tabIsActive = 'is_active';
  static const String tabOrder = 'tab_order';
  static const String tabCreatedAt = 'created_at';

  // History table
  static const String tableHistory = 'history';
  static const String historyId = 'id';
  static const String historyUrl = 'url';
  static const String historyTitle = 'title';
  static const String historyFaviconUrl = 'favicon_url';
  static const String historyVisitedAt = 'visited_at';

  // Downloads table
  static const String tableDownloads = 'downloads';
  static const String downloadId = 'id';
  static const String downloadUrl = 'url';
  static const String downloadFilename = 'filename';
  static const String downloadSavePath = 'save_path';
  static const String downloadTotalBytes = 'total_bytes';
  static const String downloadDownloadedBytes = 'downloaded_bytes';
  static const String downloadStartTime = 'start_time';
  static const String downloadEndTime = 'end_time';
  static const String downloadStatus = 'status';
  static const String downloadErrorMessage = 'error_message';
  static const String downloadMimeType = 'mime_type';
  static const String downloadReferrer = 'referrer';

  // Settings table
  static const String tableSettings = 'settings';
  static const String settingKey = 'key';
  static const String settingValue = 'value';

  // Widgets table
  static const String tableWidgets = 'widgets';
  static const String widgetId = 'id';
  static const String widgetType = 'type';
  static const String widgetPositionX = 'position_x';
  static const String widgetPositionY = 'position_y';
  static const String widgetWidth = 'width';
  static const String widgetHeight = 'height';
  static const String widgetSettings = 'settings';
  static const String widgetIsVisible = 'is_visible';
  static const String widgetCreatedAt = 'created_at';

  // Smart Notes table
  static const String tableSmartNotes = 'smart_notes';
  static const String smartNoteId = 'id';
  static const String smartNoteContent = 'content';
  static const String smartNoteSourceUrl = 'source_url';
  static const String smartNoteSourceTitle = 'source_title';
  static const String smartNoteCreatedAt = 'created_at';
  static const String smartNoteUpdatedAt = 'updated_at';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableBookmarks (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnUrl TEXT NOT NULL UNIQUE,
        $columnTitle TEXT,
        $columnCreatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFavorites (
        $favId INTEGER PRIMARY KEY AUTOINCREMENT,
        $favTitle TEXT NOT NULL,
        $favUrl TEXT NOT NULL UNIQUE,
        $favBg TEXT,
        $favFg TEXT,
        $favCreatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableFolders (
        $folderId TEXT PRIMARY KEY,
        $folderName TEXT NOT NULL,
        $folderColor TEXT,
        $folderOrder INTEGER NOT NULL,
        $folderCreatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableTabs (
        $tabId TEXT PRIMARY KEY,
        $tabUrl TEXT NOT NULL,
        $tabTitle TEXT,
        $tabFaviconUrl TEXT,
        $tabFolderId TEXT,
        $tabIsActive INTEGER DEFAULT 0,
        $tabOrder INTEGER NOT NULL,
        $tabCreatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableHistory (
        $historyId INTEGER PRIMARY KEY AUTOINCREMENT,
        $historyUrl TEXT NOT NULL,
        $historyTitle TEXT,
        $historyFaviconUrl TEXT,
        $historyVisitedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableDownloads (
        $downloadId TEXT PRIMARY KEY,
        $downloadUrl TEXT NOT NULL,
        $downloadFilename TEXT NOT NULL,
        $downloadSavePath TEXT NOT NULL,
        $downloadTotalBytes INTEGER NOT NULL,
        $downloadDownloadedBytes INTEGER DEFAULT 0,
        $downloadStartTime TEXT NOT NULL,
        $downloadEndTime TEXT,
        $downloadStatus INTEGER NOT NULL,
        $downloadErrorMessage TEXT,
        $downloadMimeType TEXT,
        $downloadReferrer TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSettings (
        $settingKey TEXT PRIMARY KEY,
        $settingValue TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableSmartNotes (
        $smartNoteId TEXT PRIMARY KEY,
        $smartNoteContent TEXT NOT NULL,
        $smartNoteSourceUrl TEXT,
        $smartNoteSourceTitle TEXT,
        $smartNoteCreatedAt TEXT NOT NULL,
        $smartNoteUpdatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Incremental migrations without dropping existing data
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableFavorites (
          $favId INTEGER PRIMARY KEY AUTOINCREMENT,
          $favTitle TEXT NOT NULL,
          $favUrl TEXT NOT NULL UNIQUE,
          $favBg TEXT,
          $favFg TEXT,
          $favCreatedAt TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableTabs (
          $tabId TEXT PRIMARY KEY,
          $tabUrl TEXT NOT NULL,
          $tabTitle TEXT,
          $tabFaviconUrl TEXT,
          $tabIsActive INTEGER DEFAULT 0,
          $tabOrder INTEGER NOT NULL,
          $tabCreatedAt TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 4) {
      // Add folders table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableFolders (
          $folderId TEXT PRIMARY KEY,
          $folderName TEXT NOT NULL,
          $folderColor TEXT,
          $folderOrder INTEGER NOT NULL,
          $folderCreatedAt TEXT NOT NULL
        )
      ''');

      // Add folder_id column to tabs table
      try {
        await db.execute('ALTER TABLE $tableTabs ADD COLUMN $tabFolderId TEXT');
      } catch (e) {
        // Column might already exist, ignore error
        debugPrint('Error adding folder_id column: $e');
      }
    }

    if (oldVersion < 5) {
      // Add history table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableHistory (
          $historyId INTEGER PRIMARY KEY AUTOINCREMENT,
          $historyUrl TEXT NOT NULL,
          $historyTitle TEXT,
          $historyFaviconUrl TEXT,
          $historyVisitedAt TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 6) {
      // Add downloads table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableDownloads (
          $downloadId TEXT PRIMARY KEY,
          $downloadUrl TEXT NOT NULL,
          $downloadFilename TEXT NOT NULL,
          $downloadSavePath TEXT NOT NULL,
          $downloadTotalBytes INTEGER NOT NULL,
          $downloadDownloadedBytes INTEGER DEFAULT 0,
          $downloadStartTime TEXT NOT NULL,
          $downloadEndTime TEXT,
          $downloadStatus INTEGER NOT NULL,
          $downloadErrorMessage TEXT,
          $downloadMimeType TEXT,
          $downloadReferrer TEXT
        )
      ''');
    }

    if (oldVersion < 7) {
      // Add settings table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableSettings (
          $settingKey TEXT PRIMARY KEY,
          $settingValue TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 8) {
      // Add widgets table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableWidgets (
          $widgetId TEXT PRIMARY KEY,
          $widgetType TEXT NOT NULL,
          $widgetPositionX REAL NOT NULL,
          $widgetPositionY REAL NOT NULL,
          $widgetWidth REAL NOT NULL,
          $widgetHeight REAL NOT NULL,
          $widgetSettings TEXT NOT NULL,
          $widgetIsVisible INTEGER DEFAULT 1,
          $widgetCreatedAt TEXT NOT NULL
        )
      ''');
  }

    if (oldVersion < 10) {
      // Add smart notes table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableSmartNotes (
          $smartNoteId TEXT PRIMARY KEY,
          $smartNoteContent TEXT NOT NULL,
          $smartNoteSourceUrl TEXT,
          $smartNoteSourceTitle TEXT,
          $smartNoteCreatedAt TEXT NOT NULL,
          $smartNoteUpdatedAt TEXT NOT NULL
        )
      ''');
  }
  }

  // Insert a bookmark
  Future<int> insertBookmark(String url, {String? title}) async {
    Database db = await database;
    return await db.insert(
      tableBookmarks,
      {
        columnUrl: url,
        columnTitle: title ?? '',
        columnCreatedAt: DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore if URL already exists
    );
  }

  // Get all bookmarks
  Future<List<Map<String, dynamic>>> getBookmarks() async {
    Database db = await database;
    return await db.query(tableBookmarks, orderBy: '$columnCreatedAt DESC');
  }

  // Get all bookmark URLs as a list
  Future<List<String>> getBookmarkUrls() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableBookmarks,
      columns: [columnUrl],
      orderBy: '$columnCreatedAt DESC',
    );
    return maps.map((map) => map[columnUrl] as String).toList();
  }

  // Delete a bookmark by URL
  Future<int> deleteBookmark(String url) async {
    Database db = await database;
    return await db.delete(
      tableBookmarks,
      where: '$columnUrl = ?',
      whereArgs: [url],
    );
  }

  // Delete a bookmark by ID
  Future<int> deleteBookmarkById(int id) async {
    Database db = await database;
    return await db.delete(
      tableBookmarks,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Check if a URL is bookmarked
  Future<bool> isBookmarked(String url) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableBookmarks,
      columns: [columnId],
      where: '$columnUrl = ?',
      whereArgs: [url],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // Update bookmark title
  Future<int> updateBookmarkTitle(String url, String title) async {
    Database db = await database;
    return await db.update(
      tableBookmarks,
      {columnTitle: title},
      where: '$columnUrl = ?',
      whereArgs: [url],
    );
  }

  // Favorites CRUD
  Future<int> insertFavorite({
    required String title,
    required String url,
    String? bg,
    String? fg,
  }) async {
    Database db = await database;
    return await db.insert(
      tableFavorites,
      {
        favTitle: title,
        favUrl: url,
        favBg: bg ?? '',
        favFg: fg ?? '',
        favCreatedAt: DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getFavoritesRaw() async {
    Database db = await database;
    return await db.query(tableFavorites, orderBy: '$favCreatedAt DESC');
  }

  Future<List<Map<String, String>>> getFavoriteApps() async {
    final rows = await getFavoritesRaw();
    return rows.map((r) => {
      'title': (r[favTitle] ?? '').toString(),
      'url': (r[favUrl] ?? '').toString(),
      'bg': (r[favBg] ?? '').toString(),
      'fg': (r[favFg] ?? '').toString(),
    }).toList();
  }

  Future<int> deleteFavoriteByUrl(String url) async {
    Database db = await database;
    return await db.delete(
      tableFavorites,
      where: '$favUrl = ?',
      whereArgs: [url],
    );
  }


  Future<List<Map<String, dynamic>>> getTabs() async {
    Database db = await database;
    return await db.query(tableTabs, orderBy: '$tabOrder ASC');
  }

  Future<int> deleteTab(String id) async {
    Database db = await database;
    return await db.delete(
      tableTabs,
      where: '$tabId = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearAllTabs() async {
    Database db = await database;
    return await db.delete(tableTabs);
  }

  Future<int> setActiveTab(String id) async {
    Database db = await database;
    // First, set all tabs to inactive
    await db.update(
      tableTabs,
      {tabIsActive: 0},
    );
    
    // Then set the specified tab as active
    return await db.update(
      tableTabs,
      {tabIsActive: 1},
      where: '$tabId = ?',
      whereArgs: [id],
    );
  }

  // Folder CRUD operations
  Future<int> insertFolder({
    required String id,
    required String name,
    String? color,
    required int order,
  }) async {
    Database db = await database;
    return await db.insert(
      tableFolders,
      {
        folderId: id,
        folderName: name,
        folderColor: color,
        folderOrder: order,
        folderCreatedAt: DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getFolders() async {
    Database db = await database;
    return await db.query(tableFolders, orderBy: '$folderOrder ASC');
  }

  Future<int> updateFolder({
    required String id,
    String? name,
    String? color,
    int? order,
  }) async {
    Database db = await database;
    Map<String, dynamic> values = {};

    if (name != null) values[folderName] = name;
    if (color != null) values[folderColor] = color;
    if (order != null) values[folderOrder] = order;

    if (values.isEmpty) return 0;

    return await db.update(
      tableFolders,
      values,
      where: '$folderId = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteFolder(String id) async {
    Database db = await database;

    // First, update all tabs in this folder to have no folder
    await db.update(
      tableTabs,
      {tabFolderId: null},
      where: '$tabFolderId = ?',
      whereArgs: [id],
    );

    // Then delete the folder
    return await db.delete(
      tableFolders,
      where: '$folderId = ?',
      whereArgs: [id],
    );
  }

  // Update the insertTab method to include folderId
  Future<int> insertTab({
    required String id,
    required String url,
    String? title,
    String? faviconUrl,
    String? folderId,
    bool isActive = false,
    required int order,
  }) async {
    Database db = await database;
    return await db.insert(
      tableTabs,
      {
        tabId: id,
        tabUrl: url,
        tabTitle: title ?? 'New Tab',
        tabFaviconUrl: faviconUrl,
        tabFolderId: folderId,
        tabIsActive: isActive ? 1 : 0,
        tabOrder: order,
        tabCreatedAt: DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Update the updateTab method to include folderId
  Future<int> updateTab({
    required String id,
    String? url,
    String? title,
    String? faviconUrl,
    String? folderId,
    bool? isActive,
    int? order,
  }) async {
    Database db = await database;
    Map<String, dynamic> values = {};

    if (url != null) values[tabUrl] = url;
    if (title != null) values[tabTitle] = title;
    if (faviconUrl != null) values[tabFaviconUrl] = faviconUrl;
    // Always include folderId in updates (including null to move to root)
    values[tabFolderId] = folderId;
    if (isActive != null) values[tabIsActive] = isActive ? 1 : 0;
    if (order != null) values[tabOrder] = order;

    if (values.isEmpty) return 0;

    return await db.update(
      tableTabs,
      values,
      where: '$tabId = ?',
      whereArgs: [id],
    );
  }

  // History CRUD operations
  Future<int> insertHistoryEntry({
    required String url,
    String? title,
    String? faviconUrl,
  }) async {
    Database db = await database;
    return await db.insert(
      tableHistory,
      {
        historyUrl: url,
        historyTitle: title ?? '',
        historyFaviconUrl: faviconUrl ?? '',
        historyVisitedAt: DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Map<String, dynamic>>> getHistory({int? limit}) async {
    Database db = await database;
    return await db.query(
      tableHistory,
      orderBy: '$historyVisitedAt DESC',
      limit: limit,
    );
  }

  Future<int> deleteHistoryEntry(int id) async {
    Database db = await database;
    return await db.delete(
      tableHistory,
      where: '$historyId = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearHistory() async {
    Database db = await database;
    return await db.delete(tableHistory);
  }

  Future<int> deleteOldHistory(int daysToKeep) async {
    Database db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    return await db.delete(
      tableHistory,
      where: '$historyVisitedAt < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  // Downloads CRUD operations
  Future<int> insertDownload(DownloadInfo download) async {
    Database db = await database;
    return await db.insert(
      tableDownloads,
      download.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateDownload(DownloadInfo download) async {
    Database db = await database;
    return await db.update(
      tableDownloads,
      download.toMap(),
      where: '$downloadId = ?',
      whereArgs: [download.id],
    );
  }

  Future<DownloadInfo?> getDownload(String id) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableDownloads,
      where: '$downloadId = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return DownloadInfo.fromMap(maps.first);
    }
    return null;
  }

  Future<List<DownloadInfo>> getAllDownloads() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableDownloads,
      orderBy: '$downloadStartTime DESC',
    );

    return List.generate(maps.length, (i) {
      return DownloadInfo.fromMap(maps[i]);
    });
  }

  Future<List<DownloadInfo>> getActiveDownloads() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableDownloads,
      where: '$downloadStatus IN (?, ?, ?)',
      whereArgs: [
        DownloadStatus.queued.index,
        DownloadStatus.downloading.index,
        DownloadStatus.paused.index,
      ],
      orderBy: '$downloadStartTime ASC',
    );

    return List.generate(maps.length, (i) {
      return DownloadInfo.fromMap(maps[i]);
    });
  }

  Future<int> deleteDownload(String id) async {
    Database db = await database;
    return await db.delete(
      tableDownloads,
      where: '$downloadId = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearCompletedDownloads() async {
    Database db = await database;
    return await db.delete(
      tableDownloads,
      where: '$downloadStatus = ?',
      whereArgs: [DownloadStatus.completed.index],
    );
  }

  Future<int> clearFailedDownloads() async {
    Database db = await database;
    return await db.delete(
      tableDownloads,
      where: '$downloadStatus = ?',
      whereArgs: [DownloadStatus.failed.index],
    );
  }

  // Settings CRUD operations
  Future<int> setSetting(String key, String value) async {
    Database db = await database;
    return await db.insert(
      tableSettings,
      {
        settingKey: key,
        settingValue: value,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableSettings,
      where: '$settingKey = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first[settingValue] as String?;
    }
    return null;
  }

  Future<Map<String, String>> getAllSettings() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableSettings);

    final settings = <String, String>{};
    for (final map in maps) {
      settings[map[settingKey] as String] = map[settingValue] as String;
    }
    return settings;
  }

  Future<int> deleteSetting(String key) async {
    Database db = await database;
    return await db.delete(
      tableSettings,
      where: '$settingKey = ?',
      whereArgs: [key],
    );
  }

  // Widgets CRUD operations
  Future<int> saveWidgets(List<Map<String, dynamic>> widgets) async {
    Database db = await database;

    // Clear existing widgets and insert new ones (simple approach for now)
    await db.delete(tableWidgets);

    int inserted = 0;
    for (final widget in widgets) {
      await db.insert(
        tableWidgets,
        {
          widgetId: widget['id'],
          widgetType: widget['type'],
          widgetPositionX: widget['positionX'],
          widgetPositionY: widget['positionY'],
          widgetWidth: widget['width'],
          widgetHeight: widget['height'],
          widgetSettings: widget['settings'] != null ? widget['settings'].toString() : '{}',
          widgetIsVisible: widget['isVisible'] ? 1 : 0,
          widgetCreatedAt: DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      inserted++;
    }

    return inserted;
  }

  Future<List<Map<String, dynamic>>> getWidgets() async {
    Database db = await database;
    return await db.query(tableWidgets, orderBy: '$widgetCreatedAt ASC');
  }

  Future<int> deleteWidget(String id) async {
    Database db = await database;
    return await db.delete(
      tableWidgets,
      where: '$widgetId = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearWidgets() async {
    Database db = await database;
    return await db.delete(tableWidgets);
  }

  // Smart Notes CRUD operations
  Future<int> insertSmartNote(SmartNote note) async {
    Database db = await database;
    return await db.insert(
      tableSmartNotes,
      note.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> updateSmartNote(SmartNote note) async {
    Database db = await database;
    final updatedNote = note.copyWith(updatedAt: DateTime.now());
    return await db.update(
      tableSmartNotes,
      updatedNote.toJson(),
      where: '$smartNoteId = ?',
      whereArgs: [note.id],
    );
  }

  Future<SmartNote?> getSmartNote(String id) async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableSmartNotes,
      where: '$smartNoteId = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return SmartNote.fromJson(maps.first);
    }
    return null;
  }

  Future<List<SmartNote>> getAllSmartNotes() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableSmartNotes,
      orderBy: '$smartNoteCreatedAt DESC',
    );

    return List.generate(maps.length, (i) {
      return SmartNote.fromJson(maps[i]);
    });
  }

  Future<int> deleteSmartNote(String id) async {
    Database db = await database;
    return await db.delete(
      tableSmartNotes,
      where: '$smartNoteId = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearAllSmartNotes() async {
    Database db = await database;
    return await db.delete(tableSmartNotes);
  }

  /// Ensures the smart notes table exists (for migration compatibility)
  Future<void> ensureSmartNotesTableExists() async {
    Database db = await database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableSmartNotes (
        $smartNoteId TEXT PRIMARY KEY,
        $smartNoteContent TEXT NOT NULL,
        $smartNoteSourceUrl TEXT,
        $smartNoteSourceTitle TEXT,
        $smartNoteCreatedAt TEXT NOT NULL,
        $smartNoteUpdatedAt TEXT NOT NULL
      )
    ''');
  }

  // Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

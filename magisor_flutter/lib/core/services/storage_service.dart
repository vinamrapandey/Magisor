import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/saved_item.dart';

/// Local persistence for AI history and saved items, backed by SQLite.
///
/// Uses the FFI factory so it works on Windows desktop (plain `sqflite` is
/// mobile-only), and stores the database in the app-support directory so an
/// installed app can write it. Exposes the data as a [ChangeNotifier] so the
/// History/Saved screens rebuild automatically on change.
class StorageService extends ChangeNotifier {
  Database? _db;
  List<SavedItem> _items = [];

  List<SavedItem> get history => _items;
  List<SavedItem> get saved => _items.where((e) => e.saved).toList();

  Future<void> init() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dir = await getApplicationSupportDirectory();
    final path = p.join(dir.path, 'magisor.db');

    _db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE entries(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              query TEXT,
              summary TEXT,
              extracted_text TEXT,
              provider_used TEXT,
              created_at INTEGER,
              saved INTEGER DEFAULT 0
            )
          ''');
        },
      ),
    );
    await _reload();
  }

  Future<void> _reload() async {
    final db = _db;
    if (db == null) return;
    final rows = await db.query('entries', orderBy: 'created_at DESC');
    _items = rows.map(SavedItem.fromMap).toList();
    notifyListeners();
  }

  /// Inserts an entry and returns the stored [SavedItem] (with its id), or null
  /// if the database is unavailable.
  Future<SavedItem?> addEntry({
    required String query,
    required String summary,
    required String extractedText,
    required String providerUsed,
  }) async {
    final db = _db;
    if (db == null) return null;
    final id = await db.insert('entries', {
      'query': query,
      'summary': summary,
      'extracted_text': extractedText,
      'provider_used': providerUsed,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'saved': 0,
    });
    await _reload();
    final match = _items.where((e) => e.id == id);
    return match.isNotEmpty ? match.first : null;
  }

  Future<void> toggleSaved(SavedItem item) async {
    final db = _db;
    if (db == null || item.id == null) return;
    await db.update(
      'entries',
      {'saved': item.saved ? 0 : 1},
      where: 'id = ?',
      whereArgs: [item.id],
    );
    await _reload();
  }

  Future<void> deleteEntry(SavedItem item) async {
    final db = _db;
    if (db == null || item.id == null) return;
    await db.delete('entries', where: 'id = ?', whereArgs: [item.id]);
    await _reload();
  }

  /// Clears history but keeps starred (saved) items.
  Future<void> clearHistory() async {
    final db = _db;
    if (db == null) return;
    await db.delete('entries', where: 'saved = 0');
    await _reload();
  }
}

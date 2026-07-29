import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/saved_item.dart';

/// Local persistence for AI history and saved items, backed by SQLite.
///
/// Uses FTS5 (Full-Text Search) and BM25 ranking for low-power, zero-cost
/// local RAG and instant offline search over all past screen captures, OCR,
/// translations, and user prompts.
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
        version: 2,
        onCreate: (db, version) async {
          await _createTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await _createFTSTable(db);
          }
        },
        onOpen: (db) async {
          await _createFTSTable(db);
        },
      ),
    );
    await _reload();
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        query TEXT,
        summary TEXT,
        extracted_text TEXT,
        provider_used TEXT,
        created_at INTEGER,
        saved INTEGER DEFAULT 0
      )
    ''');
    await _createFTSTable(db);
  }

  static Future<void> _createFTSTable(Database db) async {
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS fts_entries USING fts5(
          query,
          summary,
          extracted_text,
          content='entries',
          content_rowid='id'
        );
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS entries_ai AFTER INSERT ON entries BEGIN
          INSERT INTO fts_entries(rowid, query, summary, extracted_text)
          VALUES (new.id, new.query, new.summary, new.extracted_text);
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS entries_ad AFTER DELETE ON entries BEGIN
          INSERT INTO fts_entries(fts_entries, rowid, query, summary, extracted_text)
          VALUES ('delete', old.id, old.query, old.summary, old.extracted_text);
        END;
      ''');

      await db.execute('''
        CREATE TRIGGER IF NOT EXISTS entries_au AFTER UPDATE ON entries BEGIN
          INSERT INTO fts_entries(fts_entries, rowid, query, summary, extracted_text)
          VALUES ('delete', old.id, old.query, old.summary, old.extracted_text);
          INSERT INTO fts_entries(rowid, query, summary, extracted_text)
          VALUES (new.id, new.query, new.summary, new.extracted_text);
        END;
      ''');
    } catch (e) {
      debugPrint('FTS5 init warning: $e');
    }
  }

  Future<void> _reload() async {
    final db = _db;
    if (db == null) return;
    final rows = await db.query('entries', orderBy: 'created_at DESC');
    _items = rows.map(SavedItem.fromMap).toList();
    notifyListeners();
  }

  /// Instant, zero-cost offline search over all past OCR text & history (BM25 ranked).
  Future<List<SavedItem>> searchLocal(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return _items;
    final db = _db;
    if (db == null) return [];

    try {
      final sanitized = trimmed.replaceAll(RegExp(r'[^\w\s]'), '');
      final terms = sanitized.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) => '$w*').join(' ');
      if (terms.isEmpty) return _items;

      final rows = await db.rawQuery('''
        SELECT entries.* FROM entries
        JOIN fts_entries ON entries.id = fts_entries.rowid
        WHERE fts_entries MATCH ?
        ORDER BY bm25(fts_entries) ASC
      ''', [terms]);

      return rows.map(SavedItem.fromMap).toList();
    } catch (_) {
      final queryLower = '%$trimmed%';
      final rows = await db.query(
        'entries',
        where: 'query LIKE ? OR summary LIKE ? OR extracted_text LIKE ?',
        whereArgs: [queryLower, queryLower, queryLower],
        orderBy: 'created_at DESC',
      );
      return rows.map(SavedItem.fromMap).toList();
    }
  }

  /// Local RAG Context Retrieval: Fetches top relevant screen/chat snippets
  /// matching the user prompt to augment LLM queries with 0 extra token bloat.
  Future<String?> retrieveRAGContext(String userPrompt) async {
    final db = _db;
    if (db == null) return null;

    final words = userPrompt
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3)
        .take(4)
        .map((w) => '$w*')
        .join(' OR ');

    if (words.isEmpty) return null;

    try {
      final rows = await db.rawQuery('''
        SELECT query, summary, extracted_text FROM entries
        JOIN fts_entries ON entries.id = fts_entries.rowid
        WHERE fts_entries MATCH ?
        ORDER BY bm25(fts_entries) ASC
        LIMIT 2
      ''', [words]);

      if (rows.isEmpty) return null;

      final snippets = rows.map((r) {
        final q = r['query'] ?? '';
        final s = r['summary'] ?? '';
        final t = r['extracted_text'] ?? '';
        return "Action: $q\nSummary: $s${t.toString().isNotEmpty ? '\nText: $t' : ''}";
      }).join('\n---\n');

      return snippets.isNotEmpty ? snippets : null;
    } catch (_) {
      return null;
    }
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

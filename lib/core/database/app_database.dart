import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'database_paths.dart';

class AppDatabase {
  AppDatabase(this.db);

  static const schemaVersion = 2;

  final Database db;

  static Future<AppDatabase> openInMemory() async {
    ffi.sqfliteFfiInit();
    final database = await ffi.databaseFactoryFfi.openDatabase(
      ffi.inMemoryDatabasePath,
    );
    final appDb = AppDatabase(database);
    await appDb.migrate();
    return appDb;
  }

  static Future<AppDatabase> open() async {
    final databasePath = await oceanBabyDatabasePath();
    final database = await _databaseFactory().openDatabase(databasePath);
    final appDb = AppDatabase(database);
    await appDb.migrate();
    return appDb;
  }

  static DatabaseFactory _databaseFactory() {
    ffi.sqfliteFfiInit();
    return ffi.databaseFactoryFfi;
  }

  Future<void> close() => db.close();

  Future<void> migrate() async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS ledger_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          source TEXT NOT NULL,
          origin TEXT NOT NULL,
          occurred_at TEXT NOT NULL,
          amount_cents INTEGER NOT NULL,
          amount REAL NOT NULL,
          direction TEXT NOT NULL,
          counterparty TEXT NOT NULL,
          description TEXT NOT NULL,
          payment_method TEXT NOT NULL,
          original_category TEXT NOT NULL,
          user_category TEXT NOT NULL,
          note TEXT NOT NULL,
          import_batch_id TEXT NOT NULL,
          confirmation_status TEXT NOT NULL,
          fingerprint TEXT NOT NULL UNIQUE,
          updated_at TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_ledger_records_occurred_at
        ON ledger_records (occurred_at DESC)
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          folder TEXT NOT NULL,
          pinned INTEGER NOT NULL,
          image_path TEXT NOT NULL DEFAULT '',
          updated_at TEXT NOT NULL
        )
      ''');
      final noteColumns = await txn.rawQuery("PRAGMA table_info('notes')");
      final noteColumnNames = noteColumns.map((row) => row['name'] as String);
      if (!noteColumnNames.contains('image_path')) {
        await txn.execute(
          "ALTER TABLE notes ADD COLUMN image_path TEXT NOT NULL DEFAULT ''",
        );
      }
      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_notes_updated_at
        ON notes (updated_at DESC)
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS todos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          due_date TEXT NOT NULL,
          priority INTEGER NOT NULL,
          completed INTEGER NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_todos_due_completed_priority
        ON todos (due_date, completed, priority DESC, updated_at DESC)
      ''');
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS moods (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          day TEXT NOT NULL UNIQUE,
          mood TEXT NOT NULL,
          prompt_shown INTEGER NOT NULL,
          note TEXT NOT NULL DEFAULT '',
          updated_at TEXT NOT NULL
        )
      ''');
      final moodColumns = await txn.rawQuery("PRAGMA table_info('moods')");
      final moodColumnNames = moodColumns.map((row) => row['name'] as String);
      if (!moodColumnNames.contains('note')) {
        await txn.execute(
          "ALTER TABLE moods ADD COLUMN note TEXT NOT NULL DEFAULT ''",
        );
      }
      await txn.execute('''
        CREATE TABLE IF NOT EXISTS settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      await txn.execute('PRAGMA user_version = $schemaVersion');
    });
  }
}

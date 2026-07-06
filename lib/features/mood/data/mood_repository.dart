import 'package:sqflite_common/sqlite_api.dart';

import '../../../core/database/app_database.dart';
import '../domain/mood_entry.dart';

class MoodRepository {
  const MoodRepository(this._database);

  static const _promptEnabledKey = 'mood_prompt_enabled';
  static const _showMoodDotKey = 'mood_title_show_dot';
  static const _showMoodTextKey = 'mood_title_show_text';
  static const _showMoodNoteKey = 'mood_title_show_note';

  final AppDatabase _database;

  Future<MoodEntry?> getByDay(DateTime day) async {
    final rows = await _database.db.query(
      'moods',
      where: 'day = ?',
      whereArgs: [_dateOnly(day).toIso8601String()],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _fromRow(rows.single);
  }

  Future<void> save(MoodEntry entry) async {
    final normalizedDay = _dateOnly(entry.day);
    await _database.db.insert('moods', {
      'day': normalizedDay.toIso8601String(),
      'mood': entry.mood.name,
      'prompt_shown': entry.promptShown ? 1 : 0,
      'note': entry.note,
      'updated_at': entry.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MoodEntry>> listHistory({int limit = 60}) async {
    final rows = await _database.db.query(
      'moods',
      orderBy: 'day DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  Future<bool> getPromptEnabled() async {
    final rows = await _database.db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [_promptEnabledKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return true;
    }
    return rows.single['value'] == 'true';
  }

  Future<void> setPromptEnabled(bool enabled) async {
    await _setBoolSetting(_promptEnabledKey, enabled);
  }

  Future<MoodTitleDisplayOptions> getTitleDisplayOptions() async {
    return MoodTitleDisplayOptions(
      showDot: await _getBoolSetting(_showMoodDotKey, defaultValue: true),
      showText: await _getBoolSetting(_showMoodTextKey, defaultValue: true),
      showNote: await _getBoolSetting(_showMoodNoteKey, defaultValue: true),
    );
  }

  Future<bool> getShowMoodDot() {
    return _getBoolSetting(_showMoodDotKey, defaultValue: true);
  }

  Future<bool> getShowMoodText() {
    return _getBoolSetting(_showMoodTextKey, defaultValue: true);
  }

  Future<bool> getShowMoodNote() {
    return _getBoolSetting(_showMoodNoteKey, defaultValue: true);
  }

  Future<void> setShowMoodDot(bool enabled) {
    return _setBoolSetting(_showMoodDotKey, enabled);
  }

  Future<void> setShowMoodText(bool enabled) {
    return _setBoolSetting(_showMoodTextKey, enabled);
  }

  Future<void> setShowMoodNote(bool enabled) {
    return _setBoolSetting(_showMoodNoteKey, enabled);
  }

  MoodEntry _fromRow(Map<String, Object?> row) {
    return MoodEntry(
      day: DateTime.parse(row['day'] as String),
      mood: MoodType.values.byName(row['mood'] as String),
      promptShown: row['prompt_shown'] == 1,
      updatedAt: DateTime.parse(row['updated_at'] as String),
      note: row['note'] as String? ?? '',
    );
  }

  Future<bool> _getBoolSetting(String key, {required bool defaultValue}) async {
    final rows = await _database.db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return defaultValue;
    }
    return rows.single['value'] == 'true';
  }

  Future<void> _setBoolSetting(String key, bool enabled) async {
    await _database.db.insert('settings', {
      'key': key,
      'value': enabled.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

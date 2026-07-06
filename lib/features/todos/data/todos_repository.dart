import 'package:sqflite_common/sqlite_api.dart';

import '../../../core/database/app_database.dart';
import '../domain/todo_item.dart';

class TodosRepository {
  const TodosRepository(this._database);

  static const _autoDeleteCompletedKey = 'todo_auto_delete_completed';

  final AppDatabase _database;

  Future<TodoItem> create({
    required String title,
    required DateTime dueDate,
    int priority = 0,
  }) async {
    final normalizedDueDate = _dateOnly(dueDate);
    final updatedAt = DateTime.now();
    final id = await _database.db.insert('todos', {
      'title': title,
      'due_date': normalizedDueDate.toIso8601String(),
      'priority': priority,
      'completed': 0,
      'updated_at': updatedAt.toIso8601String(),
    });
    return TodoItem(
      id: id,
      title: title,
      dueDate: normalizedDueDate,
      priority: priority,
      completed: false,
      updatedAt: updatedAt,
    );
  }

  Future<List<TodoItem>> listToday(DateTime day) async {
    final rows = await _database.db.query(
      'todos',
      where: 'due_date >= ? AND due_date < ? AND completed = ?',
      whereArgs: [
        _dateOnly(day).toIso8601String(),
        _dateOnly(day).add(const Duration(days: 1)).toIso8601String(),
        0,
      ],
      orderBy: 'priority DESC, updated_at DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<TodoItem>> listAll() async {
    final rows = await _database.db.query(
      'todos',
      orderBy: 'due_date ASC, priority DESC, id ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<void> setCompleted(int id, bool completed) async {
    await _database.db.update(
      'todos',
      {
        'completed': completed ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    await _database.db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> getAutoDeleteCompleted() {
    return _getBoolSetting(_autoDeleteCompletedKey, defaultValue: false);
  }

  Future<void> setAutoDeleteCompleted(bool enabled) {
    return _setBoolSetting(_autoDeleteCompletedKey, enabled);
  }

  Future<void> update({
    required int id,
    required String title,
    required DateTime dueDate,
    required int priority,
  }) async {
    await _database.db.update(
      'todos',
      {
        'title': title,
        'due_date': _dateOnly(dueDate).toIso8601String(),
        'priority': priority,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  TodoItem _fromRow(Map<String, Object?> row) {
    return TodoItem(
      id: row['id'] as int,
      title: row['title'] as String,
      dueDate: DateTime.parse(row['due_date'] as String),
      priority: row['priority'] as int,
      completed: row['completed'] == 1,
      updatedAt: DateTime.parse(row['updated_at'] as String),
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

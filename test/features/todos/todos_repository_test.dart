import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/core/database/app_database.dart';
import 'package:ocean_baby/features/todos/data/todos_repository.dart';

void main() {
  test('今日待办只返回今天未完成事项', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = TodosRepository(db);

    await repo.create(title: '交电费', dueDate: DateTime(2026, 7, 5), priority: 2);
    await repo.create(
      title: '下周整理',
      dueDate: DateTime(2026, 7, 12),
      priority: 1,
    );

    final today = await repo.listToday(DateTime(2026, 7, 5));
    expect(today.map((item) => item.title), ['交电费']);
  });

  test('今日待办能查询当天带时间的记录', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    await db.db.insert('todos', {
      'title': '晚上复盘',
      'due_date': DateTime(2026, 7, 5, 21).toIso8601String(),
      'priority': 1,
      'completed': 0,
      'updated_at': DateTime(2026, 7, 5, 8).toIso8601String(),
    });
    final repo = TodosRepository(db);

    final today = await repo.listToday(DateTime(2026, 7, 5));
    expect(today.map((item) => item.title), ['晚上复盘']);
  });

  test('待办可以修改日期优先级并完成', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = TodosRepository(db);

    final todo = await repo.create(
      title: '整理账单',
      dueDate: DateTime(2026, 7, 5),
    );
    await repo.update(
      id: todo.id,
      title: '整理支付宝账单',
      dueDate: DateTime(2026, 7, 6),
      priority: 2,
    );

    expect(await repo.listToday(DateTime(2026, 7, 5)), isEmpty);
    final moved = await repo.listToday(DateTime(2026, 7, 6));
    expect(moved.single.title, '整理支付宝账单');
    expect(moved.single.priority, 2);

    await repo.setCompleted(todo.id, true);
    expect(await repo.listToday(DateTime(2026, 7, 6)), isEmpty);
  });

  test('待办可以按 id 删除', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = TodosRepository(db);

    final deleted = await repo.create(
      title: '删除这一项',
      dueDate: DateTime(2026, 7, 5),
    );
    await repo.create(title: '保留事项', dueDate: DateTime(2026, 7, 5));

    await repo.delete(deleted.id);

    final all = await repo.listAll();
    expect(all.map((item) => item.title), ['保留事项']);
  });

  test('勾选后自动删除设置默认关闭且可以保存', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = TodosRepository(db);

    expect(await repo.getAutoDeleteCompleted(), isFalse);

    await repo.setAutoDeleteCompleted(true);
    expect(await repo.getAutoDeleteCompleted(), isTrue);

    await repo.setAutoDeleteCompleted(false);
    expect(await repo.getAutoDeleteCompleted(), isFalse);
  });

  test('全部待办返回不同日期并按优先级和创建顺序排列', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    await db.db.insert('todos', {
      'title': '明天未完成',
      'due_date': DateTime(2026, 7, 6).toIso8601String(),
      'priority': 1,
      'completed': 0,
      'updated_at': DateTime(2026, 7, 5, 10).toIso8601String(),
    });
    await db.db.insert('todos', {
      'title': '今天已完成',
      'due_date': DateTime(2026, 7, 5).toIso8601String(),
      'priority': 5,
      'completed': 1,
      'updated_at': DateTime(2026, 7, 5, 9).toIso8601String(),
    });
    await db.db.insert('todos', {
      'title': '今天未完成低优先级',
      'due_date': DateTime(2026, 7, 5).toIso8601String(),
      'priority': 1,
      'completed': 0,
      'updated_at': DateTime(2026, 7, 5, 8).toIso8601String(),
    });
    await db.db.insert('todos', {
      'title': '今天未完成高优先级',
      'due_date': DateTime(2026, 7, 5).toIso8601String(),
      'priority': 3,
      'completed': 0,
      'updated_at': DateTime(2026, 7, 5, 7).toIso8601String(),
    });
    await db.db.insert('todos', {
      'title': '今天未完成同优先级较新',
      'due_date': DateTime(2026, 7, 5).toIso8601String(),
      'priority': 1,
      'completed': 0,
      'updated_at': DateTime(2026, 7, 5, 11).toIso8601String(),
    });
    final repo = TodosRepository(db);

    final all = await repo.listAll();

    expect(all.map((item) => item.title), [
      '今天已完成',
      '今天未完成高优先级',
      '今天未完成低优先级',
      '今天未完成同优先级较新',
      '明天未完成',
    ]);
    expect(all.map((item) => item.completed), [
      true,
      false,
      false,
      false,
      false,
    ]);
  });

  test('勾选或取消勾选不会改变全部待办列表中的相对位置', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    await db.db.insert('todos', {
      'title': '第一项',
      'due_date': DateTime(2026, 7, 5).toIso8601String(),
      'priority': 1,
      'completed': 0,
      'updated_at': DateTime(2026, 7, 5, 10).toIso8601String(),
    });
    await db.db.insert('todos', {
      'title': '第二项',
      'due_date': DateTime(2026, 7, 5).toIso8601String(),
      'priority': 1,
      'completed': 0,
      'updated_at': DateTime(2026, 7, 5, 9).toIso8601String(),
    });
    final repo = TodosRepository(db);

    final first = await repo.listAll();
    await repo.setCompleted(first.first.id, true);
    final afterCompleted = await repo.listAll();
    await repo.setCompleted(first.first.id, false);
    final afterUncompleted = await repo.listAll();

    expect(first.map((item) => item.title), ['第一项', '第二项']);
    expect(afterCompleted.map((item) => item.title), ['第一项', '第二项']);
    expect(afterUncompleted.map((item) => item.title), ['第一项', '第二项']);
  });
}

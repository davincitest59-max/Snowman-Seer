import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/features/notes/domain/note.dart';
import 'package:ocean_baby/features/notes/ui/notes_page.dart';
import 'package:ocean_baby/features/todos/data/todos_repository.dart';
import 'package:ocean_baby/features/todos/domain/todo_item.dart';
import 'package:ocean_baby/features/todos/ui/todos_page.dart';

TodoItem _todo({
  required int id,
  required String title,
  required DateTime dueDate,
  bool completed = false,
  int priority = 0,
}) {
  return TodoItem(
    id: id,
    title: title,
    dueDate: dueDate,
    priority: priority,
    completed: completed,
    updatedAt: dueDate,
  );
}

void main() {
  testWidgets('笔记列表未点开时只显示标题不显示正文', (tester) async {
    final note = Note(
      id: 1,
      title: '买菜清单',
      content: '鸡蛋、牛奶',
      folder: '默认',
      pinned: false,
      imagePaths: const [],
      updatedAt: DateTime(2026, 7, 6),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteListItem(
            note: note,
            onTap: () {},
            onTogglePinned: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    expect(find.text('买菜清单'), findsOneWidget);
    expect(find.textContaining('鸡蛋'), findsNothing);
  });

  testWidgets('新建笔记按钮位于搜索和已有笔记下方', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final note = Note(
      id: 1,
      title: '已有笔记',
      content: '正文不在列表显示',
      folder: '默认',
      pinned: false,
      imagePaths: const [],
      updatedAt: DateTime(2026, 7, 6),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotesListContent(
            searchController: controller,
            notes: [note],
            isLoading: false,
            onSearchChanged: (_) {},
            onCreateNote: () {},
            onOpenNote: (_) {},
            onTogglePinned: (_) {},
            onDeleteNote: (_) {},
          ),
        ),
      ),
    );

    final searchTop = tester.getTopLeft(find.byType(TextField)).dy;
    final noteTop = tester.getTopLeft(find.text('已有笔记')).dy;
    final createTop = tester.getTopLeft(find.text('新建笔记')).dy;

    expect(searchTop, lessThan(noteTop));
    expect(noteTop, lessThan(createTop));
  });

  testWidgets('笔记详情默认为只读并提供编辑按钮', (tester) async {
    final note = Note(
      id: 1,
      title: '旅行照片',
      content: '海边日落',
      folder: '默认',
      pinned: false,
      imagePaths: const [],
      updatedAt: DateTime(2026, 7, 6),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NoteDetailDialog(note: note)),
      ),
    );

    expect(find.text('旅行照片'), findsOneWidget);
    expect(find.text('海边日落'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('图片笔记可以点击放大查看', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final note = Note(
      id: 1,
      title: '图片笔记',
      content: '点图查看',
      folder: '默认',
      pinned: false,
      imagePaths: const ['missing-image-a.png', 'missing-image-b.png'],
      updatedAt: DateTime(2026, 7, 6),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NoteDetailDialog(note: note)),
      ),
    );

    expect(
      find.byKey(const ValueKey('note-image-preview-trigger-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('note-image-preview-trigger-1')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('note-image-preview-trigger-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('图片预览'), findsNothing);
    final previewSize = tester.getSize(
      find.byKey(const ValueKey('note-image-preview-viewer')),
    );
    expect(previewSize.width, greaterThanOrEqualTo(390 * 0.95));
    expect(previewSize.height, greaterThanOrEqualTo(844 * 0.95));
  });

  testWidgets('笔记编辑弹框可以展示多张已添加图片', (tester) async {
    final note = Note(
      id: 1,
      title: '多图笔记',
      content: '两张图',
      folder: '默认',
      pinned: false,
      imagePaths: const ['missing-image-a.png', 'missing-image-b.png'],
      updatedAt: DateTime(2026, 7, 6),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NoteEditorDialog(note: note)),
      ),
    );

    expect(find.byKey(const ValueKey('note-editor-image-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('note-editor-image-1')), findsOneWidget);
    expect(find.text('继续添加图片'), findsOneWidget);
  });

  testWidgets('笔记编辑弹框提供图片笔记入口', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: NoteEditorDialog())),
    );

    expect(find.text('添加图片'), findsOneWidget);
    expect(find.text('标题'), findsOneWidget);
    expect(find.text('内容'), findsOneWidget);
  });

  testWidgets('待办按每天分组显示', (tester) async {
    final todos = [
      _todo(id: 1, title: '今天事项一', dueDate: DateTime(2026, 7, 6)),
      _todo(id: 2, title: '今天事项二', dueDate: DateTime(2026, 7, 6, 18)),
      _todo(id: 3, title: '明天事项', dueDate: DateTime(2026, 7, 7)),
      _todo(id: 4, title: '后天事项', dueDate: DateTime(2026, 7, 8)),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodosListContent(
            todos: todos,
            referenceDate: DateTime(2026, 7, 6),
            onCreateTodo: (_) {},
            onEditTodo: (_) {},
            onCompletedChanged: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('明天'), findsOneWidget);
    expect(find.text('2026年7月8日'), findsOneWidget);
  });

  testWidgets('日期分组可以展开和收起', (tester) async {
    final todos = [
      _todo(id: 1, title: '今天事项', dueDate: DateTime(2026, 7, 6)),
      _todo(id: 2, title: '明天事项', dueDate: DateTime(2026, 7, 7)),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodosListContent(
            todos: todos,
            referenceDate: DateTime(2026, 7, 6),
            onCreateTodo: (_) {},
            onEditTodo: (_) {},
            onCompletedChanged: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('今天事项'), findsOneWidget);
    expect(find.text('明天事项'), findsNothing);

    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();

    expect(find.text('今天事项'), findsNothing);

    await tester.tap(find.text('明天'));
    await tester.pumpAndSettle();

    expect(find.text('明天事项'), findsOneWidget);
  });

  testWidgets('非空列表没有今天待办时仍显示今天添加入口', (tester) async {
    DateTime? createdDueDate;
    final todos = [_todo(id: 1, title: '明天事项', dueDate: DateTime(2026, 7, 7))];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodosListContent(
            todos: todos,
            referenceDate: DateTime(2026, 7, 6),
            onCreateTodo: (dueDate) => createdDueDate = dueDate,
            onEditTodo: (_) {},
            onCompletedChanged: (_, _) {},
          ),
        ),
      ),
    );

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('明天事项'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('todo-add-2026-07-06')));

    expect(createdDueDate, DateTime(2026, 7, 6));
  });

  testWidgets('日期分组内添加待办按钮固定在已有待办下方', (tester) async {
    final todos = [
      _todo(id: 1, title: '整理账单', dueDate: DateTime(2026, 7, 6), priority: 1),
      _todo(
        id: 2,
        title: '已完成事项',
        dueDate: DateTime(2026, 7, 6),
        completed: true,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodosListContent(
            todos: todos,
            referenceDate: DateTime(2026, 7, 6),
            onCreateTodo: (_) {},
            onEditTodo: (_) {},
            onCompletedChanged: (_, _) {},
          ),
        ),
      ),
    );

    final unfinishedTop = tester.getTopLeft(find.text('整理账单')).dy;
    final completedTop = tester.getTopLeft(find.text('已完成事项')).dy;
    final addTop = tester.getTopLeft(find.text('添加待办')).dy;

    expect(unfinishedTop, lessThan(completedTop));
    expect(completedTop, lessThan(addTop));
  });

  testWidgets('已勾选待办显示删除按钮并可触发删除', (tester) async {
    TodoItem? deletedTodo;
    final todos = [
      _todo(
        id: 1,
        title: '已完成事项',
        dueDate: DateTime(2026, 7, 6),
        completed: true,
      ),
      _todo(id: 2, title: '未完成事项', dueDate: DateTime(2026, 7, 6)),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodosListContent(
            todos: todos,
            referenceDate: DateTime(2026, 7, 6),
            onCreateTodo: (_) {},
            onEditTodo: (_) {},
            onCompletedChanged: (_, _) {},
            onDeleteTodo: (todo) => deletedTodo = todo,
          ),
        ),
      ),
    );

    final deleteButton = find.byTooltip('删除待办');
    expect(deleteButton, findsOneWidget);

    await tester.tap(deleteButton);

    expect(deletedTodo?.id, 1);
  });

  testWidgets('开启勾选自动删除后勾选待办会从列表移除', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final repository = _FakeTodosRepository([
      _todo(id: 1, title: '自动删除事项', dueDate: today),
      _todo(id: 2, title: '保留事项', dueDate: today),
    ], autoDeleteCompleted: true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TodosPage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, '自动删除事项'));
    await tester.pump();

    expect(repository.deletedIds, [1]);
    expect(find.text('自动删除事项'), findsNothing);
    expect(find.text('保留事项'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('勾选今天待办后添加待办按钮仍固定在已有待办下方', (tester) async {
    var todos = [_todo(id: 1, title: '今天事项', dueDate: DateTime(2026, 7, 6))];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return TodosListContent(
                todos: todos,
                referenceDate: DateTime(2026, 7, 6),
                onCreateTodo: (_) {},
                onEditTodo: (_) {},
                onCompletedChanged: (todo, completed) {
                  setState(() {
                    todos = todos
                        .map(
                          (item) => item.id == todo.id
                              ? _todo(
                                  id: item.id,
                                  title: item.title,
                                  dueDate: item.dueDate,
                                  completed: completed,
                                  priority: item.priority,
                                )
                              : item,
                        )
                        .toList();
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(CheckboxListTile, '今天事项'));
    await tester.pumpAndSettle();

    final todoTop = tester.getTopLeft(find.text('今天事项')).dy;
    final addTop = tester.getTopLeft(find.text('添加待办')).dy;

    expect(todoTop, lessThan(addTop));
  });

  testWidgets('同一天多个待办勾选后相对位置保持不变', (tester) async {
    var todos = [
      _todo(id: 1, title: '第一项', dueDate: DateTime(2026, 7, 6)),
      _todo(id: 2, title: '第二项', dueDate: DateTime(2026, 7, 6)),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return TodosListContent(
                todos: todos,
                referenceDate: DateTime(2026, 7, 6),
                onCreateTodo: (_) {},
                onEditTodo: (_) {},
                onCompletedChanged: (todo, completed) {
                  setState(() {
                    todos = todos
                        .map(
                          (item) => item.id == todo.id
                              ? _todo(
                                  id: item.id,
                                  title: item.title,
                                  dueDate: item.dueDate,
                                  completed: completed,
                                  priority: item.priority,
                                )
                              : item,
                        )
                        .toList();
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('第一项')).dy,
      lessThan(tester.getTopLeft(find.text('第二项')).dy),
    );

    await tester.tap(find.widgetWithText(CheckboxListTile, '第一项'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('第一项')).dy,
      lessThan(tester.getTopLeft(find.text('第二项')).dy),
    );
  });

  testWidgets('勾选待办刷新时保留列表而不是显示加载闪屏', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final repository = _FakeTodosRepository([
      _todo(id: 1, title: '今天事项一', dueDate: today),
      _todo(id: 2, title: '今天事项二', dueDate: today),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TodosPage(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.tap(find.widgetWithText(CheckboxListTile, '今天事项一'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('今天事项一'), findsOneWidget);
    expect(find.text('今天事项二'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('过去日期分组不显示添加待办按钮', (tester) async {
    final todos = [
      _todo(id: 1, title: '昨天事项', dueDate: DateTime(2026, 7, 5)),
      _todo(id: 2, title: '今天事项', dueDate: DateTime(2026, 7, 6)),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodosListContent(
            todos: todos,
            referenceDate: DateTime(2026, 7, 6),
            onCreateTodo: (_) {},
            onEditTodo: (_) {},
            onCompletedChanged: (_, _) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('2026年7月5日'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('todo-add-2026-07-05')), findsNothing);
    expect(find.byKey(const ValueKey('todo-add-2026-07-06')), findsOneWidget);
  });

  testWidgets('点击日期分组内添加待办会传回该分组日期', (tester) async {
    DateTime? createdDueDate;
    final todos = [
      _todo(id: 1, title: '今天事项', dueDate: DateTime(2026, 7, 6)),
      _todo(id: 2, title: '明天事项', dueDate: DateTime(2026, 7, 7)),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodosListContent(
            todos: todos,
            referenceDate: DateTime(2026, 7, 6),
            onCreateTodo: (dueDate) => createdDueDate = dueDate,
            onEditTodo: (_) {},
            onCompletedChanged: (_, _) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('明天'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('todo-add-2026-07-07')));

    expect(createdDueDate, DateTime(2026, 7, 7));
  });

  testWidgets('勾选待办后不改变其它日期分组的展开状态', (tester) async {
    final first = _todo(id: 1, title: '今天事项', dueDate: DateTime(2026, 7, 6));
    final second = _todo(id: 2, title: '明天事项', dueDate: DateTime(2026, 7, 7));
    var todos = [first, second];
    var showList = true;
    final bucket = PageStorageBucket();

    Widget buildPage() {
      return MaterialApp(
        home: Scaffold(
          body: PageStorage(
            bucket: bucket,
            child: showList
                ? TodosListContent(
                    todos: todos,
                    referenceDate: DateTime(2026, 7, 6),
                    onCreateTodo: (_) {},
                    onEditTodo: (_) {},
                    onCompletedChanged: (todo, completed) {
                      todos = todos
                          .map(
                            (item) => item.id == todo.id
                                ? _todo(
                                    id: item.id,
                                    title: item.title,
                                    dueDate: item.dueDate,
                                    completed: completed,
                                  )
                                : item,
                          )
                          .toList();
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildPage());

    await tester.tap(find.text('明天'));
    await tester.pumpAndSettle();
    expect(find.text('明天事项'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, '今天事项'));
    await tester.pumpAndSettle();
    showList = false;
    await tester.pumpWidget(buildPage());
    showList = true;
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('明天事项'), findsOneWidget);
  });
}

class _FakeTodosRepository implements TodosRepository {
  _FakeTodosRepository(this._todos, {this.autoDeleteCompleted = false});

  List<TodoItem> _todos;
  final bool autoDeleteCompleted;
  final deletedIds = <int>[];
  var _listAllCalls = 0;

  @override
  Future<List<TodoItem>> listAll() {
    _listAllCalls++;
    if (_listAllCalls == 1) {
      return Future.value(_todos);
    }
    return Future<List<TodoItem>>.delayed(
      const Duration(seconds: 1),
      () => _todos,
    );
  }

  @override
  Future<void> setCompleted(int id, bool completed) async {
    _todos = _todos
        .map(
          (item) => item.id == id
              ? _todo(
                  id: item.id,
                  title: item.title,
                  dueDate: item.dueDate,
                  completed: completed,
                  priority: item.priority,
                )
              : item,
        )
        .toList();
  }

  @override
  Future<bool> getAutoDeleteCompleted() async {
    return autoDeleteCompleted;
  }

  @override
  Future<void> delete(int id) async {
    deletedIds.add(id);
    _todos = _todos.where((item) => item.id != id).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

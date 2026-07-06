# 设置心情待办折叠分组 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Ocean Baby 的设置页改为可展开收起，把每日心情弹框改为选择后确认保存，并把待办按日期分组且支持展开收起。

**Architecture:** 继续沿用当前 Flutter 本地优先架构，不引入账号、云同步或新数据库表。设置页使用可折叠分类组件管理界面状态；心情弹框在本地组件内暂存选中的心情；待办仓库新增全量查询，待办页面按 `dueDate` 在界面层分组。

**Tech Stack:** Flutter、Material 组件、sqflite、flutter_test、现有直接 Flutter snapshot 命令。

---

## 文件结构

- Modify: `lib/features/home/ui/home_page.dart`
  - 把 `_SettingsCategory` 改为可展开/可收起分类。
  - 保留“外观设置”“心情设置”“账本设置”的现有内容。
- Modify: `lib/features/mood/ui/mood_prompt_dialog.dart`
  - 把心情选择改为 `ChoiceChip` 式选中状态。
  - 增加“取消”和“确定”按钮。
  - 未选择心情时禁用“确定”。
- Modify: `lib/features/todos/data/todos_repository.dart`
  - 新增 `listAll()`，返回所有待办。
  - 保留 `listToday()`，避免影响已有测试和可能的调用方。
- Modify: `lib/features/todos/ui/todos_page.dart`
  - `TodosPage` 从 `listToday()` 切换为 `listAll()`。
  - `TodosListContent` 按日期分组。
  - 每个日期组使用可展开/收起面板。
  - 分组内“添加待办”按钮默认使用该分组日期。
- Modify: `test/widget/navigation_and_theme_test.dart`
  - 更新设置页测试，验证分类默认收起、点击展开、再次点击收起。
- Modify: `test/widget_test.dart`
  - 更新心情弹框测试，验证选择后不会立即关闭、确定后才返回结果、未选择时不能确定。
- Modify: `test/features/todos/todos_repository_test.dart`
  - 新增 `listAll()` 查询测试。
- Modify: `test/widget/interactive_pages_test.dart`
  - 更新待办列表测试，验证按日期分组、分组可展开收起、添加按钮位置。

---

### Task 1: 设置页分类改为可展开收起

**Files:**
- Modify: `test/widget/navigation_and_theme_test.dart`
- Modify: `lib/features/home/ui/home_page.dart`

- [ ] **Step 1: 写失败测试，验证设置分类默认收起并可展开收起**

在 `test/widget/navigation_and_theme_test.dart` 的设置页测试区域新增测试：

```dart
testWidgets('设置页分类默认收起并可以展开收起', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HomeSettingsSection(
            promptEnabledFuture: Future.value(true),
            showMoodDotFuture: Future.value(true),
            showMoodTextFuture: Future.value(true),
            showMoodNoteFuture: Future.value(true),
            notificationEnabledFuture: Future.value(false),
            onPromptChanged: (_) {},
            onShowMoodDotChanged: (_) {},
            onShowMoodTextChanged: (_) {},
            onShowMoodNoteChanged: (_) {},
            onNotificationSettingsRequested: () {},
            onThemeChanged: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  expect(find.text('外观设置'), findsOneWidget);
  expect(find.text('高级配色'), findsNothing);

  await tester.tap(find.text('外观设置'));
  await tester.pumpAndSettle();

  expect(find.text('高级配色'), findsOneWidget);

  await tester.tap(find.text('外观设置'));
  await tester.pumpAndSettle();

  expect(find.text('高级配色'), findsNothing);
});
```

- [ ] **Step 2: 运行设置页测试确认失败**

Run:

```powershell
$env:JAVA_HOME='E:\codex-tools\jdk17\jdk-17.0.19+10'
$env:ANDROID_HOME='E:\codex-tools\android-sdk'
$env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
$env:PATH="$env:JAVA_HOME\bin;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:ANDROID_HOME\platform-tools;E:\codex-tools\flutter\bin;" + $env:PATH
$env:FLUTTER_ROOT='E:\codex-tools\flutter'
& 'E:\codex-tools\flutter\bin\cache\dart-sdk\bin\dart.exe' --disable-dart-dev --packages='E:\codex-tools\flutter\packages\flutter_tools\.dart_tool\package_config.json' 'E:\codex-tools\flutter\bin\cache\flutter_tools.snapshot' test --no-pub test/widget/navigation_and_theme_test.dart --plain-name "设置页分类默认收起并可以展开收起"
```

Expected: FAIL，因为当前 `_SettingsCategory` 始终显示内容。

- [ ] **Step 3: 修改设置分类组件**

在 `lib/features/home/ui/home_page.dart` 中把 `_SettingsCategory` 的 `build` 方法改为使用 `ExpansionTile`：

```dart
class _SettingsCategory extends StatelessWidget {
  const _SettingsCategory({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          initiallyExpanded: false,
          title: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          children: [child],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 更新原有设置页内容测试**

`test/widget/navigation_and_theme_test.dart` 中原本直接断言“高级配色”“每日心情弹框”“自动记账”的测试，需要先点击对应分类：

```dart
await tester.tap(find.text('外观设置'));
await tester.pumpAndSettle();
await tester.tap(find.text('心情设置'));
await tester.pumpAndSettle();
await tester.tap(find.text('账本设置'));
await tester.pumpAndSettle();
```

然后保留原有断言。

- [ ] **Step 5: 运行设置页相关测试确认通过**

Run:

```powershell
& 'E:\codex-tools\flutter\bin\cache\dart-sdk\bin\dart.exe' --disable-dart-dev --packages='E:\codex-tools\flutter\packages\flutter_tools\.dart_tool\package_config.json' 'E:\codex-tools\flutter\bin\cache\flutter_tools.snapshot' test --no-pub test/widget/navigation_and_theme_test.dart --reporter expanded
```

Expected: PASS。

---

### Task 2: 心情弹框改为选择后确认保存

**Files:**
- Modify: `test/widget_test.dart`
- Modify: `lib/features/mood/ui/mood_prompt_dialog.dart`

- [ ] **Step 1: 写失败测试，验证弹框标题和确定按钮状态**

在 `test/widget_test.dart` 中更新心情弹框测试：

```dart
testWidgets('首次心情弹框显示选择今日心情和三个选项', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: MoodPromptDialog())),
  );

  expect(find.text('选择今日心情'), findsOneWidget);
  expect(find.text('开心'), findsOneWidget);
  expect(find.text('生气'), findsOneWidget);
  expect(find.text('伤心'), findsOneWidget);
  expect(find.text('写下今天心情的原因'), findsOneWidget);
});

testWidgets('心情弹框未选择心情时不能确定', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: MoodPromptDialog())),
  );

  final confirm = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, '确定'),
  );
  expect(confirm.onPressed, isNull);
});
```

- [ ] **Step 2: 写失败测试，验证点心情不关闭，点确定才返回结果**

在 `test/widget_test.dart` 新增：

```dart
testWidgets('心情弹框选择心情后点击确定才返回结果', (tester) async {
  MoodPromptResult? result;

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return FilledButton(
            onPressed: () async {
              result = await showDialog<MoodPromptResult>(
                context: context,
                builder: (_) => const MoodPromptDialog(),
              );
            },
            child: const Text('打开弹框'),
          );
        },
      ),
    ),
  );

  await tester.tap(find.text('打开弹框'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('开心'));
  await tester.pumpAndSettle();

  expect(find.text('选择今日心情'), findsOneWidget);
  expect(result, isNull);

  await tester.enterText(find.byType(TextField), '今天很顺利');
  await tester.tap(find.text('确定'));
  await tester.pumpAndSettle();

  expect(result?.mood, MoodType.happy);
  expect(result?.note, '今天很顺利');
});
```

- [ ] **Step 3: 运行心情弹框测试确认失败**

Run:

```powershell
& 'E:\codex-tools\flutter\bin\cache\dart-sdk\bin\dart.exe' --disable-dart-dev --packages='E:\codex-tools\flutter\packages\flutter_tools\.dart_tool\package_config.json' 'E:\codex-tools\flutter\bin\cache\flutter_tools.snapshot' test --no-pub test/widget_test.dart --reporter expanded
```

Expected: FAIL，因为当前点击心情会立刻关闭。

- [ ] **Step 4: 修改心情弹框实现**

在 `lib/features/mood/ui/mood_prompt_dialog.dart` 中新增 `_selectedMood` 状态，把 `ActionChip` 改为 `ChoiceChip`，并增加 actions：

```dart
class _MoodPromptDialogState extends State<MoodPromptDialog> {
  final _noteController = TextEditingController();
  MoodType? _selectedMood;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _confirm() {
    final mood = _selectedMood;
    if (mood == null) return;
    Navigator.of(context).pop(
      MoodPromptResult(mood: mood, note: _noteController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择今日心情'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MoodChoice(
                mood: MoodType.happy,
                selectedMood: _selectedMood,
                label: '开心',
                color: Colors.green,
                onSelected: (mood) => setState(() => _selectedMood = mood),
              ),
              _MoodChoice(
                mood: MoodType.angry,
                selectedMood: _selectedMood,
                label: '生气',
                color: Colors.red,
                onSelected: (mood) => setState(() => _selectedMood = mood),
              ),
              _MoodChoice(
                mood: MoodType.sad,
                selectedMood: _selectedMood,
                label: '伤心',
                color: Colors.black,
                onSelected: (mood) => setState(() => _selectedMood = mood),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: '心情原因',
              hintText: '写下今天心情的原因',
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selectedMood == null ? null : _confirm,
          child: const Text('确定'),
        ),
      ],
    );
  }
}
```

把 `_MoodChoice` 改为：

```dart
class _MoodChoice extends StatelessWidget {
  const _MoodChoice({
    required this.mood,
    required this.selectedMood,
    required this.label,
    required this.color,
    required this.onSelected,
  });

  final MoodType mood;
  final MoodType? selectedMood;
  final String label;
  final Color color;
  final ValueChanged<MoodType> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: CircleAvatar(backgroundColor: color),
      label: Text(label),
      selected: selectedMood == mood,
      onSelected: (_) => onSelected(mood),
    );
  }
}
```

- [ ] **Step 5: 运行心情弹框测试确认通过**

Run:

```powershell
& 'E:\codex-tools\flutter\bin\cache\dart-sdk\bin\dart.exe' --disable-dart-dev --packages='E:\codex-tools\flutter\packages\flutter_tools\.dart_tool\package_config.json' 'E:\codex-tools\flutter\bin\cache\flutter_tools.snapshot' test --no-pub test/widget_test.dart --reporter expanded
```

Expected: PASS。

---

### Task 3: 待办仓库新增全量查询

**Files:**
- Modify: `test/features/todos/todos_repository_test.dart`
- Modify: `lib/features/todos/data/todos_repository.dart`

- [ ] **Step 1: 写失败测试，验证 `listAll()` 返回全部待办**

在 `test/features/todos/todos_repository_test.dart` 新增：

```dart
test('可以按日期读取全部待办', () async {
  final db = await AppDatabase.openInMemory();
  addTearDown(db.close);
  final repo = TodosRepository(db);

  await repo.create(title: '今天未完成', dueDate: DateTime(2026, 7, 6), priority: 1);
  final completed = await repo.create(
    title: '明天已完成',
    dueDate: DateTime(2026, 7, 7),
    priority: 0,
  );
  await repo.setCompleted(completed.id, true);

  final all = await repo.listAll();

  expect(all.map((item) => item.title), ['今天未完成', '明天已完成']);
  expect(all.last.completed, isTrue);
});
```

- [ ] **Step 2: 运行仓库测试确认失败**

Run:

```powershell
& 'E:\codex-tools\flutter\bin\cache\dart-sdk\bin\dart.exe' --disable-dart-dev --packages='E:\codex-tools\flutter\packages\flutter_tools\.dart_tool\package_config.json' 'E:\codex-tools\flutter\bin\cache\flutter_tools.snapshot' test --no-pub test/features/todos/todos_repository_test.dart --plain-name "可以按日期读取全部待办"
```

Expected: FAIL，因为 `TodosRepository.listAll()` 还不存在。

- [ ] **Step 3: 实现 `listAll()`**

在 `lib/features/todos/data/todos_repository.dart` 中添加：

```dart
Future<List<TodoItem>> listAll() async {
  final rows = await _database.db.query(
    'todos',
    orderBy: 'due_date ASC, completed ASC, priority DESC, updated_at DESC',
  );
  return rows.map(_fromRow).toList();
}
```

- [ ] **Step 4: 运行仓库测试确认通过**

Run:

```powershell
& 'E:\codex-tools\flutter\bin\cache\dart-sdk\bin\dart.exe' --disable-dart-dev --packages='E:\codex-tools\flutter\packages\flutter_tools\.dart_tool\package_config.json' 'E:\codex-tools\flutter\bin\cache\flutter_tools.snapshot' test --no-pub test/features/todos/todos_repository_test.dart --reporter expanded
```

Expected: PASS。

---

### Task 4: 待办按日期分组并支持展开收起

**Files:**
- Modify: `test/widget/interactive_pages_test.dart`
- Modify: `lib/features/todos/ui/todos_page.dart`

- [ ] **Step 1: 更新待办列表回调签名测试代码**

把 `TodosListContent` 的测试调用从：

```dart
onCreateTodo: () {},
```

改为：

```dart
onCreateTodo: (_) {},
referenceDate: DateTime(2026, 7, 6),
```

- [ ] **Step 2: 写失败测试，验证待办按日期分组**

在 `test/widget/interactive_pages_test.dart` 新增：

```dart
testWidgets('待办按每天分组显示', (tester) async {
  final todos = [
    TodoItem(
      id: 1,
      title: '今天事项',
      dueDate: DateTime(2026, 7, 6),
      priority: 1,
      completed: false,
      updatedAt: DateTime(2026, 7, 6),
    ),
    TodoItem(
      id: 2,
      title: '明天事项',
      dueDate: DateTime(2026, 7, 7),
      priority: 0,
      completed: false,
      updatedAt: DateTime(2026, 7, 7),
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

  expect(find.text('今天'), findsOneWidget);
  expect(find.text('明天'), findsOneWidget);
  expect(find.text('今天事项'), findsOneWidget);
  expect(find.text('明天事项'), findsNothing);
});
```

- [ ] **Step 3: 写失败测试，验证日期分组可展开收起**

在 `test/widget/interactive_pages_test.dart` 新增：

```dart
testWidgets('待办日期分组可以展开和收起', (tester) async {
  final todos = [
    TodoItem(
      id: 1,
      title: '明天事项',
      dueDate: DateTime(2026, 7, 7),
      priority: 0,
      completed: false,
      updatedAt: DateTime(2026, 7, 7),
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

  expect(find.text('明天事项'), findsNothing);

  await tester.tap(find.text('明天'));
  await tester.pumpAndSettle();
  expect(find.text('明天事项'), findsOneWidget);

  await tester.tap(find.text('明天'));
  await tester.pumpAndSettle();
  expect(find.text('明天事项'), findsNothing);
});
```

- [ ] **Step 4: 写失败测试，验证分组内添加按钮位置**

调整已有“添加待办按钮位于未完成待办下方”测试，让它断言同一日期分组内的顺序：

```dart
testWidgets('日期分组内添加待办按钮位于未完成待办下方', (tester) async {
  final todos = [
    TodoItem(
      id: 1,
      title: '整理账单',
      dueDate: DateTime(2026, 7, 6),
      priority: 1,
      completed: false,
      updatedAt: DateTime(2026, 7, 6),
    ),
    TodoItem(
      id: 2,
      title: '已完成事项',
      dueDate: DateTime(2026, 7, 6),
      priority: 0,
      completed: true,
      updatedAt: DateTime(2026, 7, 6),
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
  final addTop = tester.getTopLeft(find.text('添加待办')).dy;
  final completedTop = tester.getTopLeft(find.text('已完成事项')).dy;

  expect(unfinishedTop, lessThan(addTop));
  expect(addTop, lessThan(completedTop));
});
```

- [ ] **Step 5: 运行待办 widget 测试确认失败**

Run:

```powershell
& 'E:\codex-tools\flutter\bin\cache\dart-sdk\bin\dart.exe' --disable-dart-dev --packages='E:\codex-tools\flutter\packages\flutter_tools\.dart_tool\package_config.json' 'E:\codex-tools\flutter\bin\cache\flutter_tools.snapshot' test --no-pub test/widget/interactive_pages_test.dart --reporter expanded
```

Expected: FAIL，因为当前待办列表还没有按日期分组。

- [ ] **Step 6: 修改 `TodosPage` 读取全部待办**

在 `lib/features/todos/ui/todos_page.dart` 中把 `_reload()` 改为：

```dart
void _reload() {
  _todosFuture = widget.repository.listAll();
}
```

把 `_createTodo` 签名改为：

```dart
Future<void> _createTodo({TodoItem? todo, DateTime? initialDueDate}) async {
  final draft = await showDialog<_TodoDraft>(
    context: context,
    builder: (_) => _TodoDialog(todo: todo, initialDueDate: initialDueDate),
  );
  if (draft == null || draft.title.trim().isEmpty) return;
  ...
}
```

在 `TodosListContent` 调用处改为：

```dart
return TodosListContent(
  todos: todos,
  onCreateTodo: (date) => _createTodo(initialDueDate: date),
  onEditTodo: (todo) => _createTodo(todo: todo),
  onCompletedChanged: _setCompleted,
);
```

- [ ] **Step 7: 修改 `_TodoDialog` 支持默认日期**

在 `lib/features/todos/ui/todos_page.dart` 中把 `_TodoDialog` 改为：

```dart
class _TodoDialog extends StatefulWidget {
  const _TodoDialog({this.todo, this.initialDueDate});

  final TodoItem? todo;
  final DateTime? initialDueDate;
  ...
}
```

在 `_TodoDialogState.initState()` 中：

```dart
_dueDate = todo?.dueDate ?? widget.initialDueDate ?? DateTime.now();
```

- [ ] **Step 8: 修改 `TodosListContent` 分组渲染**

把 `TodosListContent` 的 `onCreateTodo` 类型改为：

```dart
final ValueChanged<DateTime> onCreateTodo;
final DateTime? referenceDate;
```

构造函数增加：

```dart
this.referenceDate,
```

在 `build` 中按日期分组：

```dart
final today = _dateOnly(referenceDate ?? DateTime.now());
final groups = _groupByDate(todos);
```

空状态使用：

```dart
if (todos.isEmpty) ...[
  const Card(
    child: ListTile(
      title: Text('暂无待办'),
      subtitle: Text('点击下方按钮添加要做的事'),
    ),
  ),
  const SizedBox(height: 12),
  FilledButton.icon(
    onPressed: () => onCreateTodo(today),
    icon: const Icon(Icons.add_task),
    label: const Text('添加待办'),
  ),
]
```

非空状态渲染：

```dart
...groups.map((group) {
  final unfinished = group.todos.where((todo) => !todo.completed).toList();
  final completed = group.todos.where((todo) => todo.completed).toList();
  return Card(
    child: ExpansionTile(
      initiallyExpanded: _isSameDay(group.date, today),
      title: Text(_formatGroupTitle(group.date, today)),
      children: [
        ...unfinished.map(_buildTodoTile),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => onCreateTodo(group.date),
              icon: const Icon(Icons.add_task),
              label: const Text('添加待办'),
            ),
          ),
        ),
        ...completed.map(_buildTodoTile),
      ],
    ),
  );
})
```

新增私有辅助类型和方法：

```dart
class _TodoDateGroup {
  const _TodoDateGroup({required this.date, required this.todos});

  final DateTime date;
  final List<TodoItem> todos;
}
```

```dart
List<_TodoDateGroup> _groupByDate(List<TodoItem> todos) {
  final grouped = <DateTime, List<TodoItem>>{};
  for (final todo in todos) {
    final date = _dateOnly(todo.dueDate);
    grouped.putIfAbsent(date, () => []).add(todo);
  }
  final dates = grouped.keys.toList()..sort();
  return dates
      .map((date) => _TodoDateGroup(date: date, todos: grouped[date]!))
      .toList();
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatGroupTitle(DateTime value, DateTime today) {
  if (_isSameDay(value, today)) return '今天';
  if (_isSameDay(value, today.add(const Duration(days: 1)))) return '明天';
  return '${value.year}年${value.month}月${value.day}日';
}
```

- [ ] **Step 9: 运行待办 widget 测试确认通过**

Run:

```powershell
& 'E:\codex-tools\flutter\bin\cache\dart-sdk\bin\dart.exe' --disable-dart-dev --packages='E:\codex-tools\flutter\packages\flutter_tools\.dart_tool\package_config.json' 'E:\codex-tools\flutter\bin\cache\flutter_tools.snapshot' test --no-pub test/widget/interactive_pages_test.dart --reporter expanded
```

Expected: PASS。

---

### Task 5: 全量验证并重新生成 APK

**Files:**
- No direct source edit.

- [ ] **Step 1: 格式化**

Run:

```powershell
& 'E:\codex-tools\flutter\bin\cache\dart-sdk\bin\dart.exe' format lib test
```

Expected: Dart formatter completes without syntax errors.

- [ ] **Step 2: 静态分析**

Run:

```powershell
& 'E:\codex-tools\flutter\bin\cache\dart-sdk\bin\dart.exe' --disable-dart-dev --packages='E:\codex-tools\flutter\packages\flutter_tools\.dart_tool\package_config.json' 'E:\codex-tools\flutter\bin\cache\flutter_tools.snapshot' analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 3: 全量测试**

Run:

```powershell
& 'E:\codex-tools\flutter\bin\cache\dart-sdk\bin\dart.exe' --disable-dart-dev --packages='E:\codex-tools\flutter\packages\flutter_tools\.dart_tool\package_config.json' 'E:\codex-tools\flutter\bin\cache\flutter_tools.snapshot' test --no-pub --reporter expanded
```

Expected: All tests passed.

- [ ] **Step 4: 构建 release APK**

Run:

```powershell
$env:JAVA_HOME='E:\codex-tools\jdk17\jdk-17.0.19+10'
$env:ANDROID_HOME='E:\codex-tools\android-sdk'
$env:ANDROID_SDK_ROOT=$env:ANDROID_HOME
$env:PATH="$env:JAVA_HOME\bin;$env:ANDROID_HOME\cmdline-tools\latest\bin;$env:ANDROID_HOME\platform-tools;E:\codex-tools\flutter\bin;" + $env:PATH
$env:FLUTTER_ROOT='E:\codex-tools\flutter'
& 'E:\codex-tools\flutter\bin\cache\dart-sdk\bin\dart.exe' --disable-dart-dev --packages='E:\codex-tools\flutter\packages\flutter_tools\.dart_tool\package_config.json' 'E:\codex-tools\flutter\bin\cache\flutter_tools.snapshot' build apk --release --no-tree-shake-icons --no-pub
```

Expected: `Built build\app\outputs\flutter-apk\app-release.apk`

- [ ] **Step 5: 验证 APK 签名和包信息**

Run:

```powershell
$env:JAVA_HOME='E:\codex-tools\jdk17\jdk-17.0.19+10'
$env:PATH="$env:JAVA_HOME\bin;" + $env:PATH
& 'E:\codex-tools\android-sdk\build-tools\36.0.0\apksigner.bat' verify --print-certs 'build\app\outputs\flutter-apk\app-release.apk'
& 'E:\codex-tools\android-sdk\build-tools\36.0.0\aapt.exe' dump badging 'build\app\outputs\flutter-apk\app-release.apk' | Select-Object -First 12
Get-FileHash -Algorithm SHA256 -LiteralPath 'build\app\outputs\flutter-apk\app-release.apk'
```

Expected:
- 签名校验输出证书信息。
- 包名仍为 `com.oceanbaby.ocean_baby`。
- 应用名仍为 `Ocean Baby`。
- 输出新的 SHA256。

- [ ] **Step 6: 清理 Windows native_assets 残留**

Run:

```powershell
$workspace = (Resolve-Path -LiteralPath '.').Path
$target = Join-Path $workspace 'build\native_assets\windows'
if (Test-Path -LiteralPath $target) {
  $resolved = (Resolve-Path -LiteralPath $target).Path
  if (-not $resolved.StartsWith($workspace, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "拒绝删除工作区外路径: $resolved"
  }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
```

Expected: Windows native assets output is absent.

---

## 自检

- Spec coverage: 设置页折叠由 Task 1 覆盖；心情弹框确认保存由 Task 2 覆盖；待办仓库全量查询由 Task 3 覆盖；待办日期分组、展开收起和添加按钮位置由 Task 4 覆盖；APK 交付由 Task 5 覆盖。
- Placeholder scan: 本计划不包含待填充占位项。
- Type consistency: `TodosListContent.onCreateTodo` 统一改为 `ValueChanged<DateTime>`；`_TodoDialog.initialDueDate` 为 `DateTime?`；`TodosRepository.listAll()` 返回 `Future<List<TodoItem>>`。

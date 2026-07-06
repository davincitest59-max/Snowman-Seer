import 'package:flutter/material.dart';

import '../../mood/ui/mood_page_title.dart';
import '../data/todos_repository.dart';
import '../domain/todo_item.dart';

class TodosPage extends StatefulWidget {
  const TodosPage({super.key, required this.repository});

  final TodosRepository repository;

  @override
  State<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends State<TodosPage> {
  late Future<List<TodoItem>> _todosFuture;
  var _visibleTodos = const <TodoItem>[];
  var _hasLoadedTodos = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _todosFuture = _loadTodos();
  }

  Future<List<TodoItem>> _loadTodos() async {
    final todos = await widget.repository.listAll();
    _visibleTodos = todos;
    _hasLoadedTodos = true;
    return todos;
  }

  Future<void> _createTodo({TodoItem? todo, DateTime? dueDate}) async {
    final draft = await showDialog<_TodoDraft>(
      context: context,
      builder: (_) => _TodoDialog(todo: todo, initialDueDate: dueDate),
    );
    if (draft == null || draft.title.trim().isEmpty) return;

    if (todo == null) {
      await widget.repository.create(
        title: draft.title.trim(),
        dueDate: draft.dueDate,
        priority: draft.priority,
      );
    } else {
      await widget.repository.update(
        id: todo.id,
        title: draft.title.trim(),
        dueDate: draft.dueDate,
        priority: draft.priority,
      );
    }
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _setCompleted(TodoItem todo, bool completed) async {
    final shouldAutoDelete =
        completed && await widget.repository.getAutoDeleteCompleted();
    if (!mounted) return;

    if (shouldAutoDelete) {
      setState(() {
        _visibleTodos = _removeTodo(_visibleTodos, todo);
        _hasLoadedTodos = true;
      });
      await widget.repository.delete(todo.id);
      if (!mounted) return;
      setState(_reload);
      return;
    }

    setState(() {
      _visibleTodos = _replaceTodoCompletion(_visibleTodos, todo, completed);
      _hasLoadedTodos = true;
    });
    await widget.repository.setCompleted(todo.id, completed);
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _deleteTodo(TodoItem todo) async {
    setState(() {
      _visibleTodos = _removeTodo(_visibleTodos, todo);
      _hasLoadedTodos = true;
    });
    await widget.repository.delete(todo.id);
    if (!mounted) return;
    setState(_reload);
  }

  List<TodoItem> _removeTodo(List<TodoItem> todos, TodoItem deletedTodo) {
    return todos.where((todo) => todo.id != deletedTodo.id).toList();
  }

  List<TodoItem> _replaceTodoCompletion(
    List<TodoItem> todos,
    TodoItem changedTodo,
    bool completed,
  ) {
    if (todos.isEmpty) {
      return [_todoWithCompletion(changedTodo, completed)];
    }
    var found = false;
    final updatedTodos = todos.map((todo) {
      if (todo.id != changedTodo.id) return todo;
      found = true;
      return _todoWithCompletion(todo, completed);
    }).toList();
    return found ? updatedTodos : todos;
  }

  TodoItem _todoWithCompletion(TodoItem todo, bool completed) {
    return TodoItem(
      id: todo.id,
      title: todo.title,
      dueDate: todo.dueDate,
      priority: todo.priority,
      completed: completed,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const MoodPageTitle('待办'),
        const SizedBox(height: 16),
        FutureBuilder<List<TodoItem>>(
          future: _todosFuture,
          builder: (context, snapshot) {
            final todos = _hasLoadedTodos
                ? _visibleTodos
                : snapshot.data ?? const <TodoItem>[];
            if (!_hasLoadedTodos &&
                snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return TodosListContent(
              todos: todos,
              onCreateTodo: (dueDate) => _createTodo(dueDate: dueDate),
              onEditTodo: (todo) => _createTodo(todo: todo),
              onCompletedChanged: _setCompleted,
              onDeleteTodo: _deleteTodo,
            );
          },
        ),
      ],
    );
  }
}

class TodosListContent extends StatefulWidget {
  const TodosListContent({
    super.key,
    required this.todos,
    required this.onCreateTodo,
    required this.onEditTodo,
    required this.onCompletedChanged,
    this.onDeleteTodo,
    this.referenceDate,
  });

  final List<TodoItem> todos;
  final ValueChanged<DateTime> onCreateTodo;
  final ValueChanged<TodoItem> onEditTodo;
  final void Function(TodoItem todo, bool completed) onCompletedChanged;
  final ValueChanged<TodoItem>? onDeleteTodo;
  final DateTime? referenceDate;

  @override
  State<TodosListContent> createState() => _TodosListContentState();
}

class _TodosListContentState extends State<TodosListContent> {
  final Map<String, bool> _expandedByDateKey = {};

  @override
  Widget build(BuildContext context) {
    final referenceDate = _dateOnly(widget.referenceDate ?? DateTime.now());
    final groups = _groupTodosByDate(widget.todos, referenceDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.todos.isEmpty) ...[
          const Card(
            child: ListTile(title: Text('暂无待办'), subtitle: Text('点击下方按钮添加待办')),
          ),
          const SizedBox(height: 12),
          _buildAddButton(referenceDate),
        ] else
          ...groups.map((group) => _buildDateGroup(group, referenceDate)),
      ],
    );
  }

  Widget _buildDateGroup(_TodoDateGroup group, DateTime referenceDate) {
    final dateKey = _dateKey(group.date);
    final expanded = _expandedValue(dateKey, group.date, referenceDate);
    final canCreateInGroup = !group.date.isBefore(referenceDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_formatGroupTitle(group.date, referenceDate)),
          trailing: Icon(expanded ? Icons.expand_less : Icons.expand_more),
          onTap: () => setState(() {
            _setExpandedValue(dateKey, !expanded);
          }),
        ),
        if (expanded) ...[
          ...group.todos.map(_buildTodoTile),
          if (canCreateInGroup) ...[
            const SizedBox(height: 12),
            _buildAddButton(group.date),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  Widget _buildAddButton(DateTime dueDate) {
    return FilledButton.icon(
      key: ValueKey('todo-add-${_dateKey(dueDate)}'),
      onPressed: () => widget.onCreateTodo(dueDate),
      icon: const Icon(Icons.add_task),
      label: const Text('添加待办'),
    );
  }

  Widget _buildTodoTile(TodoItem todo) {
    return Card(
      child: CheckboxListTile(
        value: todo.completed,
        onChanged: (value) => widget.onCompletedChanged(todo, value ?? false),
        title: Text(todo.title),
        subtitle: Text('${_formatDate(todo.dueDate)} · 优先级 ${todo.priority}'),
        secondary: _buildTodoActions(todo),
      ),
    );
  }

  Widget _buildTodoActions(TodoItem todo) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '编辑',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => widget.onEditTodo(todo),
        ),
        SizedBox(
          width: 48,
          height: 48,
          child: todo.completed && widget.onDeleteTodo != null
              ? IconButton(
                  tooltip: '删除待办',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => widget.onDeleteTodo!(todo),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  bool _expandedValue(
    String dateKey,
    DateTime groupDate,
    DateTime referenceDate,
  ) {
    final storedValue = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: dateKey);
    if (storedValue is bool) {
      _expandedByDateKey[dateKey] = storedValue;
      return storedValue;
    }
    return _expandedByDateKey.putIfAbsent(
      dateKey,
      () => _isSameDate(groupDate, referenceDate),
    );
  }

  void _setExpandedValue(String dateKey, bool expanded) {
    _expandedByDateKey[dateKey] = expanded;
    PageStorage.maybeOf(
      context,
    )?.writeState(context, expanded, identifier: dateKey);
  }

  List<_TodoDateGroup> _groupTodosByDate(
    List<TodoItem> todos,
    DateTime referenceDate,
  ) {
    final grouped = <String, _TodoDateGroup>{};
    for (final todo in todos) {
      final date = _dateOnly(todo.dueDate);
      final dateKey = _dateKey(date);
      final group = grouped.putIfAbsent(
        dateKey,
        () => _TodoDateGroup(date: date, todos: []),
      );
      group.todos.add(todo);
    }
    if (todos.isNotEmpty) {
      grouped.putIfAbsent(
        _dateKey(referenceDate),
        () => _TodoDateGroup(date: referenceDate, todos: []),
      );
    }

    final groups = grouped.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return groups;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _dateKey(DateTime value) {
    final date = _dateOnly(value);
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatGroupTitle(DateTime value, DateTime referenceDate) {
    if (_isSameDate(value, referenceDate)) return '今天';
    final tomorrow = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day + 1,
    );
    if (_isSameDate(value, tomorrow)) {
      return '明天';
    }
    return '${value.year}年${value.month}月${value.day}日';
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}

class _TodoDateGroup {
  _TodoDateGroup({required this.date, required this.todos});

  final DateTime date;
  final List<TodoItem> todos;
}

class _TodoDialog extends StatefulWidget {
  const _TodoDialog({this.todo, this.initialDueDate});

  final TodoItem? todo;
  final DateTime? initialDueDate;

  @override
  State<_TodoDialog> createState() => _TodoDialogState();
}

class _TodoDialogState extends State<_TodoDialog> {
  final _controller = TextEditingController();
  late DateTime _dueDate;
  late int _priority;

  @override
  void initState() {
    super.initState();
    final todo = widget.todo;
    _controller.text = todo?.title ?? '';
    _dueDate = todo?.dueDate ?? widget.initialDueDate ?? DateTime.now();
    _priority = todo?.priority ?? 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.todo == null ? '添加待办' : '编辑待办'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(labelText: '待办内容'),
            autofocus: true,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('日期'),
            subtitle: Text(_formatDate(_dueDate)),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _dueDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _dueDate = picked);
            },
          ),
          DropdownButtonFormField<int>(
            initialValue: _priority,
            decoration: const InputDecoration(labelText: '优先级'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('普通')),
              DropdownMenuItem(value: 1, child: Text('重要')),
              DropdownMenuItem(value: 2, child: Text('紧急')),
            ],
            onChanged: (value) => setState(() => _priority = value ?? 0),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _TodoDraft(
              title: _controller.text,
              dueDate: _dueDate,
              priority: _priority,
            ),
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }

  String _formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }
}

class _TodoDraft {
  const _TodoDraft({
    required this.title,
    required this.dueDate,
    required this.priority,
  });

  final String title;
  final DateTime dueDate;
  final int priority;
}

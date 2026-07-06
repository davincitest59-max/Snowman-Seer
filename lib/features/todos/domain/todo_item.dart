class TodoItem {
  const TodoItem({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.priority,
    required this.completed,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final DateTime dueDate;
  final int priority;
  final bool completed;
  final DateTime updatedAt;
}

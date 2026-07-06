import 'package:flutter/material.dart';

import '../data/mood_repository.dart';
import '../domain/mood_entry.dart';
import '../services/mood_prompt_service.dart';
import 'mood_page_title.dart';
import 'mood_prompt_dialog.dart';
import 'mood_visuals.dart';

class MoodPage extends StatefulWidget {
  const MoodPage({
    super.key,
    required this.repository,
    required this.promptService,
    required this.onMoodChanged,
  });

  final MoodRepository repository;
  final MoodPromptService promptService;
  final VoidCallback onMoodChanged;

  @override
  State<MoodPage> createState() => _MoodPageState();
}

class _MoodPageState extends State<MoodPage> {
  late Future<MoodEntry?> _entryFuture;
  late Future<List<MoodEntry>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _entryFuture = widget.repository.getByDay(DateTime.now());
    _historyFuture = widget.repository.listHistory();
  }

  Future<void> _pickMood({bool fromPrompt = false}) async {
    final result = await showDialog<MoodPromptResult>(
      context: context,
      builder: (_) => const MoodPromptDialog(),
    );
    if (result == null) return;

    final now = DateTime.now();
    if (fromPrompt) {
      await widget.promptService.saveFromPrompt(
        now,
        result.mood,
        note: result.note,
      );
    } else {
      await widget.promptService.updateTodayMood(
        now,
        result.mood,
        note: result.note,
      );
    }
    if (!mounted) return;
    widget.onMoodChanged();
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const MoodPageTitle('心情'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _pickMood,
          icon: const Icon(Icons.mood),
          label: const Text('记录今日心情'),
        ),
        const SizedBox(height: 16),
        FutureBuilder<MoodEntry?>(
          future: _entryFuture,
          builder: (context, snapshot) {
            final entry = snapshot.data;
            return Card(
              child: ListTile(
                title: const Text('今日心情'),
                subtitle: Text(
                  entry == null ? '尚未记录' : _moodSummary(entry.mood, entry.note),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<MoodEntry>>(
          future: _historyFuture,
          builder: (context, snapshot) {
            return MoodHistoryList(entries: snapshot.data ?? const []);
          },
        ),
      ],
    );
  }
}

class MoodHistoryList extends StatelessWidget {
  const MoodHistoryList({super.key, required this.entries});

  final List<MoodEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Card(
        child: ListTile(title: Text('历史心情'), subtitle: Text('暂无历史心情记录')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '历史心情',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...entries.indexed.map((entry) {
          final (index, moodEntry) = entry;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Container(
                key: ValueKey('mood-history-dot-$index'),
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: moodColor(moodEntry.mood),
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(_formatDate(moodEntry.day)),
              subtitle: Text(_moodSummary(moodEntry.mood, moodEntry.note)),
            ),
          );
        }),
      ],
    );
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

String _moodSummary(MoodType mood, String note) {
  final label = moodLabel(mood);
  return note.isEmpty ? label : '$label · $note';
}

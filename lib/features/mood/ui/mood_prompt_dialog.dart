import 'package:flutter/material.dart';

import '../domain/mood_entry.dart';

class MoodPromptResult {
  const MoodPromptResult({required this.mood, required this.note});

  final MoodType mood;
  final String note;
}

class MoodPromptDialog extends StatefulWidget {
  const MoodPromptDialog({super.key});

  @override
  State<MoodPromptDialog> createState() => _MoodPromptDialogState();
}

class _MoodPromptDialogState extends State<MoodPromptDialog> {
  final _noteController = TextEditingController();
  MoodType? _selectedMood;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedMood = _selectedMood;

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
                label: '开心',
                color: Colors.green,
                selected: selectedMood == MoodType.happy,
                onSelected: _selectMood,
              ),
              _MoodChoice(
                mood: MoodType.angry,
                label: '生气',
                color: Colors.red,
                selected: selectedMood == MoodType.angry,
                onSelected: _selectMood,
              ),
              _MoodChoice(
                mood: MoodType.sad,
                label: '伤心',
                color: Colors.black,
                selected: selectedMood == MoodType.sad,
                onSelected: _selectMood,
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
        TextButton(
          onPressed: selectedMood == null
              ? null
              : () => Navigator.of(context).pop(
                  MoodPromptResult(
                    mood: selectedMood,
                    note: _noteController.text.trim(),
                  ),
                ),
          child: const Text('确定'),
        ),
      ],
    );
  }

  void _selectMood(MoodType mood) {
    setState(() {
      _selectedMood = mood;
    });
  }
}

class _MoodChoice extends StatelessWidget {
  const _MoodChoice({
    required this.mood,
    required this.label,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final MoodType mood;
  final String label;
  final Color color;
  final bool selected;
  final ValueChanged<MoodType> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      avatar: CircleAvatar(backgroundColor: color),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(mood),
    );
  }
}

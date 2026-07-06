import 'package:flutter/material.dart';
import 'package:ocean_baby/app/app_theme.dart';
import 'package:ocean_baby/features/mood/data/mood_repository.dart';
import 'package:ocean_baby/features/mood/services/mood_prompt_service.dart';
import 'package:ocean_baby/features/mood/ui/mood_prompt_dialog.dart';
import 'package:ocean_baby/features/mood/ui/mood_visuals.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.moodRepository,
    required this.promptService,
    required this.onThemeChanged,
  });

  final MoodRepository moodRepository;
  final MoodPromptService promptService;
  final ValueChanged<OceanTheme> onThemeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<bool> _promptEnabledFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _promptEnabledFuture = widget.moodRepository.getPromptEnabled();
  }

  Future<void> _setPromptEnabled(bool enabled) async {
    await widget.promptService.setPromptEnabled(enabled);
    if (!mounted) return;
    setState(_reload);
  }

  Future<void> _previewMoodPrompt() async {
    final result = await showDialog<MoodPromptResult>(
      context: context,
      builder: (_) => const MoodPromptDialog(),
    );
    if (result == null) return;
    await widget.promptService.updateTodayMood(
      DateTime.now(),
      result.mood,
      note: result.note,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('今日心情已更新为${moodLabel(result.mood)}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          '设置',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        Text('主题预览', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: OceanTheme.values
              .map(
                (theme) => _ThemePreview(
                  theme: theme,
                  onSelected: () => widget.onThemeChanged(theme),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        FutureBuilder<bool>(
          future: _promptEnabledFuture,
          builder: (context, snapshot) {
            final enabled = snapshot.data ?? true;
            return Card(
              child: SwitchListTile(
                value: enabled,
                onChanged: _setPromptEnabled,
                title: const Text('心情弹框'),
                subtitle: const Text('每日打开应用时提醒记录心情'),
              ),
            );
          },
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.mood_outlined),
            title: const Text('预览心情弹框'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _previewMoodPrompt,
          ),
        ),
      ],
    );
  }
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.theme, required this.onSelected});

  final OceanTheme theme;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: CircleAvatar(backgroundColor: theme.seedColor),
      label: Text(theme.label),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      onPressed: onSelected,
    );
  }
}

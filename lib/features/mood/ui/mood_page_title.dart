import 'package:flutter/material.dart';

import '../data/mood_repository.dart';
import '../domain/mood_entry.dart';
import 'mood_visuals.dart';

class MoodScope extends InheritedWidget {
  const MoodScope({
    super.key,
    required this.repository,
    required this.revision,
    required this.onMoodTap,
    required super.child,
  });

  final MoodRepository repository;
  final int revision;
  final VoidCallback onMoodTap;

  static MoodScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MoodScope>();
  }

  @override
  bool updateShouldNotify(MoodScope oldWidget) {
    return repository != oldWidget.repository ||
        revision != oldWidget.revision ||
        onMoodTap != oldWidget.onMoodTap;
  }
}

class MoodPageTitle extends StatelessWidget {
  const MoodPageTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scope = MoodScope.maybeOf(context);
    if (scope == null) {
      return MoodTitleView(title: title, mood: null, onTap: () {});
    }

    return FutureBuilder<MoodEntry?>(
      key: ValueKey('${title}_${scope.revision}'),
      future: scope.repository.getByDay(DateTime.now()),
      builder: (context, snapshot) {
        return FutureBuilder<MoodTitleDisplayOptions>(
          future: scope.repository.getTitleDisplayOptions(),
          builder: (context, optionsSnapshot) {
            final entry = snapshot.data;
            final options =
                optionsSnapshot.data ??
                const MoodTitleDisplayOptions.defaults();
            return MoodTitleView(
              title: title,
              mood: entry?.mood,
              note: entry?.note ?? '',
              showMoodDot: options.showDot,
              showMoodText: options.showText,
              showMoodNote: options.showNote,
              onTap: scope.onMoodTap,
            );
          },
        );
      },
    );
  }
}

class MoodTitleView extends StatelessWidget {
  const MoodTitleView({
    super.key,
    required this.title,
    required this.mood,
    required this.onTap,
    this.note = '',
    this.showMoodDot = true,
    this.showMoodText = true,
    this.showMoodNote = true,
  });

  final String title;
  final MoodType? mood;
  final VoidCallback onTap;
  final String note;
  final bool showMoodDot;
  final bool showMoodText;
  final bool showMoodNote;

  @override
  Widget build(BuildContext context) {
    final moodText = mood == null ? '未记录' : moodLabel(mood!);
    final trimmedNote = note.trim();
    final noteVisible = showMoodNote && trimmedNote.isNotEmpty;
    final label = noteVisible
        ? '今日心情：$moodText，$trimmedNote'
        : '今日心情：$moodText';
    final hasMoodInfo = showMoodDot || showMoodText || noteVisible;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          if (hasMoodInfo) ...[
            const SizedBox(width: 10),
            Tooltip(
              message: label,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showMoodDot) ...[
                    Container(
                      key: const ValueKey('mood-title-dot'),
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: moodColor(mood),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (showMoodText)
                    Text(
                      moodText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (showMoodText && noteVisible) const SizedBox(width: 8),
                  if (noteVisible)
                    Flexible(
                      child: Text(
                        trimmedNote,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum MoodType { happy, angry, sad }

class MoodEntry {
  const MoodEntry({
    required this.day,
    required this.mood,
    required this.promptShown,
    required this.updatedAt,
    this.note = '',
  });

  final DateTime day;
  final MoodType mood;
  final bool promptShown;
  final DateTime updatedAt;
  final String note;
}

class MoodTitleDisplayOptions {
  const MoodTitleDisplayOptions({
    required this.showDot,
    required this.showText,
    required this.showNote,
  });

  const MoodTitleDisplayOptions.defaults()
    : showDot = true,
      showText = true,
      showNote = true;

  final bool showDot;
  final bool showText;
  final bool showNote;
}

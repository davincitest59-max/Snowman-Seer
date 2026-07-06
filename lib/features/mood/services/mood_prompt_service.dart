import '../data/mood_repository.dart';
import '../domain/mood_entry.dart';

class MoodPromptService {
  const MoodPromptService(this._repository);

  final MoodRepository _repository;

  Future<bool> shouldShowPrompt(DateTime now) async {
    final promptEnabled = await _repository.getPromptEnabled();
    if (!promptEnabled) {
      return false;
    }

    final entry = await _repository.getByDay(now);
    return entry == null || !entry.promptShown;
  }

  Future<void> saveFromPrompt(
    DateTime now,
    MoodType mood, {
    String note = '',
  }) async {
    await _repository.save(
      MoodEntry(
        day: _dateOnly(now),
        mood: mood,
        promptShown: true,
        updatedAt: now,
        note: note,
      ),
    );
  }

  Future<void> updateTodayMood(
    DateTime now,
    MoodType mood, {
    String note = '',
  }) async {
    final existing = await _repository.getByDay(now);
    await _repository.save(
      MoodEntry(
        day: _dateOnly(now),
        mood: mood,
        promptShown: existing?.promptShown ?? false,
        updatedAt: now,
        note: note,
      ),
    );
  }

  Future<void> setPromptEnabled(bool enabled) {
    return _repository.setPromptEnabled(enabled);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

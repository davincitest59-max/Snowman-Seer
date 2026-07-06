import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/core/database/app_database.dart';
import 'package:ocean_baby/features/mood/data/mood_repository.dart';
import 'package:ocean_baby/features/mood/domain/mood_entry.dart';
import 'package:ocean_baby/features/mood/services/mood_prompt_service.dart';

void main() {
  test('每天首次打开需要弹框，弹框保存后当天不再自动弹出', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = MoodRepository(db);
    final service = MoodPromptService(repo);
    final now = DateTime(2026, 7, 5, 9, 30);

    expect(await service.shouldShowPrompt(now), isTrue);

    await service.saveFromPrompt(now, MoodType.happy);

    expect(await service.shouldShowPrompt(now), isFalse);
  });

  test('当天心情可以随时修改，且修改后当天仍不再自动弹出', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = MoodRepository(db);
    final service = MoodPromptService(repo);
    final now = DateTime(2026, 7, 5, 9, 30);

    await service.saveFromPrompt(now, MoodType.sad);
    await service.updateTodayMood(now, MoodType.happy);

    final entry = await repo.getByDay(now);
    expect(entry?.mood, MoodType.happy);
    expect(await service.shouldShowPrompt(now), isFalse);
  });

  test('今日心情可以保存备注解释并在修改心情时更新备注', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = MoodRepository(db);
    final service = MoodPromptService(repo);
    final now = DateTime(2026, 7, 5, 9, 30);

    await service.saveFromPrompt(now, MoodType.happy, note: '项目推进顺利');

    var entry = await repo.getByDay(now);
    expect(entry?.note, '项目推进顺利');

    await service.updateTodayMood(now, MoodType.angry, note: '临时会议太多');

    entry = await repo.getByDay(now);
    expect(entry?.mood, MoodType.angry);
    expect(entry?.note, '临时会议太多');
  });

  test('关闭自动弹框后不再自动弹出，但仍可手动创建或修改当天心情', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = MoodRepository(db);
    final service = MoodPromptService(repo);
    final now = DateTime(2026, 7, 5, 9, 30);

    await service.setPromptEnabled(false);

    expect(await service.shouldShowPrompt(now), isFalse);

    await service.updateTodayMood(now, MoodType.sad);
    expect((await repo.getByDay(now))?.mood, MoodType.sad);

    await service.updateTodayMood(now, MoodType.happy);
    final entry = await repo.getByDay(now);
    expect(entry?.mood, MoodType.happy);
    expect(entry?.promptShown, isFalse);
  });

  test('可以按日期倒序读取历史心情', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = MoodRepository(db);

    await repo.save(
      MoodEntry(
        day: DateTime(2026, 7, 4),
        mood: MoodType.angry,
        promptShown: true,
        updatedAt: DateTime(2026, 7, 4, 9),
      ),
    );
    await repo.save(
      MoodEntry(
        day: DateTime(2026, 7, 6),
        mood: MoodType.happy,
        promptShown: true,
        updatedAt: DateTime(2026, 7, 6, 9),
      ),
    );
    await repo.save(
      MoodEntry(
        day: DateTime(2026, 7, 5),
        mood: MoodType.sad,
        promptShown: true,
        updatedAt: DateTime(2026, 7, 5, 9),
      ),
    );

    final history = await repo.listHistory();

    expect(history.map((entry) => entry.day), [
      DateTime(2026, 7, 6),
      DateTime(2026, 7, 5),
      DateTime(2026, 7, 4),
    ]);
    expect(history.map((entry) => entry.mood), [
      MoodType.happy,
      MoodType.sad,
      MoodType.angry,
    ]);
  });

  test('心情标题显示项默认开启且可以分别关闭', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final repo = MoodRepository(db);

    var options = await repo.getTitleDisplayOptions();
    expect(options.showDot, isTrue);
    expect(options.showText, isTrue);
    expect(options.showNote, isTrue);

    await repo.setShowMoodDot(false);
    await repo.setShowMoodText(false);
    await repo.setShowMoodNote(false);

    options = await repo.getTitleDisplayOptions();
    expect(options.showDot, isFalse);
    expect(options.showText, isFalse);
    expect(options.showNote, isFalse);
  });
}

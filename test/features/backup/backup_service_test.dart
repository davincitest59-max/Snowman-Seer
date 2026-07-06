import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/core/database/app_database.dart';
import 'package:ocean_baby/features/backup/data/backup_models.dart';
import 'package:ocean_baby/features/backup/data/backup_service.dart';

void main() {
  test('导出文件包含清单、数据和笔记图片', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final tempDir = await Directory.systemTemp.createTemp('ocean_baby_backup_');
    addTearDown(() => tempDir.delete(recursive: true));
    final imageFile = File('${tempDir.path}${Platform.pathSeparator}note.png');
    await imageFile.writeAsBytes([1, 2, 3, 4]);
    await _seedCompleteData(db, imageFile.path);

    final service = BackupService(db, now: () => DateTime(2026, 7, 7, 9, 30));

    final result = await service.createBackup();
    final archive = ZipDecoder().decodeBytes(result.bytes);
    final names = archive.files.map((file) => file.name).toSet();
    final manifest = _jsonFile(archive, 'manifest.json');
    final data = _jsonFile(archive, 'data.json');
    final notes = data['notes'] as List<Object?>;
    final exportedNote = notes.single as Map<String, Object?>;

    expect(result.fileName, 'OceanBaby_20260707_093000.oceanbaby');
    expect(names, containsAll(['manifest.json', 'data.json', 'note_images/']));
    expect(
      names.where((name) => name.startsWith('note_images/note_')),
      isNotEmpty,
    );
    expect(manifest['appName'], 'Ocean Baby');
    expect(manifest['backupFormatVersion'], 1);
    expect(data['ledgerRecords'], isNotEmpty);
    expect(data['notes'], isNotEmpty);
    expect(data['todos'], isNotEmpty);
    expect(data['moods'], isNotEmpty);
    expect(data['settings'], isNotEmpty);
    expect(exportedNote['image_paths'], isNotEmpty);
  });

  test('导出时图片缺失仍保留笔记文字并返回缺失列表', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final missingPath = '${Directory.systemTemp.path}/missing-note-image.png';
    await db.db.insert('notes', {
      'title': '宝宝第一次看海',
      'content': '风很轻，浪很蓝。',
      'folder': '成长记录',
      'pinned': 0,
      'image_path': missingPath,
      'updated_at': DateTime(2026, 7, 7, 9).toIso8601String(),
    });

    final service = BackupService(db, now: () => DateTime(2026, 7, 7, 9, 30));

    final result = await service.createBackup();
    final archive = ZipDecoder().decodeBytes(result.bytes);
    final data = _jsonFile(archive, 'data.json');
    final notes = data['notes'] as List<Object?>;
    final exportedNote = notes.single as Map<String, Object?>;

    expect(result.missingImagePaths, [missingPath]);
    expect(exportedNote['title'], '宝宝第一次看海');
    expect(exportedNote['image_paths'], isEmpty);
  });

  test('导入备份会覆盖旧数据并重建笔记图片路径', () async {
    final sourceDb = await AppDatabase.openInMemory();
    final targetDb = await AppDatabase.openInMemory();
    addTearDown(sourceDb.close);
    addTearDown(targetDb.close);
    final tempDir = await Directory.systemTemp.createTemp(
      'ocean_baby_restore_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final sourceImage = File(
      '${tempDir.path}${Platform.pathSeparator}source_note.png',
    );
    final imageBytes = [9, 8, 7, 6];
    await sourceImage.writeAsBytes(imageBytes);
    await _seedCompleteData(sourceDb, sourceImage.path);
    final sourceService = BackupService(
      sourceDb,
      now: () => DateTime(2026, 7, 7, 10),
    );
    final backup = await sourceService.createBackup();
    await _seedOldData(targetDb);
    final targetDocs = Directory(
      '${tempDir.path}${Platform.pathSeparator}target_docs',
    );
    final targetService = BackupService(
      targetDb,
      documentsDirectoryProvider: () async => targetDocs,
    );

    final result = await targetService.restoreFromBytes(backup.bytes);
    final notes = await targetDb.db.query('notes');
    final note = notes.single;
    final restoredImagePath = note['image_path']! as String;

    expect(result.ledgerCount, 1);
    expect(result.noteCount, 1);
    expect(result.todoCount, 1);
    expect(result.moodCount, 1);
    expect(result.settingCount, 1);
    expect(note['title'], '宝宝第一次看海');
    expect(restoredImagePath, isNot(sourceImage.path));
    expect(restoredImagePath, contains('note_images'));
    expect(await File(restoredImagePath).readAsBytes(), imageBytes);
    expect(await targetDb.db.query('ledger_records'), hasLength(1));
    expect(await targetDb.db.query('todos'), hasLength(1));
    expect(await targetDb.db.query('moods'), hasLength(1));
    expect(await targetDb.db.query('settings'), hasLength(1));
    expect(
      await targetDb.db.query('notes', where: 'title = ?', whereArgs: ['旧笔记']),
      isEmpty,
    );
  });

  test('非 Ocean Baby 备份文件会返回中文错误', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final service = BackupService(db);

    expect(
      () => service.restoreFromBytes(utf8.encode('不是备份文件')),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('备份文件损坏'),
        ),
      ),
    );
  });

  test('备份引用缺失图片时导入失败且旧数据保留', () async {
    final targetDb = await AppDatabase.openInMemory();
    addTearDown(targetDb.close);
    final tempDir = await Directory.systemTemp.createTemp(
      'ocean_baby_missing_image_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    await _seedOldData(targetDb);
    final service = BackupService(
      targetDb,
      documentsDirectoryProvider: () async => tempDir,
    );
    final backupBytes = _backupBytes(
      data: _baseImportData(
        notes: [
          _noteRow(imagePaths: ['note_images/missing.png']),
        ],
      ),
    );

    await expectLater(
      service.restoreFromBytes(backupBytes),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('备份文件损坏'),
        ),
      ),
    );
    final notes = await targetDb.db.query('notes');

    expect(notes, hasLength(1));
    expect(notes.single['title'], '旧笔记');
  });

  test('导入失败不会覆盖旧图片文件', () async {
    final targetDb = await AppDatabase.openInMemory();
    addTearDown(targetDb.close);
    final tempDir = await Directory.systemTemp.createTemp(
      'ocean_baby_restore_failure_',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final targetDocs = Directory(
      '${tempDir.path}${Platform.pathSeparator}target_docs',
    );
    final noteImagesDir = Directory(
      '${targetDocs.path}${Platform.pathSeparator}note_images',
    );
    await noteImagesDir.create(recursive: true);
    final oldImage = File(
      '${noteImagesDir.path}${Platform.pathSeparator}note_1_0.png',
    );
    await oldImage.writeAsBytes([5, 5, 5]);
    await _seedOldData(targetDb, imagePath: oldImage.path);
    final service = BackupService(
      targetDb,
      documentsDirectoryProvider: () async => targetDocs,
    );
    final backupBytes = _backupBytes(
      data: _baseImportData(
        notes: [
          _noteRow(imagePaths: ['note_images/note_1_0.png']),
        ],
        moods: [_moodRow(), _moodRow()],
      ),
      imageFiles: {
        'note_images/note_1_0.png': [9, 9, 9],
      },
    );

    await expectLater(
      service.restoreFromBytes(backupBytes),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('导入失败'),
        ),
      ),
    );
    final notes = await targetDb.db.query('notes');

    expect(await oldImage.readAsBytes(), [5, 5, 5]);
    expect(notes, hasLength(1));
    expect(notes.single['title'], '旧笔记');
  });
}

Future<void> _seedCompleteData(AppDatabase db, String imagePath) async {
  await db.db.insert('ledger_records', {
    'source': 'wechat',
    'origin': 'notification',
    'occurred_at': DateTime(2026, 7, 7, 8).toIso8601String(),
    'amount_cents': 1280,
    'amount': 12.8,
    'direction': 'expense',
    'counterparty': '早餐店',
    'description': '早餐',
    'payment_method': '零钱',
    'original_category': '餐饮',
    'user_category': '宝宝日常',
    'note': '豆浆和包子',
    'import_batch_id': '测试导入',
    'confirmation_status': 'confirmed',
    'fingerprint': 'backup-test-ledger',
    'updated_at': DateTime(2026, 7, 7, 8, 5).toIso8601String(),
  });
  await db.db.insert('notes', {
    'title': '宝宝第一次看海',
    'content': '风很轻，浪很蓝。',
    'folder': '成长记录',
    'pinned': 1,
    'image_path': jsonEncode([imagePath]),
    'updated_at': DateTime(2026, 7, 7, 9).toIso8601String(),
  });
  await db.db.insert('todos', {
    'title': '准备防晒帽',
    'due_date': DateTime(2026, 7, 8).toIso8601String(),
    'priority': 2,
    'completed': 0,
    'updated_at': DateTime(2026, 7, 7, 9, 5).toIso8601String(),
  });
  await db.db.insert('moods', {
    'day': DateTime(2026, 7, 7).toIso8601String(),
    'mood': 'happy',
    'prompt_shown': 1,
    'note': '今天很开心',
    'updated_at': DateTime(2026, 7, 7, 9, 10).toIso8601String(),
  });
  await db.db.insert('settings', {
    'key': 'mood_prompt_enabled',
    'value': 'true',
  });
}

Future<void> _seedOldData(AppDatabase db, {String imagePath = ''}) async {
  await db.db.insert('ledger_records', {
    'source': 'manual',
    'origin': 'old',
    'occurred_at': DateTime(2026, 7, 6, 8).toIso8601String(),
    'amount_cents': 100,
    'amount': 1.0,
    'direction': 'expense',
    'counterparty': '旧商店',
    'description': '旧账单',
    'payment_method': '现金',
    'original_category': '旧分类',
    'user_category': '旧分类',
    'note': '旧记录',
    'import_batch_id': '旧批次',
    'confirmation_status': 'pending',
    'fingerprint': 'old-ledger',
    'updated_at': DateTime(2026, 7, 6, 8, 5).toIso8601String(),
  });
  await db.db.insert('notes', {
    'title': '旧笔记',
    'content': '旧内容',
    'folder': '旧文件夹',
    'pinned': 0,
    'image_path': imagePath,
    'updated_at': DateTime(2026, 7, 6, 9).toIso8601String(),
  });
  await db.db.insert('todos', {
    'title': '旧待办',
    'due_date': DateTime(2026, 7, 6).toIso8601String(),
    'priority': 1,
    'completed': 0,
    'updated_at': DateTime(2026, 7, 6, 9, 5).toIso8601String(),
  });
  await db.db.insert('moods', {
    'day': DateTime(2026, 7, 6).toIso8601String(),
    'mood': 'sad',
    'prompt_shown': 0,
    'note': '旧心情',
    'updated_at': DateTime(2026, 7, 6, 9, 10).toIso8601String(),
  });
  await db.db.insert('settings', {'key': 'old_setting', 'value': 'old'});
}

List<int> _backupBytes({
  required Map<String, Object?> data,
  Map<String, List<int>> imageFiles = const {},
}) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('manifest.json', jsonEncode(_manifest())))
    ..addFile(ArchiveFile.string('data.json', jsonEncode(data)))
    ..addFile(ArchiveFile('note_images/', 0, const <int>[]));
  for (final entry in imageFiles.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return ZipEncoder().encode(archive)!;
}

Map<String, Object?> _manifest() {
  return {
    'appName': oceanBabyBackupAppName,
    'backupFormatVersion': oceanBabyBackupFormatVersion,
    'databaseSchemaVersion': AppDatabase.schemaVersion,
    'exportedAt': DateTime(2026, 7, 7, 11).toIso8601String(),
    'platform': Platform.operatingSystem,
  };
}

Map<String, Object?> _baseImportData({
  List<Map<String, Object?>> notes = const [],
  List<Map<String, Object?>> moods = const [],
}) {
  return {
    'ledgerRecords': <Map<String, Object?>>[],
    'notes': notes,
    'todos': <Map<String, Object?>>[],
    'moods': moods,
    'settings': <Map<String, Object?>>[],
  };
}

Map<String, Object?> _noteRow({required List<String> imagePaths}) {
  return {
    'id': 1,
    'title': '导入笔记',
    'content': '导入内容',
    'folder': '成长记录',
    'pinned': 0,
    'updated_at': DateTime(2026, 7, 7, 11).toIso8601String(),
    'image_paths': imagePaths,
  };
}

Map<String, Object?> _moodRow() {
  return {
    'id': 1,
    'day': DateTime(2026, 7, 7).toIso8601String(),
    'mood': 'happy',
    'prompt_shown': 1,
    'note': '导入心情',
    'updated_at': DateTime(2026, 7, 7, 11).toIso8601String(),
  };
}

Map<String, Object?> _jsonFile(Archive archive, String name) {
  final file = archive.files.singleWhere((entry) => entry.name == name);
  return jsonDecode(utf8.decode(file.content as List<int>))
      as Map<String, Object?>;
}

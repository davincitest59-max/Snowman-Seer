# 数据备份与恢复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Ocean Baby 安卓端增加 `.oceanbaby` 单文件导出与覆盖恢复能力，恢复账本、笔记、图片、待办、心情和设置。

**Architecture:** 新增 `features/backup` 模块，把压缩包格式、JSON 转换、图片路径重建和覆盖恢复集中在一个服务中。设置页只负责调用服务、选择保存/导入文件、显示中文确认与结果提示；应用壳层负责在恢复后刷新页面状态。

**Tech Stack:** Flutter、Dart、sqflite、archive ZIP、file_picker、path_provider、flutter_test。

---

## File Structure

- Create: `lib/features/backup/data/backup_models.dart`
  - 负责备份格式常量、导出结果、导入结果和中文异常。
- Create: `lib/features/backup/data/backup_service.dart`
  - 负责读取 SQLite、生成 `.oceanbaby` ZIP、解析 ZIP、复制笔记图片、事务式覆盖恢复。
- Create: `test/features/backup/backup_service_test.dart`
  - 覆盖导出结构、恢复一致性、覆盖旧数据、图片路径重建、非法文件错误。
- Modify: `pubspec.yaml`
  - 将 `archive` 加为直接依赖，避免引用传递依赖触发分析警告。
- Modify: `lib/features/home/ui/home_page.dart`
  - 在设置页增加“数据备份与恢复”折叠分类，并接入导出/导入交互。
- Modify: `lib/app/ocean_baby_app.dart`
  - 创建 `BackupService`，传入设置页；恢复成功后刷新页面树。
- Modify: `test/widget/navigation_and_theme_test.dart`
  - 增加设置页备份分类入口测试。

---

### Task 1: Add Backup Models And Export Tests

**Files:**
- Create: `lib/features/backup/data/backup_models.dart`
- Create: `test/features/backup/backup_service_test.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Add direct archive dependency**

Modify `pubspec.yaml` dependencies so `archive` is direct:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  archive: ^3.6.1
  collection: ^1.18.0
```

- [ ] **Step 2: Run pub get**

Run:

```powershell
flutter pub get
```

Expected: dependency resolution succeeds and `pubspec.lock` remains consistent.

- [ ] **Step 3: Write failing export tests**

Create `test/features/backup/backup_service_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/core/database/app_database.dart';
import 'package:ocean_baby/features/backup/data/backup_models.dart';
import 'package:ocean_baby/features/backup/data/backup_service.dart';
import 'package:ocean_baby/features/ledger/data/ledger_repository.dart';
import 'package:ocean_baby/features/ledger/domain/bill_source.dart';
import 'package:ocean_baby/features/ledger/domain/transaction_record.dart';
import 'package:ocean_baby/features/mood/data/mood_repository.dart';
import 'package:ocean_baby/features/mood/domain/mood_entry.dart';
import 'package:ocean_baby/features/notes/data/notes_repository.dart';
import 'package:ocean_baby/features/todos/data/todos_repository.dart';

void main() {
  test('导出文件包含清单、数据和笔记图片', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final tempDir = await Directory.systemTemp.createTemp('ocean_baby_export_');
    addTearDown(() => tempDir.delete(recursive: true));
    final image = File('${tempDir.path}${Platform.pathSeparator}photo.png');
    await image.writeAsBytes([1, 2, 3, 4]);
    await _seedFullData(db, image.path);

    final service = BackupService(
      db,
      now: () => DateTime(2026, 7, 7, 9, 30),
      documentsDirectoryProvider: () async => Directory('${tempDir.path}${Platform.pathSeparator}docs')..createSync(recursive: true),
    );

    final backup = await service.createBackup();
    final archive = ZipDecoder().decodeBytes(backup.bytes);
    final names = archive.files.map((file) => file.name).toList();

    expect(backup.fileName, 'OceanBaby_20260707_093000.oceanbaby');
    expect(names, contains('manifest.json'));
    expect(names, contains('data.json'));
    expect(names.any((name) => name.startsWith('note_images/')), isTrue);
    expect(backup.missingImagePaths, isEmpty);

    final manifest = _jsonFile(archive, 'manifest.json');
    expect(manifest['appName'], oceanBabyBackupAppName);
    expect(manifest['backupFormatVersion'], oceanBabyBackupFormatVersion);

    final data = _jsonFile(archive, 'data.json');
    expect(data['ledgerRecords'], isNotEmpty);
    expect(data['notes'], isNotEmpty);
    expect(data['todos'], isNotEmpty);
    expect(data['moods'], isNotEmpty);
    expect(data['settings'], isNotEmpty);
    expect((data['notes'] as List).single['image_paths'], isNotEmpty);
  });

  test('导出时图片缺失仍保留笔记文字并返回缺失列表', () async {
    final db = await AppDatabase.openInMemory();
    addTearDown(db.close);
    final tempDir = await Directory.systemTemp.createTemp('ocean_baby_missing_');
    addTearDown(() => tempDir.delete(recursive: true));
    final missingPath = '${tempDir.path}${Platform.pathSeparator}missing.png';
    await NotesRepository(db).create(
      title: '只有文字能恢复',
      content: '图片已经被删除',
      folder: '默认',
      imagePaths: [missingPath],
    );

    final service = BackupService(
      db,
      now: () => DateTime(2026, 7, 7, 9, 30),
      documentsDirectoryProvider: () async => tempDir,
    );

    final backup = await service.createBackup();
    final archive = ZipDecoder().decodeBytes(backup.bytes);
    final data = _jsonFile(archive, 'data.json');

    expect(backup.missingImagePaths, [missingPath]);
    expect((data['notes'] as List).single['title'], '只有文字能恢复');
    expect((data['notes'] as List).single['image_paths'], isEmpty);
  });
}

Future<void> _seedFullData(AppDatabase db, String imagePath) async {
  await LedgerRepository(db).upsert(_record());
  await NotesRepository(db).create(
    title: '旅行照片',
    content: '海边日落',
    folder: '默认',
    imagePaths: [imagePath],
  );
  await TodosRepository(db).create(
    title: '整理账单',
    dueDate: DateTime(2026, 7, 7),
  );
  await MoodRepository(db).save(
    MoodEntry(
      day: DateTime(2026, 7, 7),
      mood: MoodType.happy,
      promptShown: true,
      note: '今天不错',
      updatedAt: DateTime(2026, 7, 7, 9),
    ),
  );
  await MoodRepository(db).setPromptEnabled(false);
}

TransactionRecord _record() {
  return TransactionRecord(
    id: '',
    source: BillSource.wechat,
    origin: RecordOrigin.manual,
    occurredAt: DateTime(2026, 7, 7, 8),
    amount: 12.5,
    amountCents: 1250,
    direction: TransactionDirection.expense,
    counterparty: '便利店',
    description: '早餐',
    paymentMethod: '零钱',
    originalCategory: '商户消费',
    userCategory: '餐饮',
    note: '豆浆',
    importBatchId: '手动添加',
    confirmationStatus: ConfirmationStatus.confirmed,
    fingerprint: 'backup-export-record',
    updatedAt: DateTime(2026, 7, 7, 8),
  );
}

Map<String, Object?> _jsonFile(Archive archive, String name) {
  final file = archive.files.singleWhere((file) => file.name == name);
  return jsonDecode(utf8.decode(file.content as List<int>))
      as Map<String, Object?>;
}
```

- [ ] **Step 4: Run export tests and verify failure**

Run:

```powershell
flutter test --no-pub test/features/backup/backup_service_test.dart --reporter expanded
```

Expected: fails because `BackupService` and `backup_models.dart` do not exist.

- [ ] **Step 5: Create backup models**

Create `lib/features/backup/data/backup_models.dart`:

```dart
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

const oceanBabyBackupAppName = 'Ocean Baby';
const oceanBabyBackupFormatVersion = 1;
const oceanBabyBackupExtension = 'oceanbaby';

class BackupExportResult {
  const BackupExportResult({
    required this.fileName,
    required this.bytes,
    required this.missingImagePaths,
  });

  final String fileName;
  final List<int> bytes;
  final List<String> missingImagePaths;
}

class BackupImportResult {
  const BackupImportResult({
    required this.ledgerCount,
    required this.noteCount,
    required this.todoCount,
    required this.moodCount,
    required this.settingCount,
  });

  final int ledgerCount;
  final int noteCount;
  final int todoCount;
  final int moodCount;
  final int settingCount;
}
```

- [ ] **Step 6: Implement export in backup service**

Create `lib/features/backup/data/backup_service.dart` with the export path:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/database/app_database.dart';
import 'backup_models.dart';

typedef DirectoryProvider = Future<Directory> Function();

class BackupService {
  BackupService(
    this._database, {
    DateTime Function()? now,
    DirectoryProvider? documentsDirectoryProvider,
  }) : _now = now ?? DateTime.now,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final AppDatabase _database;
  final DateTime Function() _now;
  final DirectoryProvider _documentsDirectoryProvider;

  Future<BackupExportResult> createBackup() async {
    final exportedAt = _now();
    final imageExport = await _exportNoteImages();
    final data = {
      'ledgerRecords': await _database.db.query('ledger_records'),
      'notes': await _exportNotes(imageExport.imageFilesByOriginalPath),
      'todos': await _database.db.query('todos'),
      'moods': await _database.db.query('moods'),
      'settings': await _database.db.query('settings'),
    };
    final manifest = {
      'appName': oceanBabyBackupAppName,
      'backupFormatVersion': oceanBabyBackupFormatVersion,
      'databaseSchemaVersion': AppDatabase.schemaVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'platform': Platform.operatingSystem,
    };

    final archive = Archive()
      ..addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)))
      ..addFile(ArchiveFile.string('data.json', jsonEncode(data)));
    for (final entry in imageExport.archiveFiles.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }

    return BackupExportResult(
      fileName:
          'OceanBaby_${DateFormat('yyyyMMdd_HHmmss').format(exportedAt)}.oceanbaby',
      bytes: ZipEncoder().encode(archive)!,
      missingImagePaths: imageExport.missingImagePaths,
    );
  }

  Future<List<Map<String, Object?>>> _exportNotes(
    Map<String, String> imageFilesByOriginalPath,
  ) async {
    final notes = await _database.db.query('notes');
    return notes.map((row) {
      final exportedPaths = _decodeImagePaths(row['image_path'] as String? ?? '')
          .where(imageFilesByOriginalPath.containsKey)
          .map((path) => imageFilesByOriginalPath[path]!)
          .toList();
      return {
        'id': row['id'],
        'title': row['title'],
        'content': row['content'],
        'folder': row['folder'],
        'pinned': row['pinned'],
        'image_paths': exportedPaths,
        'updated_at': row['updated_at'],
      };
    }).toList();
  }

  Future<_ImageExport> _exportNoteImages() async {
    final notes = await _database.db.query('notes');
    final archiveFiles = <String, List<int>>{};
    final imageFilesByOriginalPath = <String, String>{};
    final missingImagePaths = <String>[];

    for (final note in notes) {
      final noteId = note['id'];
      final imagePaths = _decodeImagePaths(note['image_path'] as String? ?? '');
      for (var index = 0; index < imagePaths.length; index++) {
        final originalPath = imagePaths[index];
        final file = File(originalPath);
        if (!await file.exists()) {
          missingImagePaths.add(originalPath);
          continue;
        }
        final extension = p.extension(originalPath).isEmpty
            ? '.jpg'
            : p.extension(originalPath);
        final archivePath = 'note_images/note_${noteId}_$index$extension';
        archiveFiles[archivePath] = await file.readAsBytes();
        imageFilesByOriginalPath[originalPath] = archivePath;
      }
    }

    return _ImageExport(
      archiveFiles: archiveFiles,
      imageFilesByOriginalPath: imageFilesByOriginalPath,
      missingImagePaths: missingImagePaths,
    );
  }

  List<String> _decodeImagePaths(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];
    if (!trimmed.startsWith('[')) return [trimmed];
    final decoded = jsonDecode(trimmed);
    if (decoded is! List) return [trimmed];
    return decoded.whereType<String>().where((path) => path.isNotEmpty).toList();
  }
}

class _ImageExport {
  const _ImageExport({
    required this.archiveFiles,
    required this.imageFilesByOriginalPath,
    required this.missingImagePaths,
  });

  final Map<String, List<int>> archiveFiles;
  final Map<String, String> imageFilesByOriginalPath;
  final List<String> missingImagePaths;
}
```

- [ ] **Step 7: Run export tests and verify pass**

Run:

```powershell
flutter test --no-pub test/features/backup/backup_service_test.dart --reporter expanded
```

Expected: the two export tests pass.

- [ ] **Step 8: Commit export slice**

Run:

```powershell
git add pubspec.yaml pubspec.lock lib/features/backup/data/backup_models.dart lib/features/backup/data/backup_service.dart test/features/backup/backup_service_test.dart
git commit -m "feat: add data backup export"
```

Expected: commit contains only backup export code, direct dependency, and export tests.

---

### Task 2: Implement Cover Restore Import

**Files:**
- Modify: `lib/features/backup/data/backup_service.dart`
- Modify: `test/features/backup/backup_service_test.dart`

- [ ] **Step 1: Add failing restore tests**

Append these tests to `test/features/backup/backup_service_test.dart`:

```dart
test('导入备份会覆盖旧数据并重建笔记图片路径', () async {
  final sourceDb = await AppDatabase.openInMemory();
  final targetDb = await AppDatabase.openInMemory();
  addTearDown(sourceDb.close);
  addTearDown(targetDb.close);
  final tempDir = await Directory.systemTemp.createTemp('ocean_baby_restore_');
  addTearDown(() => tempDir.delete(recursive: true));
  final sourceImage = File('${tempDir.path}${Platform.pathSeparator}source.png');
  await sourceImage.writeAsBytes([9, 8, 7]);
  await _seedFullData(sourceDb, sourceImage.path);
  await NotesRepository(targetDb).create(
    title: '旧笔记',
    content: '应该被覆盖',
    folder: '默认',
  );
  await TodosRepository(targetDb).create(
    title: '旧待办',
    dueDate: DateTime(2026, 1, 1),
  );

  final sourceService = BackupService(
    sourceDb,
    now: () => DateTime(2026, 7, 7, 9, 30),
    documentsDirectoryProvider: () async => Directory('${tempDir.path}${Platform.pathSeparator}source_docs')..createSync(recursive: true),
  );
  final targetDocs = Directory('${tempDir.path}${Platform.pathSeparator}target_docs')
    ..createSync(recursive: true);
  final targetService = BackupService(
    targetDb,
    documentsDirectoryProvider: () async => targetDocs,
  );

  final backup = await sourceService.createBackup();
  final result = await targetService.restoreFromBytes(backup.bytes);

  expect(result.ledgerCount, 1);
  expect(result.noteCount, 1);
  expect(result.todoCount, 1);
  expect(result.moodCount, 1);
  expect(result.settingCount, 1);
  expect(await NotesRepository(targetDb).search('旧笔记'), isEmpty);
  expect(await TodosRepository(targetDb).listAll(), hasLength(1));
  expect((await TodosRepository(targetDb).listAll()).single.title, '整理账单');

  final restoredNote = (await NotesRepository(targetDb).listRecent()).single;
  expect(restoredNote.title, '旅行照片');
  expect(restoredNote.imagePaths, hasLength(1));
  expect(restoredNote.imagePaths.single, isNot(sourceImage.path));
  expect(restoredNote.imagePaths.single, contains('note_images'));
  expect(await File(restoredNote.imagePaths.single).readAsBytes(), [9, 8, 7]);
});

test('非 Ocean Baby 备份文件会返回中文错误', () async {
  final db = await AppDatabase.openInMemory();
  addTearDown(db.close);
  final tempDir = await Directory.systemTemp.createTemp('ocean_baby_invalid_');
  addTearDown(() => tempDir.delete(recursive: true));
  final service = BackupService(
    db,
    documentsDirectoryProvider: () async => tempDir,
  );

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
```

- [ ] **Step 2: Run restore tests and verify failure**

Run:

```powershell
flutter test --no-pub test/features/backup/backup_service_test.dart --reporter expanded
```

Expected: fails because `restoreFromBytes` is not implemented.

- [ ] **Step 3: Add restore implementation**

Add the following members to `BackupService` in `lib/features/backup/data/backup_service.dart`:

```dart
  Future<BackupImportResult> restoreFromBytes(List<int> bytes) async {
    final archive = _decodeArchive(bytes);
    final manifest = _decodeJsonFile(archive, 'manifest.json');
    if (manifest['appName'] != oceanBabyBackupAppName) {
      throw const BackupException('这不是 Ocean Baby 备份文件');
    }
    final version = manifest['backupFormatVersion'];
    if (version is! int || version > oceanBabyBackupFormatVersion) {
      throw const BackupException('备份文件版本过高，请升级 Ocean Baby 后再导入');
    }
    final data = _decodeJsonFile(archive, 'data.json');
    final restoredImages = await _restoreImages(archive);
    final notes = _restoreNoteRows(_listField(data, 'notes'), restoredImages);
    final ledgerRecords = _listField(data, 'ledgerRecords');
    final todos = _listField(data, 'todos');
    final moods = _listField(data, 'moods');
    final settings = _listField(data, 'settings');

    await _database.db.transaction((txn) async {
      for (final table in [
        'ledger_records',
        'notes',
        'todos',
        'moods',
        'settings',
      ]) {
        await txn.delete(table);
      }
      await txn.delete(
        'sqlite_sequence',
        where: 'name IN (?, ?, ?, ?)',
        whereArgs: ['ledger_records', 'notes', 'todos', 'moods'],
      );
      for (final row in ledgerRecords) {
        await txn.insert('ledger_records', row);
      }
      for (final row in notes) {
        await txn.insert('notes', row);
      }
      for (final row in todos) {
        await txn.insert('todos', row);
      }
      for (final row in moods) {
        await txn.insert('moods', row);
      }
      for (final row in settings) {
        await txn.insert('settings', row);
      }
    });

    return BackupImportResult(
      ledgerCount: ledgerRecords.length,
      noteCount: notes.length,
      todoCount: todos.length,
      moodCount: moods.length,
      settingCount: settings.length,
    );
  }

  Archive _decodeArchive(List<int> bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes, verify: true);
    } catch (_) {
      throw const BackupException('备份文件损坏，无法读取');
    }
  }

  Map<String, Object?> _decodeJsonFile(Archive archive, String name) {
    try {
      final file = archive.files.singleWhere((file) => file.name == name);
      return jsonDecode(utf8.decode(file.content as List<int>))
          as Map<String, Object?>;
    } catch (_) {
      throw BackupException('备份文件损坏，缺少 $name');
    }
  }

  List<Map<String, Object?>> _listField(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! List) {
      throw BackupException('备份文件损坏，缺少 $key');
    }
    return value.cast<Map>().map((row) => Map<String, Object?>.from(row)).toList();
  }

  Future<Map<String, String>> _restoreImages(Archive archive) async {
    final targetDir = Directory(
      p.join((await _documentsDirectoryProvider()).path, 'note_images'),
    );
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final restored = <String, String>{};
    for (final file in archive.files.where((file) => file.name.startsWith('note_images/'))) {
      if (!file.isFile) continue;
      final targetName =
          '${DateTime.now().microsecondsSinceEpoch}_${p.basename(file.name)}';
      final target = File(p.join(targetDir.path, targetName));
      await target.writeAsBytes(file.content as List<int>, flush: true);
      restored[file.name] = target.path;
    }
    return restored;
  }

  List<Map<String, Object?>> _restoreNoteRows(
    List<Map<String, Object?>> exportedNotes,
    Map<String, String> restoredImages,
  ) {
    return exportedNotes.map((row) {
      final imagePaths = (row['image_paths'] as List? ?? const [])
          .whereType<String>()
          .map((path) => restoredImages[path])
          .whereType<String>()
          .toList();
      return {
        'id': row['id'],
        'title': row['title'],
        'content': row['content'],
        'folder': row['folder'],
        'pinned': row['pinned'],
        'image_path': imagePaths.isEmpty
            ? ''
            : imagePaths.length == 1
            ? imagePaths.single
            : jsonEncode(imagePaths),
        'updated_at': row['updated_at'],
      };
    }).toList();
  }
```

- [ ] **Step 4: Run restore tests and verify pass**

Run:

```powershell
flutter test --no-pub test/features/backup/backup_service_test.dart --reporter expanded
```

Expected: all backup service tests pass.

- [ ] **Step 5: Commit restore slice**

Run:

```powershell
git add lib/features/backup/data/backup_service.dart test/features/backup/backup_service_test.dart
git commit -m "feat: restore data from backup"
```

Expected: commit contains only restore logic and restore tests.

---

### Task 3: Add Settings Page Backup UI

**Files:**
- Modify: `lib/features/home/ui/home_page.dart`
- Modify: `test/widget/navigation_and_theme_test.dart`

- [ ] **Step 1: Write failing widget test**

Append this test to `test/widget/navigation_and_theme_test.dart`:

```dart
testWidgets('设置页提供数据备份与恢复折叠分类', (tester) async {
  var exported = false;
  var imported = false;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HomeSettingsSection(
            promptEnabledFuture: Future.value(true),
            showMoodDotFuture: Future.value(true),
            showMoodTextFuture: Future.value(true),
            showMoodNoteFuture: Future.value(true),
            notificationEnabledFuture: Future.value(false),
            backupBusy: false,
            onPromptChanged: (_) {},
            onShowMoodDotChanged: (_) {},
            onShowMoodTextChanged: (_) {},
            onShowMoodNoteChanged: (_) {},
            onNotificationSettingsRequested: () {},
            onThemeChanged: (_) {},
            onExportBackup: () => exported = true,
            onImportBackup: () => imported = true,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  expect(find.text('数据备份与恢复'), findsOneWidget);
  expect(find.text('导出全部数据'), findsNothing);

  await _toggleSettingsCategory(tester, '数据备份与恢复');
  await tester.tap(find.text('导出全部数据'));
  await tester.tap(find.text('导入恢复数据'));

  expect(exported, isTrue);
  expect(imported, isTrue);
});
```

Update `_buildSettingsSection()` in the same test file to pass the new constructor arguments:

```dart
backupBusy: false,
onExportBackup: () {},
onImportBackup: () {},
```

- [ ] **Step 2: Run widget test and verify failure**

Run:

```powershell
flutter test --no-pub test/widget/navigation_and_theme_test.dart --reporter expanded
```

Expected: fails because `HomeSettingsSection` does not accept backup callbacks yet.

- [ ] **Step 3: Add backup callback fields to HomeSettingsSection**

Modify `HomeSettingsSection` constructor and fields in `lib/features/home/ui/home_page.dart`:

```dart
    required this.backupBusy,
    required this.onExportBackup,
    required this.onImportBackup,
```

```dart
  final bool backupBusy;
  final VoidCallback onExportBackup;
  final VoidCallback onImportBackup;
```

- [ ] **Step 4: Add data backup category UI**

Inside `HomeSettingsSection.build`, after the ledger settings category, add:

```dart
        _SettingsCategory(
          title: '数据备份与恢复',
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('导出全部数据'),
                subtitle: const Text('生成一个可用于重装后恢复的 Ocean Baby 备份文件'),
                trailing: backupBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: backupBusy ? null : onExportBackup,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restore_outlined),
                title: const Text('导入恢复数据'),
                subtitle: const Text('选择 .oceanbaby 文件并覆盖恢复当前本地数据'),
                trailing: const Icon(Icons.chevron_right),
                onTap: backupBusy ? null : onImportBackup,
              ),
            ],
          ),
        ),
```

- [ ] **Step 5: Run widget test and verify pass**

Run:

```powershell
flutter test --no-pub test/widget/navigation_and_theme_test.dart --reporter expanded
```

Expected: settings page tests pass.

- [ ] **Step 6: Commit UI slice**

Run:

```powershell
git add lib/features/home/ui/home_page.dart test/widget/navigation_and_theme_test.dart
git commit -m "feat: add backup settings entry"
```

Expected: commit contains only settings UI and tests.

---

### Task 4: Wire File Save, File Pick, And App Refresh

**Files:**
- Modify: `lib/app/ocean_baby_app.dart`
- Modify: `lib/features/home/ui/home_page.dart`
- Modify: `test/widget/widget_test.dart` if constructor changes require test updates

- [ ] **Step 1: Add BackupService dependency to HomePage**

In `lib/features/home/ui/home_page.dart`, import:

```dart
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:ocean_baby/features/backup/data/backup_models.dart';
import 'package:ocean_baby/features/backup/data/backup_service.dart';
```

Add fields to `HomePage`:

```dart
    required this.backupService,
    required this.onDataRestored,
```

```dart
  final BackupService backupService;
  final VoidCallback onDataRestored;
```

- [ ] **Step 2: Add backup state and callbacks in HomePage**

Add state field:

```dart
  bool _backupBusy = false;
```

Add export method:

```dart
  Future<void> _exportBackup() async {
    setState(() => _backupBusy = true);
    try {
      final backup = await widget.backupService.createBackup();
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: '保存 Ocean Baby 备份',
        fileName: backup.fileName,
        type: FileType.custom,
        allowedExtensions: const ['oceanbaby'],
        bytes: Uint8List.fromList(backup.bytes),
      );
      if (!mounted) return;
      final imageMessage = backup.missingImagePaths.isEmpty
          ? ''
          : '，${backup.missingImagePaths.length} 张图片未找到';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            savedPath == null ? '已取消导出' : '数据已导出$imageMessage',
          ),
        ),
      );
    } on BackupException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导出失败，请重新尝试')),
      );
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }
```

Add import method:

```dart
  Future<void> _importBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['oceanbaby'],
      withData: true,
    );
    if (result == null) return;
    final file = result.files.single;
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入恢复数据'),
        content: const Text('导入会覆盖当前全部本地数据。请确认已经保存好当前数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认导入'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _backupBusy = true);
    try {
      await widget.backupService.restoreFromBytes(bytes);
      widget.onDataRestored();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('数据已恢复')),
      );
    } on BackupException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导入失败，请重新选择备份文件')),
      );
    } finally {
      if (mounted) setState(() => _backupBusy = false);
    }
  }
```

- [ ] **Step 3: Pass backup callbacks to HomeSettingsSection**

In `HomePage.build`, pass:

```dart
          backupBusy: _backupBusy,
          onExportBackup: _exportBackup,
          onImportBackup: _importBackup,
```

- [ ] **Step 4: Wire service in OceanBabyShell**

In `lib/app/ocean_baby_app.dart`, import:

```dart
import 'package:ocean_baby/features/backup/data/backup_service.dart';
```

Add field in `_OceanBabyShellState`:

```dart
  late final _backupService = BackupService(widget.database);
  int _dataRevision = 0;
```

Add method:

```dart
  void _refreshDataAfterRestore() {
    setState(() {
      _dataRevision++;
      _moodRevision++;
      _route = AppRoute.home;
    });
  }
```

Wrap page widgets with revision keys in `_pageFor`:

```dart
      AppRoute.home => HomePage(
        key: ValueKey('home-$_dataRevision'),
        backupService: _backupService,
        onDataRestored: _refreshDataAfterRestore,
        ledgerRepository: _ledgerRepository,
        notesRepository: _notesRepository,
        todosRepository: _todosRepository,
        moodRepository: _moodRepository,
        promptService: _moodPromptService,
        onThemeChanged: widget.onThemeChanged,
        onOpenRoute: (route) => setState(() => _route = route),
        onMoodChanged: _refreshMood,
      ),
```

Apply explicit revision keys to the other route pages so their internal futures reload after restore:

```dart
      AppRoute.ledger => LedgerPage(
        key: ValueKey('ledger-$_dataRevision'),
        repository: _ledgerRepository,
      ),
      AppRoute.notes => NotesPage(
        key: ValueKey('notes-$_dataRevision'),
        repository: _notesRepository,
      ),
      AppRoute.todos => TodosPage(
        key: ValueKey('todos-$_dataRevision'),
        repository: _todosRepository,
      ),
      AppRoute.mood => MoodPage(
        key: ValueKey('mood-$_dataRevision'),
        repository: _moodRepository,
        promptService: _moodPromptService,
        onMoodChanged: _refreshMood,
      ),
```

- [ ] **Step 5: Update any constructor tests**

Run:

```powershell
rg "HomePage\\(" test lib
```

For every direct `HomePage(` test constructor, pass a `BackupService` created from the same in-memory database and `onDataRestored: () {}`.

- [ ] **Step 6: Run affected widget tests**

Run:

```powershell
flutter test --no-pub test/widget/navigation_and_theme_test.dart test/widget/widget_test.dart --reporter expanded
```

Expected: affected widget tests pass.

- [ ] **Step 7: Commit wiring slice**

Run:

```powershell
git add lib/app/ocean_baby_app.dart lib/features/home/ui/home_page.dart test/widget/navigation_and_theme_test.dart test/widget/widget_test.dart
git commit -m "feat: wire backup restore flow"
```

Expected: commit contains app wiring and any constructor test updates.

---

### Task 5: Full Verification And APK Build

**Files:**
- Verify all changed files.
- Build release APK.

- [ ] **Step 1: Run analyzer**

Run:

```powershell
flutter analyze --no-pub
```

Expected: `No issues found!`

- [ ] **Step 2: Run all tests**

Run:

```powershell
flutter test --no-pub --reporter expanded
```

Expected: all tests pass, including backup service and settings UI tests.

- [ ] **Step 3: Build release APK**

Run:

```powershell
flutter build apk --release
```

Expected: build succeeds and writes:

```text
build\app\outputs\flutter-apk\app-release.apk
```

- [ ] **Step 4: Manual smoke checklist**

Use a debug or release install on Android:

```text
1. 打开 Ocean Baby，进入设置。
2. 展开“数据备份与恢复”。
3. 点击“导出全部数据”，保存一个 .oceanbaby 文件。
4. 新增一条临时笔记或待办。
5. 点击“导入恢复数据”，选择刚才的 .oceanbaby 文件。
6. 在确认弹框中点击“确认导入”。
7. 确认临时数据消失，备份中的账本、笔记、图片、待办、心情和设置恢复。
```

- [ ] **Step 5: Final commit if verification fixes were needed**

If verification required fixes, commit them:

```powershell
git add pubspec.yaml pubspec.lock lib/features/backup/data/backup_models.dart lib/features/backup/data/backup_service.dart lib/features/home/ui/home_page.dart lib/app/ocean_baby_app.dart test/features/backup/backup_service_test.dart test/widget/navigation_and_theme_test.dart test/widget/widget_test.dart
git commit -m "fix: polish backup restore verification"
```

Expected: no verification-only changes remain unstaged.

---

## Self-Review

- Spec coverage: The plan covers `.oceanbaby` single file export, JSON data, note images, overwrite restore, settings entry, Chinese errors, tests, and APK build.
- Type consistency: `BackupExportResult`, `BackupImportResult`, `BackupException`, `BackupService.createBackup`, and `BackupService.restoreFromBytes` are used consistently across tasks.
- Scope control: The plan does not add cloud sync, login, desktop support, iOS support, or access to other apps' internal databases.

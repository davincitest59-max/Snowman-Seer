import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../platform/app_directories.dart';
import 'backup_models.dart';

typedef DirectoryProvider = Future<Directory> Function();

class BackupService {
  const BackupService(
    this._database, {
    this.now,
    this.documentsDirectoryProvider,
  });

  final AppDatabase _database;
  final DateTime Function()? now;
  final DirectoryProvider? documentsDirectoryProvider;

  Future<BackupExportResult> createBackup() async {
    final exportedAt = (now ?? DateTime.now)();
    final archive = Archive();
    final missingImagePaths = <String>[];
    final notes = await _exportNotes(archive, missingImagePaths);
    final data = {
      'ledgerRecords': await _queryRows('ledger_records'),
      'notes': notes,
      'todos': await _queryRows('todos'),
      'moods': await _queryRows('moods'),
      'settings': await _queryRows('settings'),
    };
    final manifest = {
      'appName': oceanBabyBackupAppName,
      'backupFormatVersion': oceanBabyBackupFormatVersion,
      'databaseSchemaVersion': AppDatabase.schemaVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'platform': Platform.operatingSystem,
    };

    archive.addFile(ArchiveFile.string('manifest.json', jsonEncode(manifest)));
    archive.addFile(ArchiveFile.string('data.json', jsonEncode(data)));
    archive.addFile(ArchiveFile('note_images/', 0, const <int>[]));

    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) {
      throw const BackupException('无法创建备份文件');
    }

    return BackupExportResult(
      fileName:
          'OceanBaby_${DateFormat('yyyyMMdd_HHmmss').format(exportedAt)}.$oceanBabyBackupExtension',
      bytes: bytes,
      missingImagePaths: missingImagePaths,
    );
  }

  Future<List<Map<String, Object?>>> _queryRows(String table) {
    return _database.db.query(table);
  }

  Future<List<Map<String, Object?>>> _exportNotes(
    Archive archive,
    List<String> missingImagePaths,
  ) async {
    final rows = await _queryRows('notes');
    final exportedRows = <Map<String, Object?>>[];
    for (final row in rows) {
      final exportedRow = Map<String, Object?>.from(row);
      final noteId = row['id'] as int;
      final imagePaths = _decodeImagePaths(row['image_path'] as String? ?? '');
      final backupImagePaths = <String>[];

      for (var index = 0; index < imagePaths.length; index++) {
        final imagePath = imagePaths[index];
        final imageFile = File(imagePath);
        if (!await imageFile.exists()) {
          missingImagePaths.add(imagePath);
          continue;
        }

        final extension = p.extension(imagePath);
        final backupPath = 'note_images/note_${noteId}_$index$extension';
        archive.addFile(
          ArchiveFile(
            backupPath,
            await imageFile.length(),
            await imageFile.readAsBytes(),
          ),
        );
        backupImagePaths.add(backupPath);
      }

      exportedRow.remove('image_path');
      exportedRow['image_paths'] = backupImagePaths;
      exportedRows.add(exportedRow);
    }
    return exportedRows;
  }

  List<String> _decodeImagePaths(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const [];
    if (!trimmed.startsWith('[')) return [trimmed];
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List) return [trimmed];
      return decoded
          .whereType<String>()
          .map((path) => path.trim())
          .where((path) => path.isNotEmpty)
          .toList();
    } on FormatException {
      return [trimmed];
    }
  }

  Future<BackupImportResult> restoreFromBytes(List<int> bytes) async {
    final archive = _decodeArchive(bytes);
    final manifest = _readJsonObject(archive, 'manifest.json');
    final data = _readJsonObject(archive, 'data.json');

    if (manifest['appName'] != oceanBabyBackupAppName) {
      throw const BackupException('这不是 Ocean Baby 备份文件');
    }

    final version = manifest['backupFormatVersion'];
    if (version is! int) {
      throw const BackupException('备份文件损坏，请重新选择备份文件');
    }
    if (version > oceanBabyBackupFormatVersion) {
      throw const BackupException('备份文件版本过高，请升级 Ocean Baby 后再导入');
    }

    final ledgerRecords = _readRows(data, 'ledgerRecords');
    final notes = _readRows(data, 'notes');
    final todos = _readRows(data, 'todos');
    final moods = _readRows(data, 'moods');
    final settings = _readRows(data, 'settings');
    final noteImagePaths = _validateNotes(notes, archive);
    final writtenImageFiles = <File>[];

    try {
      final restoredImagePaths = await _restoreNoteImages(
        archive,
        noteImagePaths,
        writtenImageFiles,
      );

      await _database.db.transaction((txn) async {
        for (final table in const [
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
          await txn.insert('notes', _restoreNoteRow(row, restoredImagePaths));
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
    } on BackupException {
      await _deleteFiles(writtenImageFiles);
      rethrow;
    } catch (_) {
      await _deleteFiles(writtenImageFiles);
      throw const BackupException('导入失败，请重新选择备份文件');
    }

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
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const BackupException('备份文件损坏，请重新选择备份文件');
    }
  }

  Map<String, Object?> _readJsonObject(Archive archive, String name) {
    try {
      final file = archive.files.singleWhere(
        (entry) => entry.name == name && entry.isFile,
      );
      final decoded = jsonDecode(utf8.decode(file.content as List<int>));
      if (decoded is Map<String, Object?>) return decoded;
    } catch (_) {
      throw const BackupException('备份文件损坏，请重新选择备份文件');
    }
    throw const BackupException('备份文件损坏，请重新选择备份文件');
  }

  List<Map<String, Object?>> _readRows(
    Map<String, Object?> data,
    String field,
  ) {
    final value = data[field];
    if (value is! List) {
      throw const BackupException('备份文件损坏，请重新选择备份文件');
    }
    return value.map((row) {
      if (row is! Map) {
        throw const BackupException('备份文件损坏，请重新选择备份文件');
      }
      return Map<String, Object?>.from(row);
    }).toList();
  }

  Set<String> _validateNotes(
    List<Map<String, Object?>> notes,
    Archive archive,
  ) {
    final archiveImagePaths = archive.files
        .where((file) => file.isFile)
        .map((file) => file.name)
        .where(_isValidBackupImagePath)
        .toSet();
    final noteImagePaths = <String>{};
    for (final note in notes) {
      _requireString(note, 'title');
      _requireString(note, 'content');
      _requireString(note, 'folder');
      _requireInt(note, 'pinned');
      _requireString(note, 'updated_at');
      final imagePaths = note['image_paths'];
      if (imagePaths is! List) {
        throw const BackupException('备份文件损坏，请重新选择备份文件');
      }
      for (final imagePath in imagePaths) {
        if (imagePath is! String ||
            !_isValidBackupImagePath(imagePath) ||
            !archiveImagePaths.contains(imagePath)) {
          throw const BackupException('备份文件损坏，请重新选择备份文件');
        }
        noteImagePaths.add(imagePath);
      }
    }
    return noteImagePaths;
  }

  void _requireString(Map<String, Object?> row, String field) {
    if (row[field] is! String) {
      throw const BackupException('备份文件损坏，请重新选择备份文件');
    }
  }

  void _requireInt(Map<String, Object?> row, String field) {
    if (row[field] is! int) {
      throw const BackupException('备份文件损坏，请重新选择备份文件');
    }
  }

  bool _isValidBackupImagePath(String path) {
    if (!path.startsWith('note_images/')) return false;
    final relativePath = p.posix.relative(path, from: 'note_images');
    return relativePath.isNotEmpty &&
        !relativePath.startsWith('..') &&
        !p.posix.isAbsolute(relativePath) &&
        p.posix.basename(relativePath).isNotEmpty;
  }

  Future<Map<String, String>> _restoreNoteImages(
    Archive archive,
    Set<String> noteImagePaths,
    List<File> writtenImageFiles,
  ) async {
    final documentsDirectory =
        await (documentsDirectoryProvider ??
            const AppDirectoriesBridge().applicationDocumentsDirectory)();
    final noteImagesDirectory = Directory(
      p.join(documentsDirectory.path, 'note_images'),
    );
    if (!await noteImagesDirectory.exists()) {
      await noteImagesDirectory.create(recursive: true);
    }

    final restoredPaths = <String, String>{};
    final uniquePrefix = (now ?? DateTime.now)().microsecondsSinceEpoch;
    var fileIndex = 0;
    for (final file in archive.files) {
      if (!file.isFile || !noteImagePaths.contains(file.name)) continue;

      final relativePath = p.posix.relative(file.name, from: 'note_images');
      if (relativePath.isEmpty ||
          relativePath.startsWith('..') ||
          p.posix.isAbsolute(relativePath)) {
        throw const BackupException('备份文件损坏，请重新选择备份文件');
      }

      final restoredFile = File(
        p.join(
          noteImagesDirectory.path,
          '${uniquePrefix}_${fileIndex++}_${p.basename(relativePath)}',
        ),
      );
      await restoredFile.writeAsBytes(file.content as List<int>);
      writtenImageFiles.add(restoredFile);
      restoredPaths[file.name] = restoredFile.path;
    }
    return restoredPaths;
  }

  Future<void> _deleteFiles(List<File> files) async {
    for (final file in files) {
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Best-effort cleanup; keep the original import error visible.
      }
    }
  }

  Map<String, Object?> _restoreNoteRow(
    Map<String, Object?> row,
    Map<String, String> restoredImagePaths,
  ) {
    final restoredRow = Map<String, Object?>.from(row);
    final imagePaths = restoredRow.remove('image_paths');
    if (imagePaths is! List) {
      throw const BackupException('备份文件损坏，请重新选择备份文件');
    }
    final paths = imagePaths
        .map((path) {
          if (path is! String) {
            throw const BackupException('备份文件损坏，请重新选择备份文件');
          }
          return restoredImagePaths[path] ?? '';
        })
        .where((path) => path.isNotEmpty)
        .toList();

    restoredRow['image_path'] = switch (paths.length) {
      0 => '',
      1 => paths.single,
      _ => jsonEncode(paths),
    };
    return restoredRow;
  }
}

const oceanBabyBackupAppName = 'Ocean Baby';
const oceanBabyBackupFormatVersion = 1;
const oceanBabyBackupExtension = 'oceanbaby';

class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

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

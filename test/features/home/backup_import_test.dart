import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/features/backup/data/backup_models.dart';
import 'package:ocean_baby/features/home/ui/home_page.dart';
import 'package:ocean_baby/platform/ocean_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('备份导入选择文件时不使用安卓不支持的 oceanbaby 扩展过滤', () async {
    final picker = _RecordingOceanFilePicker(
      PickedOceanFile(
        name: 'OceanBaby_20260707.oceanbaby',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    );
    final bridge = OceanBackupFileBridge(picker);

    final bytes = await bridge.pickBackupBytes();

    expect(bytes, [1, 2, 3]);
    expect(picker.mimeTypes, isEmpty);
  });

  test('备份导入选择非 oceanbaby 文件时给出中文错误', () async {
    final picker = _RecordingOceanFilePicker(
      PickedOceanFile(
        name: 'backup.zip',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    );
    final bridge = OceanBackupFileBridge(picker);

    await expectLater(
      bridge.pickBackupBytes(),
      throwsA(
        isA<BackupException>().having(
          (error) => error.message,
          'message',
          contains('.oceanbaby'),
        ),
      ),
    );
  });

  test('导入恢复数据选择器平台异常会转成中文反馈', () async {
    final result = await pickBackupForImport(
      _FakeBackupFileBridge(
        pickError: PlatformException(code: 'unsupported_filter'),
      ),
    );

    expect(result.bytes, isNull);
    expect(result.message, '无法打开文件选择器，请重新尝试');
  });

  test('导入恢复数据取消选择时会转成中文反馈', () async {
    final result = await pickBackupForImport(const _FakeBackupFileBridge());

    expect(result.bytes, isNull);
    expect(result.message, '已取消导入');
  });
}

class _RecordingOceanFilePicker implements OceanFilePicker {
  _RecordingOceanFilePicker(this.result);

  final PickedOceanFile? result;
  List<String>? mimeTypes;
  Uint8List? savedBytes;

  @override
  Future<PickedOceanFile?> pickFile({
    List<String> mimeTypes = const [],
  }) async {
    this.mimeTypes = mimeTypes;
    return result;
  }

  @override
  Future<List<PickedOceanFile>> pickImages({bool allowMultiple = true}) async {
    return result == null ? const [] : [result!];
  }

  @override
  Future<String?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    savedBytes = bytes;
    return 'backup.oceanbaby';
  }
}

class _FakeBackupFileBridge implements BackupFileBridge {
  const _FakeBackupFileBridge({this.pickError});

  final Object? pickError;

  @override
  Future<List<int>?> pickBackupBytes() async {
    final error = pickError;
    if (error != null) throw error;
    return null;
  }

  @override
  Future<String?> saveBackup({
    required String fileName,
    required List<int> bytes,
  }) async {
    return null;
  }
}

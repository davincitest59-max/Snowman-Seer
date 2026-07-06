import 'package:flutter/services.dart';

class PickedOceanFile {
  const PickedOceanFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

abstract interface class OceanFilePicker {
  Future<PickedOceanFile?> pickFile({List<String> mimeTypes = const []});

  Future<List<PickedOceanFile>> pickImages({bool allowMultiple = true});

  Future<String?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
  });
}

class OceanFilePickerBridge implements OceanFilePicker {
  const OceanFilePickerBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('ocean_baby/file_picker');

  final MethodChannel _channel;

  @override
  Future<PickedOceanFile?> pickFile({List<String> mimeTypes = const []}) async {
    final raw = await _channel.invokeMapMethod<String, Object?>('pickFile', {
      'mimeTypes': mimeTypes,
    });
    if (raw == null) return null;
    return _pickedFileFromMap(raw);
  }

  @override
  Future<List<PickedOceanFile>> pickImages({bool allowMultiple = true}) async {
    final rawFiles = await _channel.invokeListMethod<Object?>('pickImages', {
      'allowMultiple': allowMultiple,
    });
    if (rawFiles == null) return const [];
    return rawFiles
        .whereType<Map<Object?, Object?>>()
        .map((raw) => raw.map((key, value) => MapEntry(key.toString(), value)))
        .map(_pickedFileFromMap)
        .toList(growable: false);
  }

  @override
  Future<String?> saveFile({
    required String fileName,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
  }) {
    return _channel.invokeMethod<String>('saveFile', {
      'fileName': fileName,
      'bytes': bytes,
      'mimeType': mimeType,
    });
  }

  PickedOceanFile _pickedFileFromMap(Map<String, Object?> raw) {
    final name = raw['name'] as String? ?? '未命名文件';
    final bytes = raw['bytes'];
    if (bytes is Uint8List) {
      return PickedOceanFile(name: name, bytes: bytes);
    }
    throw PlatformException(
      code: 'invalid_file',
      message: '无法读取选择的文件',
    );
  }
}

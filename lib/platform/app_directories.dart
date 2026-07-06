import 'dart:io';

import 'package:flutter/services.dart';

class AppDirectoriesBridge {
  const AppDirectoriesBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('ocean_baby/app_directories');

  final MethodChannel _channel;

  Future<Directory> applicationSupportDirectory() {
    return _directoryFor('getApplicationSupportDirectory');
  }

  Future<Directory> applicationDocumentsDirectory() {
    return _directoryFor('getApplicationDocumentsDirectory');
  }

  Future<Directory> _directoryFor(String method) async {
    final path = await _channel.invokeMethod<String>(method);
    if (path == null || path.isEmpty) {
      throw PlatformException(code: 'missing_directory', message: '无法获取应用目录');
    }
    return Directory(path);
  }
}

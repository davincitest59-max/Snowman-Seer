import 'dart:io';

import 'package:flutter/services.dart';

class NotificationPermissionBridge {
  const NotificationPermissionBridge({MethodChannel? channel, this.enabled})
    : _channel =
          channel ?? const MethodChannel('ocean_baby/notification_permission');

  final MethodChannel _channel;
  final bool? enabled;

  bool get _isEnabled => enabled ?? Platform.isAndroid;

  Future<bool> isNotificationListenerEnabled() async {
    if (!_isEnabled) return false;
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> openNotificationListenerSettings() async {
    if (!_isEnabled) return;
    try {
      await _channel.invokeMethod<void>('openSettings');
    } on MissingPluginException {
      return;
    }
  }
}

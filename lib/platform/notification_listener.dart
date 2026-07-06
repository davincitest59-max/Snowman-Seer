import 'dart:io';

import 'package:flutter/services.dart';

class AppNotification {
  const AppNotification({
    required this.packageName,
    required this.title,
    required this.body,
    required this.postedAtMillis,
  });

  final String packageName;
  final String title;
  final String body;
  final int postedAtMillis;
}

class NotificationListenerBridge {
  const NotificationListenerBridge({EventChannel? channel, this.enabled})
    : _channel = channel ?? const EventChannel('ocean_baby/notifications');

  final EventChannel _channel;
  final bool? enabled;

  bool get _isEnabled => enabled ?? Platform.isAndroid;

  Stream<AppNotification> notifications() {
    if (!_isEnabled) return const Stream<AppNotification>.empty();
    return _channel
        .receiveBroadcastStream()
        .map(_notificationFromEvent)
        .where(
          (notification) =>
              notification.packageName.isNotEmpty &&
              (notification.title.isNotEmpty || notification.body.isNotEmpty),
        );
  }

  AppNotification _notificationFromEvent(Object? event) {
    if (event is! Map) {
      throw const FormatException('通知事件格式不正确');
    }

    return AppNotification(
      packageName: _stringValue(event['packageName']),
      title: _stringValue(event['title']),
      body: _stringValue(event['body']),
      postedAtMillis: _intValue(event['postedAtMillis']),
    );
  }

  static String _stringValue(Object? value) => value?.toString() ?? '';

  static int _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

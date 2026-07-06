import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/platform/notification_listener.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('将安卓通知事件映射为 AppNotification，并容错空值', () async {
    const channel = EventChannel('test/notifications');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          events.success(<String, Object?>{
            'packageName': 'com.tencent.mm',
            'title': null,
            'body': '支付成功 12.00 元',
            'postedAtMillis': null,
          });
        },
      ),
    );

    addTearDown(() {
      messenger.setMockStreamHandler(channel, null);
    });

    final notification = await const NotificationListenerBridge(
      channel: channel,
      enabled: true,
    ).notifications().first;

    expect(notification.packageName, 'com.tencent.mm');
    expect(notification.title, '');
    expect(notification.body, '支付成功 12.00 元');
    expect(notification.postedAtMillis, 0);
  });

  test('忽略缺少来源和正文的空通知事件', () async {
    const channel = EventChannel('test/empty_notifications');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          events.success(<String, Object?>{
            'packageName': '',
            'title': '',
            'body': '',
            'postedAtMillis': 0,
          });
          events.success(<String, Object?>{
            'packageName': 'com.tencent.mm',
            'title': '微信支付',
            'body': '支付成功 12.00 元',
            'postedAtMillis': 123,
          });
        },
      ),
    );

    addTearDown(() {
      messenger.setMockStreamHandler(channel, null);
    });

    final notification = await const NotificationListenerBridge(
      channel: channel,
      enabled: true,
    ).notifications().first;

    expect(notification.packageName, 'com.tencent.mm');
    expect(notification.body, '支付成功 12.00 元');
  });

  test('非 Map 事件会报告协议错误', () async {
    const channel = EventChannel('test/invalid_notifications');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockStreamHandler(
      channel,
      MockStreamHandler.inline(
        onListen: (_, events) {
          events.success('bad-event');
        },
      ),
    );

    addTearDown(() {
      messenger.setMockStreamHandler(channel, null);
    });

    expect(
      const NotificationListenerBridge(
        channel: channel,
        enabled: true,
      ).notifications().first,
      throwsA(isA<FormatException>()),
    );
  });

  test('没有原生通知监听通道时不会报错', () async {
    await expectLater(
      const NotificationListenerBridge(enabled: false).notifications(),
      emitsDone,
    );
  });
}

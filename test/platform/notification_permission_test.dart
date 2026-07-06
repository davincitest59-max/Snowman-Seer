import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/platform/notification_permission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('读取通知使用权开关状态', () async {
    const channel = MethodChannel('test/notification_permission');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'isEnabled');
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    const bridge = NotificationPermissionBridge(
      channel: channel,
      enabled: true,
    );

    expect(await bridge.isNotificationListenerEnabled(), isTrue);
  });

  test('打开通知使用权设置页', () async {
    const channel = MethodChannel('test/open_notification_permission');
    var opened = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'openSettings');
          opened = true;
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    const bridge = NotificationPermissionBridge(
      channel: channel,
      enabled: true,
    );
    await bridge.openNotificationListenerSettings();

    expect(opened, isTrue);
  });

  test('没有原生通知权限通道时会安静降级', () async {
    const bridge = NotificationPermissionBridge(enabled: false);

    expect(await bridge.isNotificationListenerEnabled(), isFalse);
    await expectLater(bridge.openNotificationListenerSettings(), completes);
  });
}

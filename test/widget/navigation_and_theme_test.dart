import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/app/app_routes.dart';
import 'package:ocean_baby/app/app_theme.dart';
import 'package:ocean_baby/app/ocean_baby_app.dart';
import 'package:ocean_baby/features/home/ui/home_page.dart';
import 'package:ocean_baby/features/ledger/ui/ledger_page.dart';

void main() {
  test('导航入口把设置放在心情后面且不再显示首页或我的', () {
    final labels = AppRoute.values.map((route) => route.label).toList();

    expect(labels, ['账本', '笔记', '待办', '心情', '设置']);
    expect(labels, isNot(contains('首页')));
    expect(labels, isNot(contains('我的')));
    expect(AppRoute.home.icon, Icons.settings_outlined);
    expect(AppRoute.home.selectedIcon, Icons.settings);
  });

  testWidgets('手机栏目支持触屏滑动切换并带页面滑动容器', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selectedRoute = AppRoute.ledger;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return CompactRoutePager(
              routes: AppRoute.values,
              selectedRoute: selectedRoute,
              onRouteChanged: (route) => setState(() => selectedRoute = route),
              pageBuilder: (route) => Center(child: Text(route.label)),
            );
          },
        ),
      ),
    );

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('账本'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-360, 0));
    await tester.pumpAndSettle();

    expect(selectedRoute, AppRoute.notes);
    expect(find.text('笔记'), findsOneWidget);
  });

  testWidgets('手机底部选项栏点击可以跨页切换并保留滑动容器', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selectedRoute = AppRoute.ledger;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: CompactRoutePager(
                routes: AppRoute.values,
                selectedRoute: selectedRoute,
                onRouteChanged: (route) =>
                    setState(() => selectedRoute = route),
                pageBuilder: (route) => Center(child: Text(route.label)),
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: AppRoute.values.indexOf(selectedRoute),
                onDestinationSelected: (index) {
                  setState(() => selectedRoute = AppRoute.values[index]);
                },
                destinations: AppRoute.values.map((route) {
                  return NavigationDestination(
                    icon: Icon(route.icon),
                    label: route.label,
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('账本'), findsWidgets);

    await tester.tap(find.text('设置').last);
    await tester.pumpAndSettle();

    expect(selectedRoute, AppRoute.home);
    expect(find.text('设置'), findsWidgets);
  });

  testWidgets('设置页面标题组件显示设置', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsHomeTitle())),
    );

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('我的'), findsNothing);
  });

  testWidgets('设置页面设置区展示高级配色和每日心情开关', (tester) async {
    await tester.pumpWidget(_buildSettingsSection());
    await tester.pump();

    await _toggleSettingsCategory(tester, '外观设置');
    expect(find.text('高级配色'), findsOneWidget);
    expect(find.text('勃艮第红'), findsOneWidget);
    expect(find.text('蒂芙尼蓝'), findsOneWidget);
    expect(find.text('申伦布黄'), findsOneWidget);

    await _toggleSettingsCategory(tester, '心情设置');
    expect(find.text('每日心情弹框'), findsOneWidget);
    expect(find.text('显示心情小圆点'), findsOneWidget);
    expect(find.text('显示心情文字'), findsOneWidget);
    expect(find.text('显示心情备注'), findsOneWidget);
  });

  testWidgets('设置页面把账本相关设置归入账本设置分类', (tester) async {
    await tester.pumpWidget(_buildSettingsSection());
    await tester.pump();

    await _toggleSettingsCategory(tester, '账本设置');
    expect(find.text('账本设置'), findsOneWidget);
    expect(find.text('自动记账'), findsOneWidget);
    expect(find.text('微信账单录入方式'), findsOneWidget);
    expect(find.textContaining('安卓不允许第三方应用直接读取微信内部账单库'), findsOneWidget);
  });

  testWidgets('设置页面提供待办自动删除开关', (tester) async {
    var autoDelete = false;

    await tester.pumpWidget(
      _buildSettingsSection(
        onTodoAutoDeleteCompletedChanged: (value) => autoDelete = value,
      ),
    );
    await tester.pump();

    await _toggleSettingsCategory(tester, '待办设置');

    expect(find.text('勾选待办自动删除'), findsOneWidget);
    expect(find.textContaining('开启后勾选完成会自动删除'), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile).last);

    expect(autoDelete, isTrue);
  });

  testWidgets('设置页面分类默认收起且点击标题可展开再收起', (tester) async {
    await tester.pumpWidget(_buildSettingsSection());
    await tester.pump();

    expect(find.text('外观设置'), findsOneWidget);
    expect(find.text('心情设置'), findsOneWidget);
    expect(find.text('账本设置'), findsOneWidget);
    expect(find.text('待办设置'), findsOneWidget);
    await _expectSettingsCategoryToggle(tester, title: '外观设置', content: '高级配色');
    await _expectSettingsCategoryToggle(
      tester,
      title: '心情设置',
      content: '每日心情弹框',
    );
    await _expectSettingsCategoryToggle(tester, title: '账本设置', content: '自动记账');
    await _expectSettingsCategoryToggle(
      tester,
      title: '待办设置',
      content: '勾选待办自动删除',
    );
  });

  testWidgets('账本行动区并列显示导入账单和手动记一笔并采用按钮样式', (tester) async {
    var imported = false;
    var manualRecorded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: LedgerActionsPanel(
              onImport: () => imported = true,
              onManualRecord: () => manualRecorded = true,
            ),
          ),
        ),
      ),
    );

    final importButton = find.widgetWithText(FilledButton, '导入账单');
    final manualButton = find.widgetWithText(FilledButton, '手动记一笔');

    expect(importButton, findsOneWidget);
    expect(manualButton, findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(
      (tester.getTopLeft(importButton).dy - tester.getTopLeft(manualButton).dy)
          .abs(),
      lessThan(1),
    );

    await tester.tap(importButton);
    await tester.tap(manualButton);

    expect(imported, isTrue);
    expect(manualRecorded, isTrue);
    expect(find.text('自动记账'), findsNothing);
    expect(find.text('微信账单录入方式'), findsNothing);
  });

  testWidgets('设置页面内容不显示概览入口', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsHomeContent(settingsSection: SizedBox.shrink()),
        ),
      ),
    );

    expect(find.text('今日待办'), findsNothing);
    expect(find.text('本月账本'), findsNothing);
    expect(find.text('最近笔记'), findsNothing);
    expect(find.text('今日心情'), findsNothing);
  });

  test('高级配色会应用到整体背景而不是只影响按钮', () {
    final theme = OceanBabyTheme.build(OceanTheme.burgundy);
    const expectedBackground = Color(0xFFF0DEE2);

    expect(theme.scaffoldBackgroundColor, expectedBackground);
    expect(theme.appBarTheme.backgroundColor, expectedBackground);
    expect(theme.navigationBarTheme.backgroundColor, expectedBackground);
    expect(theme.navigationRailTheme.backgroundColor, expectedBackground);
    expect(theme.scaffoldBackgroundColor, isNot(const Color(0xFFFBFAF7)));
  });

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
              todoAutoDeleteCompletedFuture: Future.value(false),
              backupBusy: false,
              onPromptChanged: (_) {},
              onShowMoodDotChanged: (_) {},
              onShowMoodTextChanged: (_) {},
              onShowMoodNoteChanged: (_) {},
              onTodoAutoDeleteCompletedChanged: (_) {},
              onNotificationSettingsRequested: () {},
              onExportBackup: () => exported = true,
              onImportBackup: () => imported = true,
              onThemeChanged: (_) {},
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

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(_buildSettingsSection(backupBusy: true));
    await tester.pump();

    await tester.ensureVisible(find.text('数据备份与恢复'));
    await tester.tap(find.text('数据备份与恢复'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
  });
}

Widget _buildSettingsSection({
  bool backupBusy = false,
  ValueChanged<bool>? onTodoAutoDeleteCompletedChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: HomeSettingsSection(
          promptEnabledFuture: Future.value(true),
          showMoodDotFuture: Future.value(true),
          showMoodTextFuture: Future.value(true),
          showMoodNoteFuture: Future.value(true),
          notificationEnabledFuture: Future.value(false),
          todoAutoDeleteCompletedFuture: Future.value(false),
          backupBusy: backupBusy,
          onPromptChanged: (_) {},
          onShowMoodDotChanged: (_) {},
          onShowMoodTextChanged: (_) {},
          onShowMoodNoteChanged: (_) {},
          onTodoAutoDeleteCompletedChanged:
              onTodoAutoDeleteCompletedChanged ?? (_) {},
          onNotificationSettingsRequested: () {},
          onExportBackup: () {},
          onImportBackup: () {},
          onThemeChanged: (_) {},
        ),
      ),
    ),
  );
}

Future<void> _toggleSettingsCategory(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text(title));
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Future<void> _expectSettingsCategoryToggle(
  WidgetTester tester, {
  required String title,
  required String content,
}) async {
  expect(find.text(content), findsNothing);

  await _toggleSettingsCategory(tester, title);
  expect(find.text(content), findsOneWidget);

  await _toggleSettingsCategory(tester, title);
  expect(find.text(content), findsNothing);
}

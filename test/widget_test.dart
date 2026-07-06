import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/features/mood/domain/mood_entry.dart';
import 'package:ocean_baby/features/mood/ui/mood_page_title.dart';
import 'package:ocean_baby/features/mood/ui/mood_prompt_dialog.dart';

void main() {
  testWidgets('首次心情弹框显示开心、生气、伤心三个选项和底部操作', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoodPromptDialog())),
    );

    expect(find.text('选择今日心情'), findsOneWidget);
    expect(find.text('开心'), findsOneWidget);
    expect(find.text('生气'), findsOneWidget);
    expect(find.text('伤心'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);

    final confirmButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '确定'),
    );
    expect(confirmButton.onPressed, isNull);
  });

  testWidgets('页面大标题旁显示今日心情颜色小圆点和心情文字', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoodTitleView(
            title: '账本',
            mood: MoodType.happy,
            note: '今天状态很好',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('账本'), findsOneWidget);
    expect(find.text('开心'), findsOneWidget);
    expect(find.text('今天状态很好'), findsOneWidget);
    final dot = tester.widget<Container>(
      find.byKey(const ValueKey('mood-title-dot')),
    );
    expect((dot.decoration! as BoxDecoration).color, Colors.green);
    expect(
      tester.getCenter(find.text('开心')).dx,
      greaterThan(
        tester.getCenter(find.byKey(const ValueKey('mood-title-dot'))).dx,
      ),
    );

    await tester.tap(find.byType(MoodTitleView));
    expect(tapped, isTrue);
  });

  testWidgets('页面大标题可以按设置隐藏心情圆点文字和备注', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoodTitleView(
            title: '笔记',
            mood: MoodType.sad,
            note: '今天需要休息',
            showMoodDot: false,
            showMoodText: false,
            showMoodNote: false,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('笔记'), findsOneWidget);
    expect(find.byKey(const ValueKey('mood-title-dot')), findsNothing);
    expect(find.text('伤心'), findsNothing);
    expect(find.text('今天需要休息'), findsNothing);
  });

  testWidgets('心情弹框提供心情原因输入框', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MoodPromptDialog())),
    );

    expect(find.text('心情原因'), findsOneWidget);
    expect(find.text('写下今天心情的原因'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('心情弹框选择心情后点击确定才返回结果', (tester) async {
    MoodPromptResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<MoodPromptResult>(
                  context: context,
                  builder: (_) => const MoodPromptDialog(),
                );
              },
              child: const Text('打开心情弹框'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开心情弹框'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '今天去海边玩');
    await tester.tap(find.widgetWithText(ChoiceChip, '开心'));
    await tester.pumpAndSettle();

    expect(find.text('选择今日心情'), findsOneWidget);
    expect(result, isNull);

    final confirmButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '确定'),
    );
    expect(confirmButton.onPressed, isNotNull);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(result?.mood, MoodType.happy);
    expect(result?.note, '今天去海边玩');
    expect(find.text('选择今日心情'), findsNothing);
  });

  testWidgets('心情弹框点击取消时关闭且不返回结果', (tester) async {
    MoodPromptResult? result;
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<MoodPromptResult>(
                  context: context,
                  builder: (_) => const MoodPromptDialog(),
                );
                completed = true;
              },
              child: const Text('打开心情弹框'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开心情弹框'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(result, isNull);
    expect(find.text('选择今日心情'), findsNothing);
  });
}

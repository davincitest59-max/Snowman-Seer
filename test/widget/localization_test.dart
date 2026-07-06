import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ocean_baby/app/ocean_baby_material_app.dart';

void main() {
  testWidgets('复制粘贴等文本选择菜单使用中文', (tester) async {
    await tester.pumpWidget(
      const OceanBabyMaterialApp(home: Scaffold(body: TextField())),
    );
    await tester.pump();

    final context = tester.element(find.byType(Scaffold).first);
    final localizations = MaterialLocalizations.of(context);

    expect(localizations.copyButtonLabel, '复制');
    expect(localizations.pasteButtonLabel, '粘贴');
    expect(localizations.cutButtonLabel, '剪切');
    expect(localizations.selectAllButtonLabel, '全选');
  });
}

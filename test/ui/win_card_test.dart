import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/ui/widgets/win_card_dialog.dart';

void main() {
  testWidgets('WinCard 组件渲染', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WinCard(
          seal: '通',
          title: '第 47 关 · 通关',
          xpText: '获得经验 +96',
          idioms: const ['水滴石穿 水不停地滴'],
          actions: const [WinCardAction(label: '下一关', primary: true)],
        ),
      ),
    ));
    expect(find.text('通'), findsOneWidget);
    expect(find.text('第 47 关 · 通关'), findsOneWidget);
  });
}

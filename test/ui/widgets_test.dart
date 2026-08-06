import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/ui/widgets/app_seal.dart';
import 'package:idiom_crossword/src/ui/widgets/xp_track.dart';
import 'package:idiom_crossword/src/ui/widgets/primary_button.dart';
import 'package:idiom_crossword/src/ui/widgets/badge_soft.dart';
import 'package:idiom_crossword/src/ui/widgets/app_card.dart';

void main() {
  testWidgets('AppSeal 渲染文本', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: AppSeal('通', size: 48, fontSize: 16)),
    ));
    expect(find.text('通'), findsOneWidget);
  });

  testWidgets('XpTrack 渲染进度条', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: XpTrack(progress: 0.5, height: 8)),
    ));
    expect(find.byType(XpTrack), findsOneWidget);
  });

  testWidgets('PrimaryButton ghost 变体点击回调', (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: PrimaryButton(
          label: '开始挑战',
          onTap: () => tapped = true,
        ),
      ),
    ));
    await tester.tap(find.text('开始挑战'));
    expect(tapped, isTrue);
  });

  testWidgets('BadgeSoft 渲染金徽章', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: BadgeSoft('第 128 期', color: BadgeSoftColor.gold)),
    ));
    expect(find.text('第 128 期'), findsOneWidget);
  });

  testWidgets('AppCard 渲染子组件', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: AppCard(child: Text('内容'))),
    ));
    expect(find.text('内容'), findsOneWidget);
  });
}

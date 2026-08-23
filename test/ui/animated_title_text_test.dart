import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/ui/widgets/animated_title_text.dart';

void main() {
  Widget wrap({required String effectId, bool disableAnimations = false}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: Center(
            child: AnimatedTitleText(
              text: 'Lv.17 · 太子少师',
              effectId: effectId,
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('金榜题名播放展开、鎏金扫光和金色点缀', (tester) async {
    await tester.pumpWidget(wrap(effectId: 'jinbang'));

    expect(
      find.byKey(const ValueKey('title-effect-jinbang-accents')),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('title-effect-jinbang-sweep')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('位列公卿显示朱金文字和祥云且没有卿字金印', (tester) async {
    await tester.pumpWidget(wrap(effectId: 'tianzi'));
    await tester.pumpAndSettle();

    final accents = find.byKey(const ValueKey('title-effect-tianzi-accents'));
    expect(accents, findsOneWidget);
    expect(
      find.byKey(const ValueKey('title-effect-tianzi-seal')),
      findsNothing,
    );

    final idlePainter = tester.widget<CustomPaint>(accents).painter!;
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.pump(const Duration(milliseconds: 800));
    final pulsePainter = tester.widget<CustomPaint>(accents).painter!;
    expect(pulsePainter.shouldRepaint(idlePainter), isTrue);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('减少动态效果时保留静态特效且没有持续动画', (tester) async {
    await tester.pumpWidget(wrap(effectId: 'jinbang', disableAnimations: true));
    await tester.pumpAndSettle();

    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

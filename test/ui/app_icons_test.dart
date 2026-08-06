import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/ui/widgets/app_icons.dart';

void main() {
  testWidgets('AppIcon 渲染指定名称图标', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SizedBox(width: 50, height: 50, child: AppIcon('home'))),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(AppIcon), findsOneWidget);
  });
}

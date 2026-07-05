import 'package:flutter_test/flutter_test.dart';

import 'package:idiom_crossword/main.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const IdiomCrosswordApp());
    expect(find.text('成语填字'), findsOneWidget);
  });
}

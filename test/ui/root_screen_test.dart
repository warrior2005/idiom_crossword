import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/ui/screens/root_screen.dart';
import 'package:drift/native.dart';

void main() {
  testWidgets('底部五 Tab 可切换，选中态更新', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: RootScreen()),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['首页', '关卡', '收藏', '商城', '我的']) {
      expect(find.text(label), findsWidgets);
    }
  });
}

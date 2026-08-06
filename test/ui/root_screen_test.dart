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

  testWidgets('首页书卷小径 tile 切换 Tab 而非 push', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: RootScreen()),
      ),
    );
    await tester.pumpAndSettle();

    IndexedStack stack() => tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack().index, 0);

    // 「士」头像 → 我的 Tab
    await tester.tap(find.text('士'));
    await tester.pumpAndSettle();
    expect(stack().index, 4);

    // 回首页点「选择关卡」→ 切到关卡 Tab
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('选择关卡'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('选择关卡'));
    await tester.pumpAndSettle();
    expect(stack().index, 1);

    // 回首页点「成语收藏」→ 切到收藏 Tab
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('成语收藏'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('成语收藏'));
    await tester.pumpAndSettle();
    expect(stack().index, 2);
  });
}

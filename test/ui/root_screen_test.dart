import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/ui/screens/root_screen.dart';
import 'package:idiom_crossword/src/ui/widgets/app_icons.dart';
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

  testWidgets('首页去除重复入口，两个英雄榜卡片进入对应 Tab', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: RootScreen()),
      ),
    );
    await tester.pumpAndSettle();

    IndexedStack stack() =>
        tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(stack().index, 0);

    // 「士」头像 → 我的 Tab
    await tester.tap(find.text('士'));
    await tester.pumpAndSettle();
    expect(stack().index, 4);

    // 与底部导航重复的入口已移除
    await tester.tap(find.text('首页'));
    await tester.pumpAndSettle();
    expect(find.text('书卷小径'), findsNothing);
    expect(find.text('选择关卡'), findsNothing);
    expect(find.text('成语收藏'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('天下英雄榜'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('天下英雄榜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('天下英雄榜'));
    await tester.pumpAndSettle();
    expect(find.byType(TabBar), findsOneWidget);
    expect(
      DefaultTabController.of(tester.element(find.byType(TabBar))).index,
      0,
    );

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is AppIcon && widget.name == 'back',
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('每周英雄榜'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('每周英雄榜'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('每周英雄榜'));
    await tester.pumpAndSettle();
    expect(
      DefaultTabController.of(tester.element(find.byType(TabBar))).index,
      1,
    );
  });
}

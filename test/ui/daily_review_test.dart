import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';
import 'package:idiom_crossword/src/ui/screens/daily_review_screen.dart';

void main() {
  testWidgets('每日挑战：历史含每日挑战时渲染历期', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    // 造一条昨日每日挑战记录（levelJson 留空 → 历期卡片显示关卡号）
    await db.addLevelHistory(
      levelNumber: dailyLevelOffset + 5,
      xpGained: 20,
      idiomsUsed: const [],
      levelJson: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: DailyReviewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('每日挑战'), findsOneWidget);
    expect(find.text('历期回顾'), findsOneWidget);
    expect(find.textContaining('期 ·'), findsOneWidget);
    expect(find.text('19700106期'), findsOneWidget);
    expect(find.text('重玩今日挑战'), findsOneWidget);
    expect(find.text('次日 0 点刷新'), findsOneWidget);
  });

  testWidgets('每日挑战：历期回顾每页 10 条并支持翻页', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    for (var i = 1; i <= 11; i++) {
      await db.addLevelHistory(
        levelNumber: dailyLevelOffset + i,
        xpGained: 20,
        idiomsUsed: const [],
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: DailyReviewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第 1/2 页'), findsOneWidget);
    await tester.tap(find.text('下一页'));
    await tester.pumpAndSettle();
    expect(find.text('第 2/2 页'), findsOneWidget);
  });
}

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';
import 'package:idiom_crossword/src/ui/screens/daily_review_screen.dart';

void main() {
  testWidgets('每日回顾：历史含每日挑战时渲染历期', (tester) async {
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

    expect(find.text('每日回顾'), findsOneWidget);
    expect(find.text('历期回顾'), findsOneWidget);
    expect(find.text('第 5 期'), findsOneWidget);
    expect(find.text('次日 0 点刷新'), findsOneWidget);
  });
}

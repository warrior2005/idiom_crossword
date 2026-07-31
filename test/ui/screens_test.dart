import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/achievement_manager.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/ui/screens/achievements_screen.dart';
import 'package:idiom_crossword/src/ui/screens/collection_screen.dart';
import 'package:idiom_crossword/src/ui/screens/settings_screen.dart';
import 'package:idiom_crossword/src/ui/screens/shop_screen.dart';
import 'package:idiom_crossword/src/ui/screens/stats_screen.dart';
import 'package:idiom_crossword/src/ui/screens/home_screen.dart';
import 'package:idiom_crossword/src/audio/game_audio.dart';

/// 数据驱动界面的 widget 测试（内存数据库 + Provider 覆盖）

Future<AppDatabase> _memoryDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  await db
      .into(db.idioms)
      .insert(
        IdiomsCompanion(
          word: const Value('画蛇添足'),
          pinyin: const Value('hua she tian zu'),
          pinyinAbbr: const Value('hstz'),
          explanation: const Value('比喻做了多余的事'),
          firstChar: const Value('画'),
          lastChar: const Value('足'),
          difficulty: const Value(5),
        ),
      );
  return db;
}

Widget _wrap(AppDatabase db, Widget child) {
  return ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('收藏页：空态 → 收录后展示成语', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const CollectionScreen()));
    await tester.pumpAndSettle();
    expect(find.text('还没有收藏任何成语'), findsOneWidget);

    final id = await db.findIdiomIdByWord('画蛇添足');
    await db.addToCollection(id!);
    expect(await db.getCollectionWithDetails(), hasLength(1));
    expect((await db.getCollectionWithDetails()).first.word, '画蛇添足');

    // 卸载后重新挂载，让新的 ProviderScope 重新拉取数据
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_wrap(db, const CollectionScreen()));
    await tester.pumpAndSettle();
    expect(find.text('画蛇添足'), findsOneWidget);

    // 搜索过滤：命中保留，未命中显示空态
    await tester.enterText(find.byType(TextField), '画蛇');
    await tester.pumpAndSettle();
    expect(find.text('画蛇添足'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '不存在');
    await tester.pumpAndSettle();
    expect(find.text('没有找到匹配的成语'), findsOneWidget);
  });

  testWidgets('成就页：解锁状态与进度', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const AchievementsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('已解锁 0/8'), findsOneWidget);
    expect(find.text('首战告捷'), findsOneWidget);

    await db.unlockAchievement(AchievementId.firstLevel.name);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_wrap(db, const AchievementsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('已解锁 1/8'), findsOneWidget);
  });

  testWidgets('统计页：展示通关记录明细', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    final id = await db.findIdiomIdByWord('画蛇添足');
    await db.addLevelHistory(
      levelNumber: 7,
      xpGained: 20,
      idiomsUsed: [id!],
      timeSpentMs: 30000,
      hintsUsed: 2,
      errorsMade: 1,
    );

    await tester.pumpWidget(_wrap(db, const StatsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('通关数'), findsOneWidget);
    expect(find.text('第 7 关'), findsOneWidget);
  });

  testWidgets('设置页：音效开关持久化', (tester) async {
    GameAudio.instance.muted = false;
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const SettingsScreen()));
    await tester.pumpAndSettle();

    final switchFinder = find.byType(Switch);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(GameAudio.instance.muted, isTrue);
    expect(await db.getSetting(soundEnabledKey), 'false');
  });

  testWidgets('商城购买按钮提示即将上线', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const ShopScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('¥6'));
    await tester.pump();
    expect(find.text('内购功能即将上线'), findsOneWidget);
  });

  testWidgets('首页：每日挑战在数据库无成语时提示生成失败', (tester) async {
    final db = AppDatabase(NativeDatabase.memory()); // 空库，无成语
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const HomeScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('每日挑战'));
    await tester.pumpAndSettle();
    expect(find.text('每日挑战生成失败，请重试'), findsOneWidget);
  });
}

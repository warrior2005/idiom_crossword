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
import 'package:idiom_crossword/src/ui/widgets/app_seal.dart';
import 'package:idiom_crossword/src/ui/screens/settings_screen.dart';
import 'package:idiom_crossword/src/ui/screens/shop_screen.dart';
import 'package:idiom_crossword/src/ui/screens/stats_screen.dart';
import 'package:idiom_crossword/src/ui/screens/home_screen.dart';
import 'package:idiom_crossword/src/ui/screens/level_select_screen.dart';
import 'package:idiom_crossword/src/ui/screens/learning_screen.dart';
import 'package:idiom_crossword/src/ui/screens/mine_screen.dart';
import 'package:idiom_crossword/src/ui/screens/custom_level_screen.dart';
import 'package:idiom_crossword/src/audio/game_audio.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';

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
    expect(find.text('已解锁 / ${achievementDefs.length} 项'), findsOneWidget);
    expect(find.text('首战告捷'), findsOneWidget);

    await db.unlockAchievement(AchievementId.firstLevel.name);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_wrap(db, const AchievementsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('通'), findsOneWidget);
  });

  testWidgets('成就页：印章与分组渲染', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const AchievementsScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('已解锁'), findsOneWidget);
    expect(find.text('首战告捷'), findsOneWidget);
    expect(find.byType(AppSeal), findsWidgets);
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
    expect(find.text('累计通关'), findsOneWidget);
  });

  testWidgets('统计页：正确率环形与明细', (tester) async {
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
      totalFills: 5,
    );

    await tester.pumpWidget(_wrap(db, const StatsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('累计通关'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget); // (5-1)/5
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

    await tester.tap(find.text('购买').first);
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

  testWidgets('关卡页：PageView 展示关卡，完成后显示通角标', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const LevelSelectScreen()));
    await tester.pumpAndSettle();
    // 无记录：当前关第 1 关
    expect(find.text('选择关卡'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);

    await db.addLevelHistory(levelNumber: 1, xpGained: 10, idiomsUsed: const []);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_wrap(db, const LevelSelectScreen()));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget); // 当前关

    // 点击已解锁的第 1 关 → 空库生成失败提示
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('关卡生成失败，请重试'), findsOneWidget);
  });

  testWidgets('学习模式：展示释义/出处/例句', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);
    await db
        .update(db.idioms)
        .write(
          const IdiomsCompanion(
            derivation: Value('语出《战国策》'),
            example: Value('他画蛇添足，多此一举。'),
          ),
        );

    await tester.pumpWidget(_wrap(db, const LearningScreen(words: ['画蛇添足'])));
    await tester.pumpAndSettle();
    expect(find.text('画蛇添足'), findsOneWidget);
    expect(find.textContaining('语出《战国策》'), findsOneWidget);
    expect(find.textContaining('多此一举'), findsOneWidget);
  });

  testWidgets('首页：每日挑战完成后按钮显示完成态', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);
    await db.addLevelHistory(
      levelNumber: dailyLevelNumber(),
      xpGained: 20,
      idiomsUsed: const [],
    );

    await tester.pumpWidget(_wrap(db, const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('每日挑战 ✓'), findsOneWidget);
  });

  testWidgets('首页：标题与科举仕途卡渲染', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('成语填字'), findsOneWidget);
    expect(find.text('科举仕途'), findsOneWidget);
    expect(find.text('书卷小径'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('今日一读'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('今日一读'), findsOneWidget);
  });

  testWidgets('自定义关卡页：渲染参数控件，空库生成失败提示', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const CustomLevelScreen()));
    await tester.pumpAndSettle();
    expect(find.text('难度区间'), findsOneWidget);
    expect(find.text('成语数量'), findsOneWidget);

    await tester.tap(find.text('开始挑战'));
    await tester.pumpAndSettle();
    expect(find.text('关卡生成失败，请调整参数后重试'), findsOneWidget);
  });

  testWidgets('收藏页：设计卡片样式渲染成语', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);
    final id = await db.findIdiomIdByWord('画蛇添足');
    await db.addToCollection(id!);

    await tester.pumpWidget(_wrap(db, const CollectionScreen()));
    await tester.pumpAndSettle();
    expect(find.text('画蛇添足'), findsOneWidget);
    expect(find.textContaining('共'), findsOneWidget);
  });

  testWidgets('商城页：钱包与分区渲染', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const ShopScreen()));
    await tester.pumpAndSettle();
    expect(find.text('文房四宝 · 商城'), findsOneWidget);
    expect(find.text('提示卡'), findsOneWidget);
    expect(find.text('复活卡'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('功能道具'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('功能道具'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('装饰藏品'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('装饰藏品'), findsOneWidget);
  });

  testWidgets('我的页：等级条三态与菜单', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);
    // 造一条通关记录让玩家为 Lv.1 且已通关 1 关
    await db.addLevelHistory(levelNumber: 1, xpGained: 10, idiomsUsed: const []);

    await tester.pumpWidget(_wrap(db, const MineScreen()));
    await tester.pumpAndSettle();

    expect(find.text('我的'), findsOneWidget);
    expect(find.textContaining('Lv.1'), findsOneWidget);
    expect(find.text('自定义关卡'), findsNothing); // 已删除

    await tester.scrollUntilVisible(find.text('设置'), 100, scrollable: find.byType(Scrollable).first);
    expect(find.text('成就'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}

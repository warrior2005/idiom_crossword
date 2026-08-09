import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/achievement_manager.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/state/level_state_codec.dart';
import 'package:idiom_crossword/src/state/player_state.dart';
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
import 'package:idiom_crossword/src/audio/game_audio.dart';
import 'package:idiom_crossword/src/ui/widgets/user_avatar.dart';
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
    expect(find.text('本周新增 1'), findsOneWidget);

    // 搜索过滤：命中保留，未命中显示空态
    await tester.enterText(find.byType(TextField), '画蛇');
    await tester.pumpAndSettle();
    expect(find.text('画蛇添足'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '比喻做了多余的事');
    await tester.pumpAndSettle();
    expect(find.text('没有找到匹配的成语'), findsOneWidget);
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

  testWidgets('统计页：最长连胜按跨关卡连续答对字数统计', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);
    await db.updatePlayerProgress(
      level: 1,
      totalXp: 10,
      completedLevels: 1,
      hintCards: 0,
      reviveCards: 0,
      bestCorrectStreak: 12,
    );

    await tester.pumpWidget(_wrap(db, const StatsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('12 字'), findsOneWidget);
    expect(find.text('最长连胜 · 连续答对'), findsOneWidget);
  });

  testWidgets('设置页：音效开关持久化', (tester) async {
    GameAudio.instance.muted = false;
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const SettingsScreen()));
    await tester.pumpAndSettle();

    final switchFinder = find.byType(Switch).first;
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(GameAudio.instance.muted, isTrue);
    expect(await db.getSetting(soundEnabledKey), 'false');
  });

  testWidgets('设置页：触感开关持久化，无语言/成语数据库行', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('音效'), findsOneWidget);
    expect(find.text('触感反馈'), findsOneWidget);
    expect(find.text('语言'), findsNothing);
    expect(find.text('成语数据库'), findsNothing);

    final switches = find.byType(Switch);
    expect(tester.widget<Switch>(switches.at(1)).value, isTrue); // 触感默认开
    await tester.tap(switches.at(1));
    await tester.pumpAndSettle();
    expect(await db.getSetting(hapticEnabledKey), 'false');
  });

  testWidgets('商城购买提示卡后库存增加并扣减积分', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(playerProvider.notifier).loadFromDatabase(db);
    await container.read(playerProvider.notifier).addPoints(100);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ShopScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('购买').first);
    await tester.pumpAndSettle();
    expect(find.text('确认购买'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect((await db.getPlayerProgress())!.hintCards, 5);
    expect((await db.getPlayerProgress())!.points, 100);

    await tester.tap(find.text('购买').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认'));
    await tester.pump();
    expect(find.text('购买成功：提示卡 ×1'), findsOneWidget);
    expect((await db.getPlayerProgress())!.hintCards, 6);
    expect((await db.getPlayerProgress())!.points, 90);
  });

  testWidgets('商城切换网格皮肤并持久化', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const ShopScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('宣纸'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('宣纸'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('宣纸'));
    await tester.pump();

    expect(find.text('已切换网格皮肤：宣纸'), findsOneWidget);
    expect(await db.getActiveDecorationId('grid_skin'), 'paper');
  });

  testWidgets('商城等级皮肤未解锁时锁定，广告皮肤积分购买', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(playerProvider.notifier).loadFromDatabase(db);
    await container.read(playerProvider.notifier).addPoints(5000);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ShopScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // 未解锁等级皮肤（竹简 Lv.3）不能切换
    await tester.scrollUntilVisible(
      find.text('竹简'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('竹简'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('竹简'));
    await tester.pump();
    expect(find.text('该皮肤为 Lv.3 升级奖励，达到等级后解锁'), findsOneWidget);
    expect(await db.getActiveDecorationId('grid_skin'), isNull);

    // 清除上一条提示，避免新提示排队
    ScaffoldMessenger.of(
      tester.element(find.byType(ShopScreen)),
    ).clearSnackBars();
    await tester.pumpAndSettle();

    // 广告皮肤秋香 2000 积分购买并切换
    await tester.scrollUntilVisible(
      find.text('秋香'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('秋香'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('秋香'));
    await tester.pumpAndSettle();
    expect(find.text('确认购买'), findsOneWidget);
    await tester.tap(find.text('确认'));
    await tester.pump();
    expect(find.text('已购买并切换网格皮肤：秋香'), findsOneWidget);
    expect((await db.getPlayerProgress())!.points, 3000);
    expect(await db.getActiveDecorationId('grid_skin'), 'qiuxiang');
  });

  testWidgets('商城：头像框已拥有可切换，称号特效未拥有提示解锁', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);
    await db.addDecoration('avatar_frame', 'wusha');
    await db.updatePlayerProgress(
      level: 1,
      totalXp: 0,
      completedLevels: 0,
      hintCards: 0,
      reviveCards: 0,
    );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(playerProvider.notifier).loadFromDatabase(db);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ShopScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('乌纱帽'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('乌纱帽'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('乌纱帽'));
    await tester.pump();
    expect(find.text('已切换头像框：乌纱帽'), findsOneWidget);
    expect(await db.getActiveDecorationId('avatar_frame'), 'wusha');

    // 清除提示，避免新提示排队
    ScaffoldMessenger.of(
      tester.element(find.byType(ShopScreen)),
    ).clearSnackBars();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('金榜题名'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('金榜题名'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('金榜题名'));
    await tester.pump();
    expect(find.text('该称号特效为 Lv.9 升级奖励，达到等级后解锁'), findsOneWidget);
  });

  testWidgets('商城：积分头像框可购买并切换，等级头像框未解锁提示', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(playerProvider.notifier).loadFromDatabase(db);
    await container.read(playerProvider.notifier).addPoints(7000);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: ShopScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('东坡巾'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('东坡巾'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('东坡巾'));
    await tester.pumpAndSettle();
    expect(find.text('确认购买'), findsOneWidget);
    await tester.tap(find.text('确认'));
    await tester.pump();
    expect(find.text('已购买并切换头像框：东坡巾'), findsOneWidget);
    expect((await db.getPlayerProgress())!.points, 5000);
    expect(await db.getActiveDecorationId('avatar_frame'), 'dongpo');

    ScaffoldMessenger.of(
      tester.element(find.byType(ShopScreen)),
    ).clearSnackBars();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('翼善冠'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('翼善冠'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('翼善冠'));
    await tester.pumpAndSettle();
    expect(find.text('确认购买'), findsOneWidget);
    await tester.tap(find.text('确认'));
    await tester.pump();
    expect(find.text('已购买并切换头像框：翼善冠'), findsOneWidget);
    expect((await db.getPlayerProgress())!.points, 0);
    expect(await db.getActiveDecorationId('avatar_frame'), 'yishan');

    ScaffoldMessenger.of(
      tester.element(find.byType(ShopScreen)),
    ).clearSnackBars();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('四方平定巾'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('四方平定巾'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('四方平定巾'));
    await tester.pump();
    expect(find.text('该头像框为 Lv.2 升级奖励，达到等级后解锁'), findsOneWidget);
  });

  testWidgets('商城：积分说明弹窗展示积分规则', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const ShopScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('积分说明'));
    await tester.pumpAndSettle();
    Finder richTextContaining(String text) => find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains(text),
    );
    expect(richTextContaining('激励广告'), findsOneWidget);
    expect(richTextContaining('插屏广告'), findsOneWidget);
    expect(richTextContaining('横幅广告'), findsOneWidget);
  });

  testWidgets('首页：每日挑战在数据库无成语时提示生成失败', (tester) async {
    final db = AppDatabase(NativeDatabase.memory()); // 空库，无成语
    addTearDown(db.close);
    // 每日挑战 Lv.3 开启：Lv1-2 累计经验 100+160=260
    await db.updatePlayerProgress(
      level: 4,
      totalXp: 516,
      completedLevels: 0,
      hintCards: 0,
      reviveCards: 0,
    );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(playerProvider.notifier).loadFromDatabase(db);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始挑战'));
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

    await db.addLevelHistory(
      levelNumber: 1,
      xpGained: 10,
      idiomsUsed: const [],
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_wrap(db, const LevelSelectScreen()));
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget); // 当前关

    // 点击已解锁的第 1 关 → 空库生成失败提示
    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('关卡生成失败，请重试'), findsOneWidget);
  });

  testWidgets('关卡页：每日挑战已完成时不显示置顶卡', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.addLevelHistory(
      levelNumber: dailyLevelNumber(),
      xpGained: 20,
      idiomsUsed: const [],
    );

    await tester.pumpWidget(_wrap(db, const LevelSelectScreen()));
    await tester.pumpAndSettle();

    expect(find.text('每日挑战 · 今日一题'), findsNothing);
  });

  testWidgets('关卡页：选关方块保持正方形', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const LevelSelectScreen()));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(const ValueKey('level-node-1')));
    expect(rect.width, closeTo(rect.height, 0.1));
  });

  testWidgets('关卡页：旧通关记录也能显示成语小字', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);
    final id = await db.findIdiomIdByWord('画蛇添足');
    await db.addLevelHistory(
      levelNumber: 1,
      xpGained: 10,
      idiomsUsed: [id!],
      levelJson: null, // 模拟旧数据没有冻结定义
    );

    await tester.pumpWidget(_wrap(db, const LevelSelectScreen()));
    await tester.pumpAndSettle();

    expect(find.text('画蛇添足'), findsOneWidget);
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

  testWidgets('本关成语：填错词优先展示并显示填错tag', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);
    await db
        .into(db.idioms)
        .insert(
          IdiomsCompanion(
            word: const Value('画龙点睛'),
            pinyin: const Value('hua long dian jing'),
            pinyinAbbr: const Value('hldj'),
            explanation: const Value('比喻在关键处加上精辟的语句'),
            firstChar: const Value('画'),
            lastChar: const Value('睛'),
            difficulty: const Value(1),
          ),
        );

    await tester.pumpWidget(
      _wrap(
        db,
        const LearningScreen(words: ['画蛇添足', '画龙点睛'], wrongWords: {'画蛇添足'}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('填错'), findsOneWidget);
    expect(find.textContaining('难度'), findsNothing);
    final wrongY = tester.getTopLeft(find.text('画蛇添足')).dy;
    final correctY = tester.getTopLeft(find.text('画龙点睛')).dy;
    expect(wrongY, lessThan(correctY));
  });

  testWidgets('首页：每日挑战完成后按钮显示完成态', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);
    await db.addLevelHistory(
      levelNumber: dailyLevelNumber(),
      xpGained: 20,
      idiomsUsed: const [],
    );
    await db.updatePlayerProgress(
      level: 4,
      totalXp: 516,
      completedLevels: 0,
      hintCards: 0,
      reviveCards: 0,
    );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(playerProvider.notifier).loadFromDatabase(db);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已完成'), findsOneWidget);
  });

  testWidgets('首页：未达Lv3时每日挑战显示开启提示', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('到达Lv.3·廪生后开启'), findsOneWidget);
    expect(find.text('开始挑战'), findsNothing);
    expect(find.text('往期回顾'), findsNothing);
  });

  testWidgets('首页：标题与科举仕途卡渲染', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('成语填字'), findsOneWidget);
    expect(find.text('科举仕途'), findsOneWidget);
    expect(find.text('书卷小径'), findsOneWidget);
    expect(find.textContaining('农历'), findsOneWidget);
    expect(find.text('到达Lv.3·廪生后开启'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('今日一读'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('今日一读'), findsOneWidget);
  });

  testWidgets('首页：未开始关卡显示开始，有存档显示继续', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);

    await tester.pumpWidget(_wrap(db, const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('开始第 1 关'), findsOneWidget);

    await db.saveLevelState(
      levelNumber: 1,
      levelJson: '{}',
      stateJson: encodeGameState(
        SavedGameState(
          answers: {(0, 0): '画'},
          usedCandidateSlots: const {},
          fillHistory: const [],
          cellToCandidateSlot: const {},
          candidateBoard: const [[]],
          hintUsesThisLevel: 0,
          errorsMade: 0,
          correctStreak: 0,
          totalFills: 0,
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_wrap(db, const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('继续第 1 关'), findsOneWidget);
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
    expect(find.text('0/100'), findsOneWidget); // 激励广告今日次数（按钮下方）
    await tester.scrollUntilVisible(
      find.text('功能道具'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('功能道具'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('装饰藏品'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('装饰藏品'), findsOneWidget);
  });

  testWidgets('我的页：等级条三态与菜单', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);
    // 造一条通关记录让玩家为 Lv.1 且已通关 1 关
    await db.addLevelHistory(
      levelNumber: 1,
      xpGained: 10,
      idiomsUsed: const [],
    );

    await tester.pumpWidget(_wrap(db, const MineScreen()));
    await tester.pumpAndSettle();

    expect(find.text('我的'), findsOneWidget);
    expect(find.textContaining('Lv.1'), findsOneWidget);
    expect(find.text('自定义关卡'), findsNothing); // 已删除

    await tester.scrollUntilVisible(
      find.text('设置'),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('成就'), findsOneWidget);
    expect(find.text('统计'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('我的页：点头像可打开头像设置并取消自定义头像', (tester) async {
    final db = await _memoryDb();
    addTearDown(db.close);
    await db.updatePlayerProgress(
      level: 1,
      totalXp: 0,
      completedLevels: 0,
      hintCards: 0,
      reviveCards: 0,
    );
    await db.setSetting(kCustomAvatarPathKey, '/tmp/custom_avatar.jpg');

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(playerProvider.notifier).loadFromDatabase(db);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MineScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(UserAvatar));
    await tester.pumpAndSettle();
    expect(find.text('从相册选择'), findsOneWidget);
    expect(find.text('取消自定义头像'), findsOneWidget);

    await tester.tap(find.text('取消自定义头像'));
    await tester.pumpAndSettle();
    expect(container.read(playerProvider).customAvatarPath, '');
    expect(await db.getSetting(kCustomAvatarPathKey), '');
  });
}

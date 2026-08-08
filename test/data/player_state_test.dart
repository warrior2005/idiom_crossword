import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/growth_manager.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';
import 'package:idiom_crossword/src/state/player_state.dart';

/// 玩家成长流程集成测试：通关/升级/奖励/持久化
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('通关获得经验并持久化', () async {
    final notifier = container.read(playerProvider.notifier);
    expect(container.read(playerProvider).level, 1);

    final result = await notifier.completeLevel(1, [5, 5, 5, 5, 5]); // 教学关 10xp
    expect(result.xpGained, 10);
    expect(result.leveledUp, isFalse);

    final state = container.read(playerProvider);
    expect(state.totalXp, 10);
    expect(state.completedLevels, 1);
    expect(state.xpProgress, closeTo(0.1, 0.001)); // 10/100
    expect(state.xpRemaining, 90); // 升 2 级还差 90 经验

    final progress = await db.getPlayerProgress();
    expect(progress, isNotNull);
    expect(progress!.totalXp, 10);
    expect(progress.completedLevels, 1);
  });

  test('升级发放头像框奖励并持久化', () async {
    final notifier = container.read(playerProvider.notifier);
    // 10 个教学关 → 100xp → 升到 2 级（奖励头像框·四方平定巾）
    ExperienceResult? last;
    for (var i = 0; i < 10; i++) {
      last = await notifier.completeLevel(1, [5, 5, 5, 5, 5]);
    }
    expect(last!.leveledUp, isTrue);
    expect(last.newLevel, 2);

    final state = container.read(playerProvider);
    expect(state.level, 2);
    expect(state.title, '生员');
    expect(state.functionalItems['hint_card'] ?? 0, 0);
    expect(state.ownedDecorations, contains('avatar_frame_sifang'));
    expect(state.xpProgress, closeTo(0.0, 0.001)); // 刚升级，本级进度 0

    final progress = await db.getPlayerProgress();
    expect(progress!.level, 2);
    expect(progress.hintCards, 0);
    expect(await db.getOwnedDecorationIds(), contains('avatar_frame_sifang'));
  });

  test('装饰奖励写入数据库', () async {
    final notifier = container.read(playerProvider.notifier);
    // 26 个教学关 → 260xp → 3 级（奖励网格皮肤·竹简）
    for (var i = 0; i < 26; i++) {
      await notifier.completeLevel(1, [5, 5, 5, 5, 5]);
    }
    final state = container.read(playerProvider);
    expect(state.level, 3);
    expect(state.ownedDecorations, contains('grid_skin_bamboo'));
    expect(await db.getOwnedDecorationIds(), contains('grid_skin_bamboo'));
  });

  test('用提示卡扣减并持久化，不会扣成负数', () async {
    final notifier = container.read(playerProvider.notifier);
    await notifier.addHintCards(2);
    expect(container.read(playerProvider).functionalItems['hint_card'], 2);

    await notifier.useHintCard();
    expect(container.read(playerProvider).functionalItems['hint_card'], 1);
    expect((await db.getPlayerProgress())!.hintCards, 1);

    await notifier.useHintCard();
    await notifier.useHintCard();
    await notifier.useHintCard(); // 已用完，不应变负
    expect(container.read(playerProvider).functionalItems['hint_card'], 0);
    expect((await db.getPlayerProgress())!.hintCards, 0);
  });

  test('每日挑战不计入主线已获关卡', () async {
    final notifier = container.read(playerProvider.notifier);

    await notifier.completeLevel(dailyLevelNumber(), [20, 30, 40]);
    expect(container.read(playerProvider).completedLevels, 0);
    expect(container.read(playerProvider).totalXp, 300);

    await notifier.completeLevel(1, [5, 5, 5, 5, 5]);
    expect(container.read(playerProvider).completedLevels, 1);
    expect((await db.getPlayerProgress())!.completedLevels, 1);
  });

  test('载入旧进度时按主线历史修正已获关卡数', () async {
    await db.addLevelHistory(
      levelNumber: 1,
      xpGained: 10,
      idiomsUsed: const [],
    );
    await db.addLevelHistory(
      levelNumber: 2,
      xpGained: 20,
      idiomsUsed: const [],
    );
    await db.addLevelHistory(
      levelNumber: dailyLevelNumber(),
      xpGained: 20,
      idiomsUsed: const [],
    );
    await db.updatePlayerProgress(
      level: 1,
      totalXp: 50,
      completedLevels: 3, // 旧数据把每日挑战也算进去了
      hintCards: 0,
      reviveCards: 0,
    );

    await container.read(playerProvider.notifier).loadFromDatabase(db);

    expect(container.read(playerProvider).completedLevels, 2);
    expect((await db.getPlayerProgress())!.completedLevels, 2);
  });

  test('连续答对跨关卡累计，答错归零并保留最佳', () async {
    final notifier = container.read(playerProvider.notifier);
    for (var i = 0; i < 5; i++) {
      await notifier.recordCorrectFill();
    }
    expect(container.read(playerProvider).currentCorrectStreak, 5);
    expect(container.read(playerProvider).bestCorrectStreak, 5);

    await notifier.recordWrongFill();
    expect(container.read(playerProvider).currentCorrectStreak, 0);
    expect(container.read(playerProvider).bestCorrectStreak, 5);

    for (var i = 0; i < 8; i++) {
      await notifier.recordCorrectFill();
    }
    expect(container.read(playerProvider).currentCorrectStreak, 8);
    expect(container.read(playerProvider).bestCorrectStreak, 8);

    final progress = await db.getPlayerProgress();
    expect(progress!.currentCorrectStreak, 8);
    expect(progress.bestCorrectStreak, 8);
  });

  test('Lv.∞ 后经验继续累加且不再计算下一级', () async {
    var maxXp = 0;
    for (var i = 1; i < GrowthManager.maxLevel; i++) {
      maxXp += GrowthManager.xpForLevel(i);
    }
    await db.updatePlayerProgress(
      level: GrowthManager.maxLevel,
      totalXp: maxXp + 100,
      completedLevels: 7000,
      hintCards: 0,
      reviveCards: 0,
    );
    await container.read(playerProvider.notifier).loadFromDatabase(db);

    final before = container.read(playerProvider).totalXp;
    await container.read(playerProvider.notifier).completeLevel(6000, [
      5,
      5,
      5,
      5,
      5,
    ]);

    final state = container.read(playerProvider);
    expect(state.level, GrowthManager.maxLevel);
    expect(state.totalXp, greaterThan(before));
    expect(state.xpToNextLevel, 0);
    expect(state.xpProgress, 1.0);
    expect(state.xpRemaining, 0);
    expect((await db.getPlayerProgress())!.totalXp, state.totalXp);
  });

  test('商城购买道具增加库存并持久化', () async {
    final notifier = container.read(playerProvider.notifier);
    await notifier.addHintCards(10);
    await notifier.addReviveCards(5);

    expect(container.read(playerProvider).functionalItems['hint_card'], 10);
    expect(container.read(playerProvider).functionalItems['revive_card'], 5);
    final progress = await db.getPlayerProgress();
    expect(progress!.hintCards, 10);
    expect(progress.reviveCards, 5);
  });

  test('积分增加/消费并持久化，积分不足时不扣减', () async {
    final notifier = container.read(playerProvider.notifier);
    await notifier.addPoints(30);
    expect(container.read(playerProvider).points, 30);
    expect((await db.getPlayerProgress())!.points, 30);

    final ok = await notifier.spendPoints(25);
    expect(ok, isTrue);
    expect(container.read(playerProvider).points, 5);
    expect((await db.getPlayerProgress())!.points, 5);

    final fail = await notifier.spendPoints(10);
    expect(fail, isFalse);
    expect(container.read(playerProvider).points, 5);
    expect((await db.getPlayerProgress())!.points, 5);
  });

  test('激励广告：前10次冷却1分钟，之后2分钟，每日上限100次', () async {
    final notifier = container.read(playerProvider.notifier);
    var status = await notifier.rewardedAdStatus();
    expect(status.canWatch, isTrue);
    expect(status.countToday, 0);

    // 每次调用前把上次观看时间拨到 5 分钟前，模拟冷却已结束
    Future<void> expireCooldown() => db.setSetting(
      kRewardedAdsLastTsKey,
      '${DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch}',
    );

    for (var i = 0; i < 9; i++) {
      await expireCooldown();
      status = await notifier.consumeRewardedAd();
      expect(status.countToday, i + 1);
      expect(status.cooldownSeconds, 60);
      expect(status.canWatch, isFalse);
    }

    // 第 10 次后进入 2 分钟冷却档
    await expireCooldown();
    status = await notifier.consumeRewardedAd();
    expect(status.countToday, 10);
    expect(status.cooldownSeconds, 120);

    // 冷却未结束不可观看，也不会增加次数
    final blocked = await notifier.consumeRewardedAd();
    expect(blocked.countToday, 10);
    expect(blocked.canWatch, isFalse);

    // 模拟冷却结束后继续观看，直到达到每日 100 次上限
    for (var i = 10; i < kRewardedAdMaxPerDay; i++) {
      await expireCooldown();
      status = await notifier.consumeRewardedAd();
      expect(status.countToday, i + 1);
      expect(status.canWatch, isFalse);
    }
    expect(status.maxReached, isTrue);
    expect(status.countToday, kRewardedAdMaxPerDay);

    final finalStatus = await notifier.rewardedAdStatus();
    expect(finalStatus.maxReached, isTrue);
    expect(finalStatus.canWatch, isFalse);
    expect(finalStatus.cooldownSeconds, 0);
  });

  test('横幅广告积分按分钟累计，每日上限120', () async {
    final notifier = container.read(playerProvider.notifier);
    for (var i = 0; i < 121; i++) {
      await notifier.addBannerPoints(1);
    }
    expect(container.read(playerProvider).points, kMaxBannerPointsPerDay);
    expect((await db.getPlayerProgress())!.points, kMaxBannerPointsPerDay);
    expect(await db.getSetting(kBannerPointsCountKey), '120');

    // 同日达到上限后不再发放
    final granted = await notifier.addBannerPoints(1);
    expect(granted, 0);
    expect(container.read(playerProvider).points, kMaxBannerPointsPerDay);
  });

  test('设置网格皮肤并持久化', () async {
    final notifier = container.read(playerProvider.notifier);
    await notifier.setActiveGridSkin('bamboo');

    expect(container.read(playerProvider).activeGridSkin, 'bamboo');
    expect(await db.getActiveDecorationId('grid_skin'), 'bamboo');
    expect(await db.getOwnedDecorationIds(), contains('grid_skin_bamboo'));
  });
}

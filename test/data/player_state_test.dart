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

    final result = await notifier.completeLevel(1, [5, 5, 5, 5, 5]); // 教学关 20xp
    expect(result.xpGained, 20);
    expect(result.leveledUp, isFalse);

    final state = container.read(playerProvider);
    expect(state.totalXp, 20);
    expect(state.completedLevels, 1);
    expect(state.xpProgress, closeTo(0.2, 0.001)); // 20/100
    expect(state.xpRemaining, 80); // 升 2 级还差 80 经验

    final progress = await db.getPlayerProgress();
    expect(progress, isNotNull);
    expect(progress!.totalXp, 20);
    expect(progress.completedLevels, 1);
  });

  test('新账号初始库存为 5 提示卡 + 2 复活卡', () {
    final state = container.read(playerProvider);
    expect(state.functionalItems['hint_card'], 5);
    expect(state.functionalItems['revive_card'], 2);
  });

  test('升级发放头像框奖励并持久化', () async {
    final notifier = container.read(playerProvider.notifier);
    // 5 个教学关 → 100xp → 升到 2 级（奖励头像框·四方平定巾）
    ExperienceResult? last;
    for (var i = 0; i < 5; i++) {
      last = await notifier.completeLevel(1, [5, 5, 5, 5, 5]);
    }
    expect(last!.leveledUp, isTrue);
    expect(last.newLevel, 2);

    final state = container.read(playerProvider);
    expect(state.level, 2);
    expect(state.title, '生员');
    expect(state.functionalItems['hint_card'], 5);
    expect(state.ownedDecorations, contains('avatar_frame_sifang'));
    expect(state.xpProgress, closeTo(0.0, 0.001)); // 刚升级，本级进度 0

    final progress = await db.getPlayerProgress();
    expect(progress!.level, 2);
    expect(progress.hintCards, 5);
    expect(await db.getOwnedDecorationIds(), contains('avatar_frame_sifang'));
  });

  test('装饰奖励写入数据库', () async {
    final notifier = container.read(playerProvider.notifier);
    // 13 个教学关 → 260xp → 3 级（奖励网格皮肤·竹简）
    for (var i = 0; i < 13; i++) {
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
    expect(container.read(playerProvider).functionalItems['hint_card'], 7);

    await notifier.useHintCard();
    expect(container.read(playerProvider).functionalItems['hint_card'], 6);
    expect((await db.getPlayerProgress())!.hintCards, 6);

    for (var i = 0; i < 6; i++) {
      await notifier.useHintCard();
    }
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

    expect(container.read(playerProvider).functionalItems['hint_card'], 15);
    expect(container.read(playerProvider).functionalItems['revive_card'], 7);
    final progress = await db.getPlayerProgress();
    expect(progress!.hintCards, 15);
    expect(progress.reviveCards, 7);
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

  test('每日登录奖励按七日周期发放并在第8天循环', () async {
    final notifier = container.read(playerProvider.notifier);
    const expectedRewards = [
      '提示卡 ×1',
      '提示卡 ×2',
      '提示卡 ×3',
      '提示卡 ×3、复活卡 ×1',
      '50 积分',
      '80 积分',
      '100 积分',
      '提示卡 ×1',
      '提示卡 ×2',
    ];

    for (var i = 0; i < expectedRewards.length; i++) {
      final claim = await notifier.claimDailyLoginReward(
        now: DateTime(2026, 8, i + 1, 12),
      );
      expect(claim, isNotNull);
      expect(claim!.streakDay, i + 1);
      expect(claim.reward.label, expectedRewards[i]);
    }

    final state = container.read(playerProvider);
    expect(state.functionalItems['hint_card'], 17);
    expect(state.functionalItems['revive_card'], 3);
    expect(state.points, 230);
    final progress = await db.getPlayerProgress();
    expect(progress!.hintCards, 17);
    expect(progress.reviveCards, 3);
    expect(progress.points, 230);
    expect(await db.getSetting(kDailyLoginStreakKey), '9');
  });

  test('每日登录奖励同日不重复发放，断签后重置为第1天', () async {
    final notifier = container.read(playerProvider.notifier);

    final first = await notifier.claimDailyLoginReward(
      now: DateTime(2026, 8, 20, 8),
    );
    final restartedContainer = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(restartedContainer.dispose);
    final restartedNotifier = restartedContainer.read(playerProvider.notifier);
    await restartedNotifier.loadFromDatabase(db);

    final duplicate = await restartedNotifier.claimDailyLoginReward(
      now: DateTime(2026, 8, 20, 20),
    );
    final afterGap = await restartedNotifier.claimDailyLoginReward(
      now: DateTime(2026, 8, 22, 8),
    );

    expect(first!.streakDay, 1);
    expect(duplicate, isNull);
    expect(afterGap!.streakDay, 1);
    expect(afterGap.reward.label, '提示卡 ×1');
    expect(
      restartedContainer.read(playerProvider).functionalItems['hint_card'],
      7,
    );
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

  test('自定义头像设置与取消持久化', () async {
    final notifier = container.read(playerProvider.notifier);
    await notifier.setCustomAvatar('/tmp/custom_avatar.jpg');

    expect(
      container.read(playerProvider).customAvatarPath,
      '/tmp/custom_avatar.jpg',
    );
    expect(await db.getSetting(kCustomAvatarPathKey), '/tmp/custom_avatar.jpg');

    await notifier.clearCustomAvatar();
    expect(container.read(playerProvider).customAvatarPath, '');
    expect(await db.getSetting(kCustomAvatarPathKey), '');
  });
}

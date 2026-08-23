import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import '../data/achievement_manager.dart';
import '../data/database.dart';
import '../data/growth_manager.dart';
import 'game_center_service.dart';
import 'level_generation.dart';

/// 激励广告配额与冷却常量
const int kRewardedAdMaxPerDay = 100;

/// 前 10 次激励广告使用 1 分钟冷却，之后为 2 分钟
const int kRewardedAdFirstCount = 10;
const int kRewardedAdFirstCooldownSeconds = 60;
const int kRewardedAdLaterCooldownSeconds = 120;

/// 每则激励广告奖励积分（按激励广告 eCPM 估算，可后续调整）
const int kRewardedAdPointsReward = 3;

/// 完成插页式激励广告后奖励积分。
const int kRewardedInterstitialAdPointsReward = 2;

/// 横幅广告每观看 1 分钟奖励 1 积分，每日上限 120 积分
const int kMaxBannerPointsPerDay = 120;

const String kRewardedAdsDateKey = 'rewarded_ads_date';
const String kRewardedAdsCountKey = 'rewarded_ads_count';
const String kRewardedAdsLastTsKey = 'rewarded_ads_last_ts';
const int kDailyReviveLimit = 10;
const String kDailyReviveDateKey = 'daily_revive_date';
const String kDailyAdReviveCountKey = 'daily_ad_revive_count';
const String kDailyShareReviveCountKey = 'daily_share_revive_count';
const String kBannerPointsDateKey = 'banner_points_date';
const String kBannerPointsCountKey = 'banner_points_count';
const String kCustomAvatarPathKey = 'custom_avatar_path';
const String kActiveBackgroundKey = 'active_background';

/// 积分定价（与商城一致）
const int kHintCardPoints = 10;
const int kReviveCardPoints = 15;
const int kGiftBoxPoints = 40;

const String kDailyLoginLastDateKey = 'daily_login_last_date';
const String kDailyLoginStreakKey = 'daily_login_streak';
const String _achievementRewardKeyPrefix = 'achievement_reward_claimed_';

class DailyLoginReward {
  final int hintCards;
  final int reviveCards;
  final int points;

  const DailyLoginReward({
    this.hintCards = 0,
    this.reviveCards = 0,
    this.points = 0,
  });

  String get label => [
    if (hintCards > 0) '提示卡 ×$hintCards',
    if (reviveCards > 0) '复活卡 ×$reviveCards',
    if (points > 0) '$points 积分',
  ].join('、');
}

class DailyLoginClaim {
  final int streakDay;
  final DailyLoginReward reward;
  final DailyLoginReward nextReward;

  const DailyLoginClaim({
    required this.streakDay,
    required this.reward,
    required this.nextReward,
  });
}

const List<DailyLoginReward> kDailyLoginRewards = [
  DailyLoginReward(hintCards: 1),
  DailyLoginReward(hintCards: 2),
  DailyLoginReward(hintCards: 3),
  DailyLoginReward(hintCards: 3, reviveCards: 1),
  DailyLoginReward(points: 50),
  DailyLoginReward(points: 80),
  DailyLoginReward(points: 100),
];

/// 激励广告当前可用状态
class RewardedAdStatus {
  final int countToday;
  final int cooldownSeconds;
  final bool canWatch;
  final bool maxReached;

  const RewardedAdStatus({
    required this.countToday,
    required this.cooldownSeconds,
    required this.canWatch,
    required this.maxReached,
  });
}

enum DailyReviveMethod { ad, share }

class DailyReviveQuota {
  final int adRemaining;
  final int shareRemaining;

  const DailyReviveQuota({
    required this.adRemaining,
    required this.shareRemaining,
  });
}

class PlayerState {
  final int level;
  final int totalXp;
  final int xpToNextLevel;
  final String title;
  final int points;
  final int completedLevels;
  final int currentCorrectStreak;
  final int bestCorrectStreak;
  final Map<String, int> functionalItems;
  final Set<String> ownedDecorations;
  final String activeGridSkin;
  final String activeBackground;
  final String? activeAvatarFrame;
  final String? customAvatarPath;
  final String? activeTitleEffect;

  const PlayerState({
    required this.level,
    required this.totalXp,
    required this.xpToNextLevel,
    required this.title,
    required this.points,
    required this.completedLevels,
    required this.currentCorrectStreak,
    required this.bestCorrectStreak,
    required this.functionalItems,
    required this.ownedDecorations,
    required this.activeGridSkin,
    this.activeBackground = 'default',
    required this.activeAvatarFrame,
    this.customAvatarPath,
    required this.activeTitleEffect,
  });

  double get xpProgress {
    if (xpToNextLevel == 0) return 1.0;
    final currentLevelXp = totalXp - _xpForPreviousLevels();
    return currentLevelXp / xpToNextLevel;
  }

  /// 距离升级还差多少经验
  int get xpRemaining {
    final currentLevelXp = totalXp - _xpForPreviousLevels();
    final remaining = xpToNextLevel - currentLevelXp;
    return remaining < 0 ? 0 : remaining;
  }

  PlayerState copyWith({
    int? level,
    int? totalXp,
    int? xpToNextLevel,
    String? title,
    int? points,
    int? completedLevels,
    int? currentCorrectStreak,
    int? bestCorrectStreak,
    Map<String, int>? functionalItems,
    Set<String>? ownedDecorations,
    String? activeGridSkin,
    String? activeBackground,
    String? activeAvatarFrame,
    String? customAvatarPath,
    String? activeTitleEffect,
  }) {
    return PlayerState(
      level: level ?? this.level,
      totalXp: totalXp ?? this.totalXp,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
      title: title ?? this.title,
      points: points ?? this.points,
      completedLevels: completedLevels ?? this.completedLevels,
      currentCorrectStreak: currentCorrectStreak ?? this.currentCorrectStreak,
      bestCorrectStreak: bestCorrectStreak ?? this.bestCorrectStreak,
      functionalItems: functionalItems ?? this.functionalItems,
      ownedDecorations: ownedDecorations ?? this.ownedDecorations,
      activeGridSkin: activeGridSkin ?? this.activeGridSkin,
      activeBackground: activeBackground ?? this.activeBackground,
      activeAvatarFrame: activeAvatarFrame ?? this.activeAvatarFrame,
      customAvatarPath: customAvatarPath ?? this.customAvatarPath,
      activeTitleEffect: activeTitleEffect ?? this.activeTitleEffect,
    );
  }

  int _xpForPreviousLevels() {
    int total = 0;
    for (int i = 1; i < level; i++) {
      total += GrowthManager.xpForLevel(i);
    }
    return total;
  }
}

class PlayerNotifier extends Notifier<PlayerState> {
  @override
  PlayerState build() {
    return const PlayerState(
      level: 1,
      totalXp: 0,
      xpToNextLevel: 100,
      title: '童生',
      points: 0,
      completedLevels: 0,
      currentCorrectStreak: 0,
      bestCorrectStreak: 0,
      functionalItems: {'hint_card': 5, 'revive_card': 2},
      ownedDecorations: {},
      activeGridSkin: 'paper',
      activeBackground: 'default',
      activeAvatarFrame: null,
      activeTitleEffect: null,
    );
  }

  /// 从数据库加载已保存的进度（应用启动时调用一次）
  Future<void> loadFromDatabase(AppDatabase db) async {
    final progress = await db.getPlayerProgress();
    if (progress == null) return;
    // 每日挑战不计入主线已获关卡；旧数据若把每日也累加过，这里按主线历史修正。
    final mainCompleted = await db.getCompletedLevelNumbers();
    if (progress.completedLevels != mainCompleted.length) {
      await db.updatePlayerProgress(
        level: progress.level,
        totalXp: progress.totalXp,
        completedLevels: mainCompleted.length,
        hintCards: progress.hintCards,
        reviveCards: progress.reviveCards,
        currentCorrectStreak: progress.currentCorrectStreak,
        bestCorrectStreak: progress.bestCorrectStreak,
      );
    }
    var owned = await db.getOwnedDecorationIds();
    // 旧版 Lv.18 奖励“三公”已更名为“忠靖冠”，已有存档迁移到新 id。
    if (owned.contains('avatar_frame_sangong')) {
      await db.addDecoration('avatar_frame', 'zhongjing');
      owned = {...owned}
        ..remove('avatar_frame_sangong')
        ..add('avatar_frame_zhongjing');
    }
    // 补齐历史存档中按等级应已解锁的装饰奖励（含新增的 Lv.2/Lv.18/Lv.21 头像框）。
    for (var level = 1; level <= progress.level; level++) {
      final reward = GrowthManager.rewardForLevel(level);
      if (reward == null || reward.type != RewardType.decoration) continue;
      if (owned.contains(reward.item)) continue;
      final (type, id) = _splitDecorationId(reward.item);
      await db.addDecoration(type, id);
      owned = {...owned, reward.item};
    }
    var activeAvatarFrame = await db.getActiveDecorationId('avatar_frame');
    if (activeAvatarFrame == 'sangong') {
      await db.setActiveDecoration('avatar_frame', 'zhongjing');
      activeAvatarFrame = 'zhongjing';
    }
    final savedAvatar = await db.getSetting(kCustomAvatarPathKey);
    final customAvatarPath = (savedAvatar == null || savedAvatar.isEmpty)
        ? null
        : savedAvatar;
    final savedBackground = await db.getSetting(kActiveBackgroundKey);
    final activeBackground =
        (savedBackground == null || savedBackground.isEmpty)
        ? 'default'
        : savedBackground;

    state = PlayerState(
      level: progress.level,
      totalXp: progress.totalXp,
      xpToNextLevel: progress.level >= GrowthManager.maxLevel
          ? 0
          : GrowthManager.xpForLevel(progress.level),
      title: GrowthManager.titleForLevel(progress.level),
      points: progress.points,
      completedLevels: mainCompleted.length,
      currentCorrectStreak: progress.currentCorrectStreak,
      bestCorrectStreak: progress.bestCorrectStreak,
      functionalItems: {
        'hint_card': progress.hintCards,
        'revive_card': progress.reviveCards,
      },
      ownedDecorations: owned,
      activeGridSkin: await db.getActiveDecorationId('grid_skin') ?? 'paper',
      activeBackground: activeBackground,
      activeAvatarFrame: activeAvatarFrame,
      customAvatarPath: customAvatarPath,
      activeTitleEffect: await db.getActiveDecorationId('title_effect'),
    );
  }

  Future<ExperienceResult> completeLevel(
    int levelNumber,
    List<int> idiomDifficulties,
  ) async {
    final xp = GrowthManager.calculateXp(levelNumber, idiomDifficulties);
    final oldLevel = state.level;
    final newTotalXp = state.totalXp + xp;
    final newLevel = GrowthManager.levelFromXp(newTotalXp);
    final leveledUp = newLevel > oldLevel;
    final reward = leveledUp ? GrowthManager.rewardForLevel(newLevel) : null;
    final isDaily = levelNumber >= dailyLevelOffset;

    state = state.copyWith(
      level: newLevel,
      totalXp: newTotalXp,
      xpToNextLevel: newLevel >= GrowthManager.maxLevel
          ? 0
          : GrowthManager.xpForLevel(newLevel),
      title: GrowthManager.titleForLevel(newLevel),
      completedLevels: isDaily
          ? state.completedLevels
          : state.completedLevels + 1,
      functionalItems: _applyReward(state.functionalItems, reward),
      ownedDecorations: _applyDecorationReward(state.ownedDecorations, reward),
    );

    final db = ref.read(databaseProvider);
    await _persist(db);
    if (reward != null && reward.type == RewardType.decoration) {
      final (type, id) = _splitDecorationId(reward.item);
      await db.addDecoration(type, id);
    }

    return ExperienceResult(
      xpGained: xp,
      leveledUp: leveledUp,
      newLevel: newLevel,
      reward: reward,
    );
  }

  /// 记录一次答对：跨关卡连续连胜 +1，并刷新历史最佳
  Future<void> recordCorrectFill() async {
    final current = state.currentCorrectStreak + 1;
    final best = state.bestCorrectStreak < current
        ? current
        : state.bestCorrectStreak;
    state = state.copyWith(
      currentCorrectStreak: current,
      bestCorrectStreak: best,
    );
    await ref
        .read(databaseProvider)
        .updatePlayerStreak(
          currentCorrectStreak: current,
          bestCorrectStreak: best,
        );
  }

  /// 记录一次答错：连续连胜归零
  Future<void> recordWrongFill() async {
    if (state.currentCorrectStreak == 0) return;
    state = state.copyWith(currentCorrectStreak: 0);
    await ref
        .read(databaseProvider)
        .updatePlayerStreak(
          currentCorrectStreak: 0,
          bestCorrectStreak: state.bestCorrectStreak,
        );
  }

  /// 恢复存档时同步连续答对字数
  Future<void> setCorrectStreak(int value) async {
    final best = value > state.bestCorrectStreak
        ? value
        : state.bestCorrectStreak;
    state = state.copyWith(
      currentCorrectStreak: value,
      bestCorrectStreak: best,
    );
    await ref
        .read(databaseProvider)
        .updatePlayerStreak(
          currentCorrectStreak: value,
          bestCorrectStreak: best,
        );
  }

  /// 把当前状态写回数据库
  Future<void> _persist(AppDatabase db) {
    return _persistState(db, state);
  }

  Future<void> _persistState(AppDatabase db, PlayerState playerState) {
    return db.updatePlayerProgress(
      level: playerState.level,
      totalXp: playerState.totalXp,
      completedLevels: playerState.completedLevels,
      hintCards: playerState.functionalItems['hint_card'] ?? 0,
      reviveCards: playerState.functionalItems['revive_card'] ?? 0,
      currentCorrectStreak: playerState.currentCorrectStreak,
      bestCorrectStreak: playerState.bestCorrectStreak,
      points: playerState.points,
    );
  }

  /// 发放当日首次登录奖励；当天已领取时返回 null。
  Future<DailyLoginClaim?> claimDailyLoginReward({DateTime? now}) async {
    final db = ref.read(databaseProvider);
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final todayKey = _dateKey(today);
    final yesterdayKey = _dateKey(
      DateTime(today.year, today.month, today.day - 1),
    );
    DailyLoginClaim? claim;
    PlayerState? claimedState;

    await db.transaction(() async {
      final lastDate = await db.getSetting(kDailyLoginLastDateKey);
      if (lastDate == todayKey) return;

      final savedStreak =
          int.tryParse(await db.getSetting(kDailyLoginStreakKey) ?? '0') ?? 0;
      final streakDay = lastDate == yesterdayKey && savedStreak > 0
          ? savedStreak + 1
          : 1;
      final reward =
          kDailyLoginRewards[(streakDay - 1) % kDailyLoginRewards.length];
      final nextReward =
          kDailyLoginRewards[streakDay % kDailyLoginRewards.length];
      final nextState = state.copyWith(
        points: state.points + reward.points,
        functionalItems: {
          ...state.functionalItems,
          'hint_card':
              (state.functionalItems['hint_card'] ?? 0) + reward.hintCards,
          'revive_card':
              (state.functionalItems['revive_card'] ?? 0) + reward.reviveCards,
        },
      );

      await _persistState(db, nextState);
      await db.setSetting(kDailyLoginLastDateKey, todayKey);
      await db.setSetting(kDailyLoginStreakKey, '$streakDay');
      claimedState = nextState;
      claim = DailyLoginClaim(
        streakDay: streakDay,
        reward: reward,
        nextReward: nextReward,
      );
    });

    if (claimedState case final nextState?) state = nextState;
    return claim;
  }

  /// 增加积分（广告奖励、活动奖励等）
  Future<void> addPoints(int amount) async {
    if (amount <= 0) return;
    state = state.copyWith(points: state.points + amount);
    await _persist(ref.read(databaseProvider));
  }

  /// 解锁成就并发放一次对应积分奖励。
  Future<bool> unlockAchievement(AchievementId id) async {
    final db = ref.read(databaseProvider);
    final isNew = await GameCenterService.unlockAchievement(db, id);
    await _claimAchievementReward(id);
    return isNew;
  }

  /// 为旧存档或 Game Center 同步回来的成就补发尚未领取的积分。
  Future<int> claimUnlockedAchievementRewards() async {
    final unlocked = await ref
        .read(databaseProvider)
        .getUnlockedAchievementIds();
    var total = 0;
    for (final definition in achievementDefs) {
      if (unlocked.contains(definition.id.name)) {
        total += await _claimAchievementReward(definition.id);
      }
    }
    return total;
  }

  Future<int> _claimAchievementReward(AchievementId id) async {
    final db = ref.read(databaseProvider);
    final key = '$_achievementRewardKeyPrefix${id.name}';
    final definition = achievementDefFor(id);
    PlayerState? rewardedState;

    await db.transaction(() async {
      if (await db.getSetting(key) == 'true') return;
      final unlocked = await db.getUnlockedAchievementIds();
      if (!unlocked.contains(id.name)) return;
      final savedPoints =
          (await db.getPlayerProgress())?.points ?? state.points;
      rewardedState = state.copyWith(points: savedPoints + definition.points);
      await _persistState(db, rewardedState!);
      await db.setSetting(key, 'true');
    });

    if (rewardedState == null) return 0;
    state = rewardedState!;
    return definition.points;
  }

  /// 横幅广告积分：按分钟累计，受每日上限约束；返回实际发放的积分
  Future<int> addBannerPoints(int amount) async {
    if (amount <= 0) return 0;
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final today = _dateKey(now);
    final savedDate = await db.getSetting(kBannerPointsDateKey);
    if (savedDate != today) {
      final granted = min(amount, kMaxBannerPointsPerDay);
      await db.setSetting(kBannerPointsDateKey, today);
      await db.setSetting(kBannerPointsCountKey, '$granted');
      if (granted > 0) await addPoints(granted);
      return granted;
    }
    final used =
        int.tryParse(await db.getSetting(kBannerPointsCountKey) ?? '0') ?? 0;
    if (used >= kMaxBannerPointsPerDay) return 0;
    final granted = min(amount, kMaxBannerPointsPerDay - used);
    await db.setSetting(kBannerPointsCountKey, '${used + granted}');
    if (granted > 0) await addPoints(granted);
    return granted;
  }

  /// 消耗积分购买道具/装饰；积分不足返回 false
  Future<bool> spendPoints(int amount) async {
    if (amount <= 0 || state.points < amount) return false;
    state = state.copyWith(points: state.points - amount);
    await _persist(ref.read(databaseProvider));
    return true;
  }

  /// 解锁网格皮肤（购买后加入拥有集合并写入数据库）
  Future<void> unlockGridSkin(String id) async {
    state = state.copyWith(
      ownedDecorations: {...state.ownedDecorations, 'grid_skin_$id'},
    );
    await ref.read(databaseProvider).addDecoration('grid_skin', id);
  }

  /// 解锁头像框（购买后加入拥有集合并写入数据库）
  Future<void> unlockAvatarFrame(String id) async {
    state = state.copyWith(
      ownedDecorations: {...state.ownedDecorations, 'avatar_frame_$id'},
    );
    await ref.read(databaseProvider).addDecoration('avatar_frame', id);
  }

  String _dateKey(DateTime time) {
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    return '${time.year}-$m-$d';
  }

  /// 查询激励广告今日次数、剩余冷却与是否可观看
  Future<RewardedAdStatus> rewardedAdStatus() async {
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final today = _dateKey(now);
    final savedDate = await db.getSetting(kRewardedAdsDateKey);
    if (savedDate != today) {
      return const RewardedAdStatus(
        countToday: 0,
        cooldownSeconds: 0,
        canWatch: true,
        maxReached: false,
      );
    }
    final count =
        int.tryParse(await db.getSetting(kRewardedAdsCountKey) ?? '0') ?? 0;
    final lastTs =
        int.tryParse(await db.getSetting(kRewardedAdsLastTsKey) ?? '0') ?? 0;
    final maxReached = count >= kRewardedAdMaxPerDay;
    final cooldown = count < kRewardedAdFirstCount
        ? kRewardedAdFirstCooldownSeconds
        : kRewardedAdLaterCooldownSeconds;
    final remainingMs =
        (cooldown * 1000 - (now.millisecondsSinceEpoch - lastTs)).clamp(
          0,
          cooldown * 1000,
        );
    final cooldownSeconds = maxReached ? 0 : (remainingMs / 1000).ceil();
    return RewardedAdStatus(
      countToday: count,
      cooldownSeconds: cooldownSeconds,
      canWatch: !maxReached && cooldownSeconds <= 0,
      maxReached: maxReached,
    );
  }

  /// 记录一则激励广告已观看，返回观看后的最新状态
  Future<RewardedAdStatus> consumeRewardedAd() async {
    final db = ref.read(databaseProvider);
    final before = await rewardedAdStatus();
    if (!before.canWatch) return before;
    final now = DateTime.now();
    final count = before.countToday + 1;
    await db.setSetting(kRewardedAdsDateKey, _dateKey(now));
    await db.setSetting(kRewardedAdsCountKey, '$count');
    await db.setSetting(kRewardedAdsLastTsKey, '${now.millisecondsSinceEpoch}');
    final maxReached = count >= kRewardedAdMaxPerDay;
    return RewardedAdStatus(
      countToday: count,
      cooldownSeconds: maxReached
          ? 0
          : count < kRewardedAdFirstCount
          ? kRewardedAdFirstCooldownSeconds
          : kRewardedAdLaterCooldownSeconds,
      canWatch: false,
      maxReached: maxReached,
    );
  }

  /// 广告与分享复活的每日剩余额度（所有关卡共享）。
  Future<DailyReviveQuota> dailyReviveQuota({DateTime? now}) async {
    final db = ref.read(databaseProvider);
    final current = now ?? DateTime.now();
    final savedDate = await db.getSetting(kDailyReviveDateKey);
    if (savedDate != _dateKey(current)) {
      return const DailyReviveQuota(
        adRemaining: kDailyReviveLimit,
        shareRemaining: kDailyReviveLimit,
      );
    }
    final adUsed =
        (int.tryParse(await db.getSetting(kDailyAdReviveCountKey) ?? '0') ?? 0)
            .clamp(0, kDailyReviveLimit);
    final shareUsed =
        (int.tryParse(await db.getSetting(kDailyShareReviveCountKey) ?? '0') ??
                0)
            .clamp(0, kDailyReviveLimit);
    return DailyReviveQuota(
      adRemaining: kDailyReviveLimit - adUsed,
      shareRemaining: kDailyReviveLimit - shareUsed,
    );
  }

  /// 消耗一次每日复活额度；额度用尽时返回 false。
  Future<bool> consumeDailyRevive(
    DailyReviveMethod method, {
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final quota = await dailyReviveQuota(now: current);
    if ((method == DailyReviveMethod.ad && quota.adRemaining <= 0) ||
        (method == DailyReviveMethod.share && quota.shareRemaining <= 0)) {
      return false;
    }

    final adUsed =
        kDailyReviveLimit -
        quota.adRemaining +
        (method == DailyReviveMethod.ad ? 1 : 0);
    final shareUsed =
        kDailyReviveLimit -
        quota.shareRemaining +
        (method == DailyReviveMethod.share ? 1 : 0);
    final db = ref.read(databaseProvider);
    await db.setSetting(kDailyReviveDateKey, _dateKey(current));
    await db.setSetting(kDailyAdReviveCountKey, '$adUsed');
    await db.setSetting(kDailyShareReviveCountKey, '$shareUsed');
    return true;
  }

  /// 'grid_skin_bamboo' -> ('grid_skin', 'bamboo')
  (String, String) _splitDecorationId(String item) {
    final sep = item.lastIndexOf('_');
    if (sep <= 0) return (item, '');
    return (item.substring(0, sep), item.substring(sep + 1));
  }

  Map<String, int> _applyReward(Map<String, int> items, LevelReward? reward) {
    if (reward == null || reward.type != RewardType.functional) return items;
    final updated = Map<String, int>.from(items);
    updated[reward.item] = (updated[reward.item] ?? 0) + reward.quantity;
    return updated;
  }

  Set<String> _applyDecorationReward(Set<String> owned, LevelReward? reward) {
    if (reward == null || reward.type != RewardType.decoration) return owned;
    return {...owned, reward.item};
  }

  Future<void> useHintCard() async {
    final current = state.functionalItems['hint_card'] ?? 0;
    if (current > 0) {
      state = state.copyWith(
        functionalItems: {...state.functionalItems, 'hint_card': current - 1},
      );
      await _persist(ref.read(databaseProvider));
    }
  }

  Future<void> useReviveCard() async {
    final current = state.functionalItems['revive_card'] ?? 0;
    if (current > 0) {
      state = state.copyWith(
        functionalItems: {...state.functionalItems, 'revive_card': current - 1},
      );
      await _persist(ref.read(databaseProvider));
    }
  }

  Future<void> addHintCards(int count) async {
    if (count <= 0) return;
    final current = state.functionalItems['hint_card'] ?? 0;
    state = state.copyWith(
      functionalItems: {...state.functionalItems, 'hint_card': current + count},
    );
    await _persist(ref.read(databaseProvider));
  }

  Future<void> addReviveCards(int count) async {
    if (count <= 0) return;
    final current = state.functionalItems['revive_card'] ?? 0;
    state = state.copyWith(
      functionalItems: {
        ...state.functionalItems,
        'revive_card': current + count,
      },
    );
    await _persist(ref.read(databaseProvider));
  }

  Future<void> setActiveGridSkin(String id) async {
    state = state.copyWith(activeGridSkin: id);
    await ref.read(databaseProvider).setActiveDecoration('grid_skin', id);
  }

  /// 解锁游戏背景（购买后加入拥有集合并写入数据库）
  Future<void> unlockBackground(String id) async {
    state = state.copyWith(
      ownedDecorations: {...state.ownedDecorations, 'background_$id'},
    );
    await ref.read(databaseProvider).addDecoration('background', id);
  }

  /// 切换当前游戏背景
  Future<void> setActiveBackground(String id) async {
    state = state.copyWith(activeBackground: id);
    await ref.read(databaseProvider).setSetting(kActiveBackgroundKey, id);
  }

  Future<void> setActiveAvatarFrame(String id) async {
    state = state.copyWith(activeAvatarFrame: id);
    await ref.read(databaseProvider).setActiveDecoration('avatar_frame', id);
  }

  /// 设置自定义头像（图片已由调用方复制到持久目录）
  Future<void> setCustomAvatar(String path) async {
    state = state.copyWith(customAvatarPath: path);
    await ref.read(databaseProvider).setSetting(kCustomAvatarPathKey, path);
  }

  /// 取消自定义头像，恢复默认“士/官/卿/相/公/龙”印章
  Future<void> clearCustomAvatar() async {
    state = state.copyWith(customAvatarPath: '');
    await ref.read(databaseProvider).setSetting(kCustomAvatarPathKey, '');
  }

  Future<void> setActiveTitleEffect(String id) async {
    state = state.copyWith(activeTitleEffect: id);
    await ref.read(databaseProvider).setActiveDecoration('title_effect', id);
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

/// 下一个主线关卡（排除每日挑战号段）
final nextMainLevelProvider = FutureProvider<int>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  return db.getNextMainLevel();
});

import 'dart:math';

/// 成长系统管理器
///
/// 负责：
/// - 经验值计算（暴雪式指数曲线）
/// - 等级判定
/// - 升级奖励
/// - 称号管理

enum RewardType { functional, decoration }

class LevelReward {
  final RewardType type;
  final String item;
  final int quantity;

  const LevelReward({
    required this.type,
    required this.item,
    required this.quantity,
  });
}

class ExperienceResult {
  final int xpGained;
  final bool leveledUp;
  final int newLevel;
  final LevelReward? reward;

  const ExperienceResult({
    required this.xpGained,
    required this.leveledUp,
    required this.newLevel,
    this.reward,
  });
}

class GrowthManager {
  /// 每日挑战专用关卡号段起点（与 level_generation.dailyLevelOffset 保持一致）
  static const int dailyChallengeLevelOffset = 1000000;

  /// 每日挑战固定经验（按约 1000 次每日挑战估算，可让升 20 级提前约 970 关）
  static const int dailyChallengeXp = 300;

  /// 升级所需经验值公式：XP(n) = 100 × 1.6^(n-1)
  static int xpForLevel(int level) {
    if (level <= 1) return 100;
    return (100 * pow(1.6, level - 1)).round();
  }

  /// 根据总经验值计算当前等级
  static int levelFromXp(int totalXp) {
    int level = 1;
    int xpNeeded = 0;
    while (level < 20) {
      xpNeeded += xpForLevel(level);
      if (totalXp < xpNeeded) break;
      level++;
    }
    return level;
  }

  /// 升级奖励配置
  static const Map<int, LevelReward> _rewards = {
    1: LevelReward(type: RewardType.functional, item: 'hint_card', quantity: 3),
    2: LevelReward(type: RewardType.functional, item: 'hint_card', quantity: 2),
    3: LevelReward(
      type: RewardType.decoration,
      item: 'grid_skin_bamboo',
      quantity: 1,
    ),
    4: LevelReward(
      type: RewardType.functional,
      item: 'revive_card',
      quantity: 1,
    ),
    5: LevelReward(
      type: RewardType.decoration,
      item: 'avatar_frame_wusha',
      quantity: 1,
    ),
    6: LevelReward(type: RewardType.functional, item: 'hint_card', quantity: 3),
    7: LevelReward(
      type: RewardType.decoration,
      item: 'grid_skin_paper',
      quantity: 1,
    ),
    8: LevelReward(
      type: RewardType.functional,
      item: 'revive_card',
      quantity: 2,
    ),
    9: LevelReward(
      type: RewardType.decoration,
      item: 'title_effect_jinbang',
      quantity: 1,
    ),
    10: LevelReward(
      type: RewardType.functional,
      item: 'hint_card',
      quantity: 5,
    ),
    11: LevelReward(
      type: RewardType.decoration,
      item: 'grid_skin_dragon',
      quantity: 1,
    ),
    12: LevelReward(
      type: RewardType.functional,
      item: 'revive_card',
      quantity: 3,
    ),
    13: LevelReward(
      type: RewardType.decoration,
      item: 'avatar_frame_xiezhi',
      quantity: 1,
    ),
    14: LevelReward(
      type: RewardType.functional,
      item: 'hint_card',
      quantity: 5,
    ),
    15: LevelReward(
      type: RewardType.decoration,
      item: 'grid_skin_gold',
      quantity: 1,
    ),
    16: LevelReward(
      type: RewardType.functional,
      item: 'revive_card',
      quantity: 5,
    ),
    17: LevelReward(
      type: RewardType.decoration,
      item: 'title_effect_tianzi',
      quantity: 1,
    ),
    18: LevelReward(
      type: RewardType.decoration,
      item: 'avatar_frame_sangong',
      quantity: 1,
    ),
    19: LevelReward(
      type: RewardType.decoration,
      item: 'grid_skin_emperor',
      quantity: 1,
    ),
    20: LevelReward(
      type: RewardType.decoration,
      item: 'custom_title_unlock',
      quantity: 1,
    ),
  };

  /// 获取升级奖励
  static LevelReward? rewardForLevel(int level) => _rewards[level];

  /// 称号配置
  static const Map<int, String> _titles = {
    1: '童生',
    2: '生员',
    3: '廪生',
    4: '贡生',
    5: '举人',
    6: '解元',
    7: '会元',
    8: '进士',
    9: '殿试',
    10: '探花',
    11: '榜眼',
    12: '状元',
    13: '编修',
    14: '侍郎',
    15: '尚书',
    16: '大学士',
    17: '太子少师',
    18: '太傅',
    19: '太师',
    20: '位极人臣',
  };

  /// 获取称号
  static String titleForLevel(int level) => _titles[level] ?? '童生';

  /// 全部称号（等级 1→20 顺序）
  static List<String> get titleSequence => List.unmodifiable(_titles.values);

  /// 计算通关获得的经验值
  ///
  /// [levelNumber] 关卡编号
  /// [idiomDifficulties] 该关成语的难度列表
  static int calculateXp(int levelNumber, List<int> idiomDifficulties) {
    if (levelNumber >= dailyChallengeLevelOffset) {
      return dailyChallengeXp; // 每日挑战固定 250 经验
    }
    if (levelNumber <= 5) {
      return 10; // 教学关固定 10 经验
    }
    // 通关经验随关卡号缓慢递增：第 6 关起约 5 点起步，
    // 每 1000 关约增加 43 点，保证不做每日时约 7500 关升到 20 级。
    return 5 + ((levelNumber - 1) * 43) ~/ 1000;
  }

  /// 估算后续主线关卡可获得经验（与 calculateXp 同一套递增公式）
  static int estimatedXpForLevel(int levelNumber) {
    return calculateXp(levelNumber, const []);
  }

  /// 按剩余升级经验和后续主线关卡估算还需通关几关
  static int levelsToNextTitle({
    required int xpRemaining,
    required int nextMainLevel,
  }) {
    var remaining = xpRemaining;
    var levelNumber = nextMainLevel;
    var count = 0;
    while (remaining > 0 && count < 10000) {
      remaining -= estimatedXpForLevel(levelNumber);
      count++;
      levelNumber++;
    }
    return count;
  }
}

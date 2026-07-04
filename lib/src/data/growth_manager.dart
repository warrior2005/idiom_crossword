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

class PlayerProgress {
  final int level;
  final int totalXp;
  final int completedLevels;
  final Map<String, int> functionalItems; // hint_card: 5, revive_card: 2
  final Set<String> ownedDecorations; // grid_skin_bamboo, avatar_frame_wusha

  const PlayerProgress({
    required this.level,
    required this.totalXp,
    required this.completedLevels,
    required this.functionalItems,
    required this.ownedDecorations,
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
    3: LevelReward(type: RewardType.decoration, item: 'grid_skin_bamboo', quantity: 1),
    4: LevelReward(type: RewardType.functional, item: 'revive_card', quantity: 1),
    5: LevelReward(type: RewardType.decoration, item: 'avatar_frame_wusha', quantity: 1),
    6: LevelReward(type: RewardType.functional, item: 'hint_card', quantity: 3),
    7: LevelReward(type: RewardType.decoration, item: 'grid_skin_paper', quantity: 1),
    8: LevelReward(type: RewardType.functional, item: 'revive_card', quantity: 2),
    9: LevelReward(type: RewardType.decoration, item: 'title_effect_jinbang', quantity: 1),
    10: LevelReward(type: RewardType.functional, item: 'hint_card', quantity: 5),
    11: LevelReward(type: RewardType.decoration, item: 'grid_skin_dragon', quantity: 1),
    12: LevelReward(type: RewardType.functional, item: 'revive_card', quantity: 3),
    13: LevelReward(type: RewardType.decoration, item: 'avatar_frame_xiezhi', quantity: 1),
    14: LevelReward(type: RewardType.functional, item: 'hint_card', quantity: 5),
    15: LevelReward(type: RewardType.decoration, item: 'grid_skin_gold', quantity: 1),
    16: LevelReward(type: RewardType.functional, item: 'revive_card', quantity: 5),
    17: LevelReward(type: RewardType.decoration, item: 'title_effect_tianzi', quantity: 1),
    18: LevelReward(type: RewardType.decoration, item: 'avatar_frame_sangong', quantity: 1),
    19: LevelReward(type: RewardType.decoration, item: 'grid_skin_emperor', quantity: 1),
    20: LevelReward(type: RewardType.decoration, item: 'custom_title_unlock', quantity: 1),
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

  /// 计算通关获得的经验值
  /// 
  /// [levelNumber] 关卡编号
  /// [idiomDifficulties] 该关成语的难度列表
  static int calculateXp(int levelNumber, List<int> idiomDifficulties) {
    if (levelNumber <= 5) {
      return 10; // 教学关固定 10 经验
    }
    if (idiomDifficulties.isEmpty) {
      return 0;
    }
    final avgDifficulty = idiomDifficulties.reduce((a, b) => a + b) / 
        idiomDifficulties.length;
    return (avgDifficulty * 2).round();
  }
}

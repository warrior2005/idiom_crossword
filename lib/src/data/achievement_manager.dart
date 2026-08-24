/// 成就定义与解锁判定。
///
/// App Store Connect 中的成就总分为 1000 分。
library;

enum AchievementCategory { level, collection, streak, skill, daily, xp }

enum AchievementId {
  firstLevel,
  level10,
  level50,
  level100,
  level500,
  level1000,
  level5000,
  level10000,
  collector50,
  collector200,
  collector1000,
  streak10,
  streak30,
  streak100,
  noHint10,
  noHint100,
  flawless10,
  flawless100,
  dailyChallenge,
  daily7,
  daily30,
  xp10000,
  xp100000,
  xp1000000,
}

class AchievementDef {
  final AchievementId id;
  final String gameCenterId;
  final String title;
  final String description;
  final AchievementCategory category;
  final int points;

  const AchievementDef({
    required this.id,
    required this.gameCenterId,
    required this.title,
    required this.description,
    required this.category,
    required this.points,
  });

  String get assetPath => 'assets/images/achievements/$title.png';
}

const _gameCenterPrefix = 'com.sunnywarrior.idiomcrossword.achievement';

/// 展示顺序也是 App 内成就顺序。
const List<AchievementDef> achievementDefs = [
  AchievementDef(
    id: AchievementId.firstLevel,
    gameCenterId: '$_gameCenterPrefix.first_level',
    title: '初露锋芒',
    description: '累计通关 1 关',
    category: AchievementCategory.level,
    points: 10,
  ),
  AchievementDef(
    id: AchievementId.level10,
    gameCenterId: '$_gameCenterPrefix.level_10',
    title: '小试牛刀',
    description: '累计通关 10 关',
    category: AchievementCategory.level,
    points: 10,
  ),
  AchievementDef(
    id: AchievementId.level50,
    gameCenterId: '$_gameCenterPrefix.level_50',
    title: '渐入佳境',
    description: '累计通关 50 关',
    category: AchievementCategory.level,
    points: 20,
  ),
  AchievementDef(
    id: AchievementId.level100,
    gameCenterId: '$_gameCenterPrefix.level_100',
    title: '百尺竿头',
    description: '累计通关 100 关',
    category: AchievementCategory.level,
    points: 30,
  ),
  AchievementDef(
    id: AchievementId.level500,
    gameCenterId: '$_gameCenterPrefix.level_500',
    title: '熟能生巧',
    description: '累计通关 500 关',
    category: AchievementCategory.level,
    points: 40,
  ),
  AchievementDef(
    id: AchievementId.level1000,
    gameCenterId: '$_gameCenterPrefix.level_1000',
    title: '千锤百炼',
    description: '累计通关 1000 关',
    category: AchievementCategory.level,
    points: 50,
  ),
  AchievementDef(
    id: AchievementId.level5000,
    gameCenterId: '$_gameCenterPrefix.level_5000',
    title: '炉火纯青',
    description: '累计通关 5000 关',
    category: AchievementCategory.level,
    points: 80,
  ),
  AchievementDef(
    id: AchievementId.level10000,
    gameCenterId: '$_gameCenterPrefix.level_10000',
    title: '登峰造极',
    description: '累计通关 10000 关',
    category: AchievementCategory.level,
    points: 100,
  ),
  AchievementDef(
    id: AchievementId.collector50,
    gameCenterId: '$_gameCenterPrefix.collect_50',
    title: '集腋成裘',
    description: '收藏 50 个成语',
    category: AchievementCategory.collection,
    points: 20,
  ),
  AchievementDef(
    id: AchievementId.collector200,
    gameCenterId: '$_gameCenterPrefix.collect_200',
    title: '博闻强识',
    description: '收藏 200 个成语',
    category: AchievementCategory.collection,
    points: 40,
  ),
  AchievementDef(
    id: AchievementId.collector1000,
    gameCenterId: '$_gameCenterPrefix.collect_1000',
    title: '汗牛充栋',
    description: '收藏 1000 个成语',
    category: AchievementCategory.collection,
    points: 80,
  ),
  AchievementDef(
    id: AchievementId.streak10,
    gameCenterId: '$_gameCenterPrefix.streak_10',
    title: '一气呵成',
    description: '连续答对 10 个字',
    category: AchievementCategory.streak,
    points: 20,
  ),
  AchievementDef(
    id: AchievementId.streak30,
    gameCenterId: '$_gameCenterPrefix.streak_30',
    title: '势如破竹',
    description: '连续答对 30 个字',
    category: AchievementCategory.streak,
    points: 40,
  ),
  AchievementDef(
    id: AchievementId.streak100,
    gameCenterId: '$_gameCenterPrefix.streak_100',
    title: '百发百中',
    description: '连续答对 100 个字',
    category: AchievementCategory.streak,
    points: 80,
  ),
  AchievementDef(
    id: AchievementId.noHint10,
    gameCenterId: '$_gameCenterPrefix.no_hint_10',
    title: '自力更生',
    description: '累计 10 次无提示通关',
    category: AchievementCategory.skill,
    points: 30,
  ),
  AchievementDef(
    id: AchievementId.noHint100,
    gameCenterId: '$_gameCenterPrefix.no_hint_100',
    title: '独当一面',
    description: '累计 100 次无提示通关',
    category: AchievementCategory.skill,
    points: 60,
  ),
  AchievementDef(
    id: AchievementId.flawless10,
    gameCenterId: '$_gameCenterPrefix.flawless_10',
    title: '精益求精',
    description: '累计 10 次零失误通关',
    category: AchievementCategory.skill,
    points: 30,
  ),
  AchievementDef(
    id: AchievementId.flawless100,
    gameCenterId: '$_gameCenterPrefix.flawless_100',
    title: '无懈可击',
    description: '累计 100 次零失误通关',
    category: AchievementCategory.skill,
    points: 60,
  ),
  AchievementDef(
    id: AchievementId.dailyChallenge,
    gameCenterId: '$_gameCenterPrefix.daily_1',
    title: '闻鸡起舞',
    description: '完成 1 次每日挑战',
    category: AchievementCategory.daily,
    points: 10,
  ),
  AchievementDef(
    id: AchievementId.daily7,
    gameCenterId: '$_gameCenterPrefix.daily_7',
    title: '七步成诗',
    description: '累计完成 7 次每日挑战',
    category: AchievementCategory.daily,
    points: 30,
  ),
  AchievementDef(
    id: AchievementId.daily30,
    gameCenterId: '$_gameCenterPrefix.daily_30',
    title: '持之以恒',
    description: '累计完成 30 次每日挑战',
    category: AchievementCategory.daily,
    points: 50,
  ),
  AchievementDef(
    id: AchievementId.xp10000,
    gameCenterId: '$_gameCenterPrefix.xp_10000',
    title: '积少成多',
    description: '累计获得 1 万经验',
    category: AchievementCategory.xp,
    points: 20,
  ),
  AchievementDef(
    id: AchievementId.xp100000,
    gameCenterId: '$_gameCenterPrefix.xp_100000',
    title: '厚积薄发',
    description: '累计获得 10 万经验',
    category: AchievementCategory.xp,
    points: 30,
  ),
  AchievementDef(
    id: AchievementId.xp1000000,
    gameCenterId: '$_gameCenterPrefix.xp_1000000',
    title: '功成名就',
    description: '累计获得 100 万经验',
    category: AchievementCategory.xp,
    points: 60,
  ),
];

AchievementDef achievementDefFor(AchievementId id) =>
    achievementDefs.firstWhere((definition) => definition.id == id);

class AchievementManager {
  static List<AchievementId> evaluateOnLevelComplete({
    required Set<AchievementId> alreadyUnlocked,
    required int totalCompleted,
    required int noHintCompletions,
    required int flawlessCompletions,
    required int dailyCompletions,
    required int totalXp,
    required int collectionCount,
  }) {
    final unlocked = <AchievementId>{};

    void check(AchievementId id, bool condition) {
      if (condition && !alreadyUnlocked.contains(id)) unlocked.add(id);
    }

    for (final (id, threshold) in const [
      (AchievementId.firstLevel, 1),
      (AchievementId.level10, 10),
      (AchievementId.level50, 50),
      (AchievementId.level100, 100),
      (AchievementId.level500, 500),
      (AchievementId.level1000, 1000),
      (AchievementId.level5000, 5000),
      (AchievementId.level10000, 10000),
    ]) {
      check(id, totalCompleted >= threshold);
    }
    for (final (id, threshold) in const [
      (AchievementId.collector50, 50),
      (AchievementId.collector200, 200),
      (AchievementId.collector1000, 1000),
    ]) {
      check(id, collectionCount >= threshold);
    }
    check(AchievementId.noHint10, noHintCompletions >= 10);
    check(AchievementId.noHint100, noHintCompletions >= 100);
    check(AchievementId.flawless10, flawlessCompletions >= 10);
    check(AchievementId.flawless100, flawlessCompletions >= 100);
    check(AchievementId.dailyChallenge, dailyCompletions >= 1);
    check(AchievementId.daily7, dailyCompletions >= 7);
    check(AchievementId.daily30, dailyCompletions >= 30);
    check(AchievementId.xp10000, totalXp >= 10000);
    check(AchievementId.xp100000, totalXp >= 100000);
    check(AchievementId.xp1000000, totalXp >= 1000000);

    return achievementDefs.map((d) => d.id).where(unlocked.contains).toList();
  }

  static List<AchievementId> evaluateStreak({
    required Set<AchievementId> alreadyUnlocked,
    required int streak,
  }) => [
    if (streak >= 10 && !alreadyUnlocked.contains(AchievementId.streak10))
      AchievementId.streak10,
    if (streak >= 30 && !alreadyUnlocked.contains(AchievementId.streak30))
      AchievementId.streak30,
    if (streak >= 100 && !alreadyUnlocked.contains(AchievementId.streak100))
      AchievementId.streak100,
  ];
}

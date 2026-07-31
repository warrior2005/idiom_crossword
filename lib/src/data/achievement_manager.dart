/// 成就系统：定义与解锁判定
///
/// 纯逻辑、无 Flutter 依赖，便于单元测试。

library;

enum AchievementId {
  firstLevel, // 首战告捷：完成第 1 关
  streak10, // 十连击：连续答对 10 个字
  noHint, // 不靠提示：不消耗提示通关
  level100, // 百关斩：累计通关 100 关
  dailyChallenge, // 每日打卡：完成一次每日挑战
  collector50, // 成语收藏家：收藏 50 个成语
  speedrun, // 速战速决：60 秒内通关
  flawless, // 零失误：无错误填写通关
}

class AchievementDef {
  final AchievementId id;
  final String title;
  final String description;

  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
  });
}

/// 全部成就定义（展示顺序即列表顺序）
const List<AchievementDef> achievementDefs = [
  AchievementDef(
    id: AchievementId.firstLevel,
    title: '首战告捷',
    description: '完成第 1 关',
  ),
  AchievementDef(
    id: AchievementId.streak10,
    title: '十连击',
    description: '连续答对 10 个字',
  ),
  AchievementDef(
    id: AchievementId.noHint,
    title: '不靠提示',
    description: '不使用提示通关一关',
  ),
  AchievementDef(
    id: AchievementId.level100,
    title: '百关斩',
    description: '累计通关 100 关',
  ),
  AchievementDef(
    id: AchievementId.dailyChallenge,
    title: '每日打卡',
    description: '完成一次每日挑战',
  ),
  AchievementDef(
    id: AchievementId.collector50,
    title: '成语收藏家',
    description: '收藏 50 个成语',
  ),
  AchievementDef(
    id: AchievementId.speedrun,
    title: '速战速决',
    description: '60 秒内通关一关',
  ),
  AchievementDef(
    id: AchievementId.flawless,
    title: '零失误',
    description: '无错误填写通关一关',
  ),
];

class AchievementManager {
  /// 通关事件触发的一次性判定：返回本次新解锁的成就
  ///
  /// [alreadyUnlocked] 已解锁集合；[completedLevels] 为通关后的累计通关数；
  /// [collectionCount] 为通关后的收藏数。
  static List<AchievementId> evaluateOnLevelComplete({
    required Set<AchievementId> alreadyUnlocked,
    required int levelNumber,
    required int completedLevels,
    required bool isDaily,
    required int hintsUsed,
    required int errorsMade,
    required int timeSpentMs,
    required int collectionCount,
  }) {
    final unlocked = <AchievementId>{};

    void check(AchievementId id, bool condition) {
      if (condition && !alreadyUnlocked.contains(id)) unlocked.add(id);
    }

    check(AchievementId.firstLevel, levelNumber == 1);
    check(AchievementId.noHint, hintsUsed == 0);
    check(AchievementId.level100, completedLevels >= 100);
    check(AchievementId.dailyChallenge, isDaily);
    check(AchievementId.collector50, collectionCount >= 50);
    check(AchievementId.speedrun, timeSpentMs > 0 && timeSpentMs < 60000);
    check(AchievementId.flawless, errorsMade == 0);

    return achievementDefs.map((d) => d.id).where(unlocked.contains).toList();
  }
}

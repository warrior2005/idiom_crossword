/// 成就系统：定义与解锁判定
///
/// 纯逻辑、无 Flutter 依赖，便于单元测试。

library;

enum AchievementId {
  firstLevel, // 首战告捷：完成第 1 关
  level10, // 十关
  level50, // 五十关
  level100, // 百关斩
  level500, // 五百关
  level1000, // 千关斩
  collector50, // 成语收藏家：收藏 50 个
  collector100, // 收藏 100 个
  collector200, // 收藏 200 个
  streak10, // 十连击：连续答对 10 字
  streak20, // 二十连击
  streak30, // 三十连击
  noHint, // 不靠提示：无提示通关
  noHint10, // 十次无提示通关
  flawless, // 零失误：无错误通关
  flawless10, // 十次零失误通关
  speedrun, // 速战速决：60 秒内通关
  speedrun10, // 十次速通
  dailyChallenge, // 每日打卡：完成一次每日挑战
  daily7, // 七日挑战：累计 7 次
  xp100000, // 经验大师：累计 10 万经验
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
    id: AchievementId.level10,
    title: '十关',
    description: '累计通关 10 关',
  ),
  AchievementDef(
    id: AchievementId.level50,
    title: '五十关',
    description: '累计通关 50 关',
  ),
  AchievementDef(
    id: AchievementId.level100,
    title: '百关斩',
    description: '累计通关 100 关',
  ),
  AchievementDef(
    id: AchievementId.level500,
    title: '五百关',
    description: '累计通关 500 关',
  ),
  AchievementDef(
    id: AchievementId.level1000,
    title: '千关斩',
    description: '累计通关 1000 关',
  ),
  AchievementDef(
    id: AchievementId.collector50,
    title: '成语收藏家',
    description: '收藏 50 个成语',
  ),
  AchievementDef(
    id: AchievementId.collector100,
    title: '收藏百条',
    description: '收藏 100 个成语',
  ),
  AchievementDef(
    id: AchievementId.collector200,
    title: '收藏两百',
    description: '收藏 200 个成语',
  ),
  AchievementDef(
    id: AchievementId.streak10,
    title: '十连击',
    description: '连续答对 10 个字',
  ),
  AchievementDef(
    id: AchievementId.streak20,
    title: '二十连击',
    description: '连续答对 20 个字',
  ),
  AchievementDef(
    id: AchievementId.streak30,
    title: '三十连击',
    description: '连续答对 30 个字',
  ),
  AchievementDef(
    id: AchievementId.noHint,
    title: '不靠提示',
    description: '不使用提示通关一关',
  ),
  AchievementDef(
    id: AchievementId.noHint10,
    title: '十次不靠提示',
    description: '累计 10 次无提示通关',
  ),
  AchievementDef(
    id: AchievementId.flawless,
    title: '零失误',
    description: '无错误填写通关一关',
  ),
  AchievementDef(
    id: AchievementId.flawless10,
    title: '十次零失误',
    description: '累计 10 次零失误通关',
  ),
  AchievementDef(
    id: AchievementId.speedrun,
    title: '速战速决',
    description: '60 秒内通关一关',
  ),
  AchievementDef(
    id: AchievementId.speedrun10,
    title: '十次速通',
    description: '累计 10 次 60 秒内通关',
  ),
  AchievementDef(
    id: AchievementId.dailyChallenge,
    title: '每日打卡',
    description: '完成一次每日挑战',
  ),
  AchievementDef(
    id: AchievementId.daily7,
    title: '七日挑战',
    description: '累计完成 7 次每日挑战',
  ),
  AchievementDef(
    id: AchievementId.xp100000,
    title: '经验大师',
    description: '累计获得 10 万经验',
  ),
];

class AchievementManager {
  /// 通关事件触发的一次性判定：返回本次新解锁的成就
  ///
  /// 计数类参数由调用方从通关历史统计后传入。
  static List<AchievementId> evaluateOnLevelComplete({
    required Set<AchievementId> alreadyUnlocked,
    required int levelNumber,
    required int totalCompleted,
    required int noHintCompletions,
    required int flawlessCompletions,
    required int speedrunCompletions,
    required int dailyCompletions,
    required int totalXp,
    required int collectionCount,
    required bool isDaily,
    required int hintsUsed,
    required int errorsMade,
    required int timeSpentMs,
  }) {
    final unlocked = <AchievementId>{};

    void check(AchievementId id, bool condition) {
      if (condition && !alreadyUnlocked.contains(id)) unlocked.add(id);
    }

    check(AchievementId.firstLevel, levelNumber == 1);
    check(AchievementId.level10, totalCompleted >= 10);
    check(AchievementId.level50, totalCompleted >= 50);
    check(AchievementId.level100, totalCompleted >= 100);
    check(AchievementId.level500, totalCompleted >= 500);
    check(AchievementId.level1000, totalCompleted >= 1000);
    check(AchievementId.collector50, collectionCount >= 50);
    check(AchievementId.collector100, collectionCount >= 100);
    check(AchievementId.collector200, collectionCount >= 200);
    check(AchievementId.noHint, hintsUsed == 0);
    check(AchievementId.noHint10, noHintCompletions >= 10);
    check(AchievementId.flawless, errorsMade == 0);
    check(AchievementId.flawless10, flawlessCompletions >= 10);
    check(AchievementId.speedrun, timeSpentMs > 0 && timeSpentMs < 60000);
    check(AchievementId.speedrun10, speedrunCompletions >= 10);
    check(AchievementId.dailyChallenge, isDaily);
    check(AchievementId.daily7, dailyCompletions >= 7);
    check(AchievementId.xp100000, totalXp >= 100000);

    return achievementDefs.map((d) => d.id).where(unlocked.contains).toList();
  }
}

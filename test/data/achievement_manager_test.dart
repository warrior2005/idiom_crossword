import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/achievement_manager.dart';

List<AchievementId> _eval({
  Set<AchievementId> alreadyUnlocked = const {},
  int levelNumber = 1,
  int totalCompleted = 1,
  int noHintCompletions = 1,
  int flawlessCompletions = 1,
  int speedrunCompletions = 1,
  int dailyCompletions = 0,
  int totalXp = 100,
  int collectionCount = 5,
  bool isDaily = false,
  int hintsUsed = 0,
  int errorsMade = 0,
  int timeSpentMs = 30000,
}) {
  return AchievementManager.evaluateOnLevelComplete(
    alreadyUnlocked: alreadyUnlocked,
    levelNumber: levelNumber,
    totalCompleted: totalCompleted,
    noHintCompletions: noHintCompletions,
    flawlessCompletions: flawlessCompletions,
    speedrunCompletions: speedrunCompletions,
    dailyCompletions: dailyCompletions,
    totalXp: totalXp,
    collectionCount: collectionCount,
    isDaily: isDaily,
    hintsUsed: hintsUsed,
    errorsMade: errorsMade,
    timeSpentMs: timeSpentMs,
  );
}

void main() {
  test('首关完成解锁基础成就', () {
    final newly = _eval();
    expect(newly, contains(AchievementId.firstLevel));
    expect(newly, contains(AchievementId.noHint));
    expect(newly, contains(AchievementId.flawless));
    expect(newly, contains(AchievementId.speedrun));
  });

  test('已解锁的不重复返回', () {
    final newly = _eval(
      alreadyUnlocked: {AchievementId.firstLevel, AchievementId.flawless},
    );
    expect(newly, isNot(contains(AchievementId.firstLevel)));
    expect(newly, isNot(contains(AchievementId.flawless)));
    expect(newly, contains(AchievementId.noHint));
  });

  test('通关数分层里程碑', () {
    expect(_eval(totalCompleted: 10), contains(AchievementId.level10));
    expect(_eval(totalCompleted: 50), contains(AchievementId.level50));
    expect(_eval(totalCompleted: 100), contains(AchievementId.level100));
    expect(_eval(totalCompleted: 500), contains(AchievementId.level500));
    expect(_eval(totalCompleted: 1000), contains(AchievementId.level1000));
    expect(_eval(totalCompleted: 100), isNot(contains(AchievementId.level500)));
  });

  test('计数类成就按累计次数解锁', () {
    expect(_eval(noHintCompletions: 10), contains(AchievementId.noHint10));
    expect(_eval(flawlessCompletions: 10), contains(AchievementId.flawless10));
    expect(_eval(speedrunCompletions: 10), contains(AchievementId.speedrun10));
    expect(
      _eval(noHintCompletions: 9),
      isNot(contains(AchievementId.noHint10)),
    );
  });

  test('每日挑战成就与经验里程碑', () {
    final daily = _eval(isDaily: true, dailyCompletions: 7);
    expect(daily, contains(AchievementId.dailyChallenge));
    expect(daily, contains(AchievementId.daily7));
    expect(_eval(totalXp: 100000), contains(AchievementId.xp100000));
    expect(_eval(totalXp: 99999), isNot(contains(AchievementId.xp100000)));
  });

  test('收藏分层', () {
    expect(_eval(collectionCount: 50), contains(AchievementId.collector50));
    expect(_eval(collectionCount: 100), contains(AchievementId.collector100));
    expect(_eval(collectionCount: 200), contains(AchievementId.collector200));
    expect(
      _eval(collectionCount: 49),
      isNot(contains(AchievementId.collector50)),
    );
  });
}

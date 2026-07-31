import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/achievement_manager.dart';

void main() {
  group('AchievementManager.evaluateOnLevelComplete', () {
    test('首关完成解锁 firstLevel', () {
      final newly = AchievementManager.evaluateOnLevelComplete(
        alreadyUnlocked: {},
        levelNumber: 1,
        completedLevels: 1,
        isDaily: false,
        hintsUsed: 0,
        errorsMade: 0,
        timeSpentMs: 30000,
        collectionCount: 5,
      );
      expect(newly, contains(AchievementId.firstLevel));
      expect(newly, contains(AchievementId.noHint));
      expect(newly, contains(AchievementId.speedrun));
      expect(newly, contains(AchievementId.flawless));
    });

    test('已解锁的不重复返回', () {
      final newly = AchievementManager.evaluateOnLevelComplete(
        alreadyUnlocked: {AchievementId.firstLevel, AchievementId.flawless},
        levelNumber: 1,
        completedLevels: 1,
        isDaily: false,
        hintsUsed: 0,
        errorsMade: 0,
        timeSpentMs: 30000,
        collectionCount: 5,
      );
      expect(newly, isNot(contains(AchievementId.firstLevel)));
      expect(newly, isNot(contains(AchievementId.flawless)));
      expect(newly, contains(AchievementId.noHint));
    });

    test('每日挑战解锁 dailyChallenge', () {
      final newly = AchievementManager.evaluateOnLevelComplete(
        alreadyUnlocked: {},
        levelNumber: 1000001,
        completedLevels: 6,
        isDaily: true,
        hintsUsed: 2,
        errorsMade: 1,
        timeSpentMs: 120000,
        collectionCount: 10,
      );
      expect(newly, contains(AchievementId.dailyChallenge));
      expect(newly, isNot(contains(AchievementId.noHint)));
      expect(newly, isNot(contains(AchievementId.flawless)));
    });

    test('百关斩/收藏家阈值', () {
      final newly = AchievementManager.evaluateOnLevelComplete(
        alreadyUnlocked: {},
        levelNumber: 100,
        completedLevels: 100,
        isDaily: false,
        hintsUsed: 1,
        errorsMade: 2,
        timeSpentMs: 90000,
        collectionCount: 50,
      );
      expect(newly, contains(AchievementId.level100));
      expect(newly, contains(AchievementId.collector50));
      expect(newly, isNot(contains(AchievementId.speedrun)));
    });
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/achievement_manager.dart';

List<AchievementId> _eval({
  Set<AchievementId> alreadyUnlocked = const {},
  int totalCompleted = 1,
  int noHintCompletions = 1,
  int flawlessCompletions = 1,
  int dailyCompletions = 0,
  int totalXp = 100,
  int collectionCount = 5,
}) => AchievementManager.evaluateOnLevelComplete(
  alreadyUnlocked: alreadyUnlocked,
  totalCompleted: totalCompleted,
  noHintCompletions: noHintCompletions,
  flawlessCompletions: flawlessCompletions,
  dailyCompletions: dailyCompletions,
  totalXp: totalXp,
  collectionCount: collectionCount,
);

void main() {
  test('首次通关只解锁基础通关成就', () {
    expect(_eval(), [AchievementId.firstLevel]);
  });

  test('已解锁成就不会重复返回', () {
    expect(
      _eval(alreadyUnlocked: {AchievementId.firstLevel}),
      isNot(contains(AchievementId.firstLevel)),
    );
  });

  test('通关成就是可长期追求的分层里程碑', () {
    expect(_eval(totalCompleted: 10), contains(AchievementId.level10));
    expect(_eval(totalCompleted: 1000), contains(AchievementId.level1000));
    expect(_eval(totalCompleted: 5000), contains(AchievementId.level5000));
    expect(_eval(totalCompleted: 10000), contains(AchievementId.level10000));
  });

  test('技巧成就按累计次数解锁', () {
    expect(_eval(noHintCompletions: 10), contains(AchievementId.noHint10));
    expect(_eval(noHintCompletions: 100), contains(AchievementId.noHint100));
    expect(_eval(flawlessCompletions: 10), contains(AchievementId.flawless10));
    expect(
      _eval(flawlessCompletions: 100),
      contains(AchievementId.flawless100),
    );
  });

  test('每日、收藏和经验成就有三档目标', () {
    expect(_eval(dailyCompletions: 30), contains(AchievementId.daily30));
    expect(_eval(collectionCount: 1000), contains(AchievementId.collector1000));
    expect(_eval(totalXp: 1000000), contains(AchievementId.xp1000000));
  });

  test('收集成就描述使用收集措辞', () {
    expect(
      achievementDefs
          .where((item) => item.category == AchievementCategory.collection)
          .map((item) => item.description),
      ['收集 50 个成语', '收集 200 个成语', '收集 1000 个成语'],
    );
  });

  test('连击成就按 10、30、100 解锁', () {
    expect(
      AchievementManager.evaluateStreak(alreadyUnlocked: const {}, streak: 100),
      [AchievementId.streak10, AchievementId.streak30, AchievementId.streak100],
    );
  });

  test('App Store 成就总分为 1000 且 ID 唯一', () {
    expect(achievementDefs.fold(0, (sum, item) => sum + item.points), 1000);
    expect(
      achievementDefs.map((item) => item.gameCenterId).toSet().length,
      achievementDefs.length,
    );
  });

  testWidgets('24 个成就都有对应图片资源', (tester) async {
    expect(achievementDefs, hasLength(24));
    for (final definition in achievementDefs) {
      final image = await rootBundle.load(definition.assetPath);
      expect(image.lengthInBytes, greaterThan(0), reason: definition.title);
    }
  });
}

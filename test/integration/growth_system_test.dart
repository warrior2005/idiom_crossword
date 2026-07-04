import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/spiral_difficulty.dart';
import 'package:idiom_crossword/src/data/growth_manager.dart';

void main() {
  group('Growth System Integration', () {
    test('full flow: level 1 to level 2', () {
      // Start at level 1
      var totalXp = 0;
      var level = GrowthManager.levelFromXp(totalXp);
      expect(level, 1);

      // Complete 10 levels (difficulty 5 gives 10 xp each)
      for (int i = 1; i <= 10; i++) {
        totalXp += GrowthManager.calculateXp(i, [5, 5, 5, 5, 5]);
      }

      // Should be level 2 now
      level = GrowthManager.levelFromXp(totalXp);
      expect(level, 2);
    });

    test('spiral difficulty generates valid ranges', () {
      for (int levelNum = 1; levelNum <= 10000; levelNum += 100) {
        final result = SpiralDifficulty.calculate(levelNum);
        expect(result.baseDifficulty, greaterThanOrEqualTo(1));
        expect(result.baseDifficulty, lessThanOrEqualTo(50));
        expect(result.mainMin, greaterThanOrEqualTo(1));
        expect(result.mainMax, lessThanOrEqualTo(50));
        expect(result.mainMin, lessThanOrEqualTo(result.mainMax));
      }
    });

    test('rewards are assigned correctly', () {
      expect(GrowthManager.rewardForLevel(1)?.item, 'hint_card');
      expect(GrowthManager.rewardForLevel(3)?.item, 'grid_skin_bamboo');
      expect(GrowthManager.rewardForLevel(20)?.item, 'custom_title_unlock');
    });
  });
}

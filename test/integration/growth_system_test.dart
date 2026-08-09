import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/spiral_difficulty.dart';
import 'package:idiom_crossword/src/engine/global_difficulty.dart';
import 'package:idiom_crossword/src/data/growth_manager.dart';

void main() {
  group('Growth System Integration', () {
    test('full flow: level 1 to level 2', () {
      // Start at level 1
      var totalXp = 0;
      var level = GrowthManager.levelFromXp(totalXp);
      expect(level, 1);

      // 完成 15 个主线关：1-5 关各 20 经验，6-15 关各 5 经验，合计 150
      for (int i = 1; i <= 15; i++) {
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

    test('Lv20 后三区混排参数保持合理', () {
      for (final levelNum in [7551, 10001, 20001, 50001]) {
        final gd = GlobalDifficulty.calculate(levelNum, random: Random(1));
        expect(gd.center, inInclusiveRange(20, 40));
        expect(gd.reviewMax, lessThan(gd.mainMin));
        expect(gd.mainMax, lessThan(gd.sprintMin));
        expect(gd.targetSize, inInclusiveRange(10, 12));
        expect(gd.mainCount, 8);
        expect(gd.reviewCount, 0);
        expect(gd.sprintCount, inInclusiveRange(2, 3));
        expect(gd.surpriseCount, inInclusiveRange(0, 1));
        expect(
          gd.mainCount + gd.reviewCount + gd.sprintCount + gd.surpriseCount,
          gd.targetSize,
        );
      }
    });

    test('rewards are assigned correctly', () {
      expect(GrowthManager.rewardForLevel(1)?.item, 'hint_card');
      expect(GrowthManager.rewardForLevel(2)?.item, 'avatar_frame_sifang');
      expect(GrowthManager.rewardForLevel(5)?.item, 'avatar_frame_wusha');
      expect(GrowthManager.rewardForLevel(13)?.item, 'avatar_frame_xiezhi');
      expect(GrowthManager.rewardForLevel(18)?.item, 'avatar_frame_zhongjing');
      expect(GrowthManager.rewardForLevel(21)?.item, 'avatar_frame_tianzi');
      expect(GrowthManager.rewardForLevel(3)?.item, 'grid_skin_bamboo');
      expect(GrowthManager.rewardForLevel(20)?.item, 'custom_title_unlock');
    });
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/growth_manager.dart';
import 'package:idiom_crossword/src/ui/screens/shop_screen.dart';
import 'package:idiom_crossword/src/ui/theme/decoration_catalog.dart';
import 'package:idiom_crossword/src/ui/theme/grid_skins.dart';

void main() {
  test('所有装饰升级奖励都有对应商品、展示名和一致的解锁等级', () {
    final seen = <String>{};
    for (var level = 2; level <= GrowthManager.maxLevel; level++) {
      final reward = GrowthManager.rewardForLevel(level)!;
      if (reward.type != RewardType.decoration) continue;
      expect(seen.add(reward.item), isTrue, reason: '重复奖励：${reward.item}');
      expect(decorationName(reward.item), isNot(reward.item));
      expect(reward.quantity, 1);
      if (reward.item.startsWith('grid_skin_')) {
        final id = reward.item.substring('grid_skin_'.length);
        expect(id, isNot('paper'), reason: '默认皮肤不应再次作为升级奖励');
        expect(gridSkinById(id), isNotNull);
        expect(kLevelSkinUnlockLevels[id], level);
      } else if (reward.item.startsWith('avatar_frame_')) {
        final frame = avatarFrameById(
          reward.item.substring('avatar_frame_'.length),
        );
        expect(frame, isNotNull);
        expect(frame!.unlockLevel, level);
        expect(File(frame.asset!).existsSync(), isTrue);
      } else if (reward.item.startsWith('title_effect_')) {
        final effect = titleEffectById(
          reward.item.substring('title_effect_'.length),
        );
        expect(effect, isNotNull);
        expect(effect!.unlockLevel, level);
      } else {
        fail('奖励缺少可使用的商品：${reward.item}');
      }
    }
  });

  test('位极人臣奖励皮肤，真龙天子奖励天子冕冠', () {
    expect(GrowthManager.titleForLevel(20), '位极人臣');
    expect(GrowthManager.rewardForLevel(20)!.item, 'grid_skin_emperor');
    expect(GrowthManager.titleForLevel(21), '真龙天子');
    expect(GrowthManager.levelLabel(21), 'Lv.∞');
    expect(GrowthManager.rewardForLevel(21)!.item, 'avatar_frame_tianzi');
    expect(avatarFrameById('tianzi')!.unlockLevel, 21);
  });
}

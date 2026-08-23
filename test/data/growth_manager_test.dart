// ignore_for_file: avoid_print

import 'package:idiom_crossword/src/data/growth_manager.dart';
import 'package:idiom_crossword/src/ui/theme/decoration_catalog.dart';

/// 成长系统管理器测试

void main() {
  print('=== 成长系统管理器测试 ===\n');

  // 测试 1：经验值公式
  print('--- 测试 1: 经验值公式 ---');
  _testXpFormula(1, 100, 'level 1');
  _testXpFormula(2, 160, 'level 2');
  _testXpFormula(5, 655, 'level 5');
  _testXpFormula(10, 6872, 'level 10');

  // 测试 2：根据经验值计算等级
  print('\n--- 测试 2: 根据经验值计算等级 ---');
  _testLevelFromXp(0, 1, '0 XP');
  _testLevelFromXp(100, 2, '100 XP');
  _testLevelFromXp(260, 3, '260 XP');
  _testLevelFromXp(10000, 9, '10000 XP');
  _testLevelFromXp(8689604, 20, '接近 Lv.∞');
  _testLevelFromXp(8689605, 21, 'Lv.∞ 真龙天子');

  // 测试 3：升级奖励
  print('\n--- 测试 3: 升级奖励 ---');
  final reward1 = GrowthManager.rewardForLevel(1);
  assert(reward1 != null, 'level 1 should have reward');
  assert(
    reward1!.type == RewardType.functional,
    'level 1 reward should be functional',
  );
  assert(
    reward1!.item == 'hint_card',
    'level 1 reward item should be hint_card',
  );
  assert(reward1!.quantity == 3, 'level 1 reward quantity should be 3');
  print('  ✓ level 1: functional hint_card x3');

  final reward3 = GrowthManager.rewardForLevel(3);
  assert(reward3 != null, 'level 3 should have reward');
  assert(
    reward3!.type == RewardType.decoration,
    'level 3 reward should be decoration',
  );
  assert(
    reward3!.item == 'grid_skin_bamboo',
    'level 3 reward item should be grid_skin_bamboo',
  );
  print('  ✓ level 3: decoration grid_skin_bamboo');

  final reward2 = GrowthManager.rewardForLevel(2);
  assert(
    reward2?.item == 'avatar_frame_sifang',
    'level 2 reward should be avatar_frame_sifang',
  );
  print('  ✓ level 2: decoration avatar_frame_sifang');

  final reward5 = GrowthManager.rewardForLevel(5);
  assert(
    reward5?.item == 'avatar_frame_wusha',
    'level 5 reward should be avatar_frame_wusha',
  );
  print('  ✓ level 5: decoration avatar_frame_wusha');

  final reward13 = GrowthManager.rewardForLevel(13);
  assert(
    reward13?.item == 'avatar_frame_xiezhi',
    'level 13 reward should be avatar_frame_xiezhi',
  );
  print('  ✓ level 13: decoration avatar_frame_xiezhi');

  final reward18 = GrowthManager.rewardForLevel(18);
  assert(
    reward18?.item == 'avatar_frame_zhongjing',
    'level 18 reward should be avatar_frame_zhongjing',
  );
  print('  ✓ level 18: decoration avatar_frame_zhongjing');

  final reward21 = GrowthManager.rewardForLevel(21);
  assert(
    reward21?.item == 'avatar_frame_tianzi',
    'level 21 reward should be avatar_frame_tianzi',
  );
  print('  ✓ level 21: decoration avatar_frame_tianzi');

  // 测试 4：称号系统
  print('\n--- 测试 4: 称号系统 ---');
  _testTitle(1, '童生', 'level 1');
  _testTitle(5, '举人', 'level 5');
  _testTitle(12, '状元', 'level 12');
  _testTitle(20, '位极人臣', 'level 20');
  _testTitle(21, '真龙天子', 'level 21');

  // 测试 5：经验值计算
  print('\n--- 测试 5: 经验值计算 ---');
  final xpTeaching = GrowthManager.calculateXp(3, [5, 10, 15]);
  assert(xpTeaching == 20, 'teaching level should give 20 XP');
  print('  ✓ teaching level 3: 20 XP');

  final xpFormal = GrowthManager.calculateXp(10, [20, 30, 40]);
  assert(xpFormal == 5, 'expected 5, got $xpFormal');
  assert(
    GrowthManager.calculateXp(1000, [1]) > GrowthManager.calculateXp(100, [1]),
  );
  print('  ✓ formal level 10: 5 XP，且随关卡号递增');

  // 测试 6：估算后续通关关数
  print('\n--- 测试 6: 估算晋升所需通关关数 ---');
  assert(GrowthManager.estimatedXpForLevel(1) == 20);
  assert(GrowthManager.estimatedXpForLevel(6) == 5);
  final levels = GrowthManager.levelsToNextTitle(
    xpRemaining: 90,
    nextMainLevel: 1,
  );
  assert(levels == 5, 'expected 5, got $levels');
  print('  ✓ 还差 90 经验时预计需通关 5 关');

  // 测试 7：头像印章分档（6 档）
  print('\n--- 测试 7: 头像印章分档（6 档）---');
  assert(GrowthManager.avatarSeal(1) == '士');
  assert(GrowthManager.avatarSeal(5) == '士');
  assert(GrowthManager.avatarSeal(6) == '官');
  assert(GrowthManager.avatarSeal(9) == '卿');
  assert(GrowthManager.avatarSeal(13) == '相');
  assert(GrowthManager.avatarSeal(17) == '公');
  assert(GrowthManager.avatarSeal(21) == '龙');
  print('  ✓ 士/官/卿/相/公/龙 六档映射正确');

  // 测试 8：装饰条目显示名（升级奖励弹框用）
  print('\n--- 测试 8: 装饰条目显示名 ---');
  _testDecorationName('grid_skin_bamboo', '网格皮肤·竹简');
  _testDecorationName('avatar_frame_sifang', '头像框·四方平定巾');
  _testDecorationName('avatar_frame_dongpo', '头像框·东坡巾');
  _testDecorationName('avatar_frame_wusha', '头像框·乌纱帽');
  _testDecorationName('avatar_frame_yishan', '头像框·翼善冠');
  _testDecorationName('avatar_frame_zhongjing', '头像框·忠靖冠');
  _testDecorationName('avatar_frame_tianzi', '头像框·天子冕冠');
  _testDecorationName('title_effect_jinbang', '称号特效·金榜题名');
  _testDecorationName('title_effect_tianzi', '称号特效·位列公卿');
  _testDecorationName('custom_title_unlock', '自定义称号解锁');

  print('\n=== 所有测试通过 ===');
}

void _testXpFormula(int level, int expected, String label) {
  final result = GrowthManager.xpForLevel(level);
  final pass = result == expected;
  final icon = pass ? '✓' : '✗';
  print('  $icon $label: xp=$result (expected $expected)');
  assert(pass, '$label: expected xp $expected, got $result');
}

void _testLevelFromXp(int xp, int expected, String label) {
  final result = GrowthManager.levelFromXp(xp);
  final pass = result == expected;
  final icon = pass ? '✓' : '✗';
  print('  $icon $label: level=$result (expected $expected)');
  assert(pass, '$label: expected level $expected, got $result');
}

void _testTitle(int level, String expected, String label) {
  final result = GrowthManager.titleForLevel(level);
  final pass = result == expected;
  final icon = pass ? '✓' : '✗';
  print('  $icon $label: title=$result (expected $expected)');
  assert(pass, '$label: expected title $expected, got $result');
}

void _testDecorationName(String item, String expected) {
  final result = decorationName(item);
  final pass = result == expected;
  final icon = pass ? '✓' : '✗';
  print('  $icon $item -> $result');
  assert(pass, '$item: expected $expected, got $result');
}

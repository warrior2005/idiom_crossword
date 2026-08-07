// ignore_for_file: avoid_print

import 'package:idiom_crossword/src/data/growth_manager.dart';

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
  assert(xpTeaching == 10, 'teaching level should give 10 XP');
  print('  ✓ teaching level 3: 10 XP');

  final xpFormal = GrowthManager.calculateXp(10, [20, 30, 40]);
  assert(xpFormal == 5, 'expected 5, got $xpFormal');
  assert(
    GrowthManager.calculateXp(1000, [1]) > GrowthManager.calculateXp(100, [1]),
  );
  print('  ✓ formal level 10: 5 XP，且随关卡号递增');

  // 测试 6：估算后续通关关数
  print('\n--- 测试 6: 估算晋升所需通关关数 ---');
  assert(GrowthManager.estimatedXpForLevel(1) == 10);
  assert(GrowthManager.estimatedXpForLevel(6) == 5);
  final levels = GrowthManager.levelsToNextTitle(
    xpRemaining: 90,
    nextMainLevel: 1,
  );
  assert(levels == 13, 'expected 13, got $levels');
  print('  ✓ 还差 90 经验时预计需通关 13 关');

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

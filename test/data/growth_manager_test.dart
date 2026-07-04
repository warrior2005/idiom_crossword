import 'package:idiom_crossword/src/data/growth_manager.dart';

/// 成长系统管理器测试

void main() {
  print('=== 成长系统管理器测试 ===\n');

  // 测试 1：经验值公式
  print('--- 测试 1: 经验值公式 ---');
  _testXpFormula(1, 100, 'level 1');
  _testXpFormula(2, 160, 'level 2');
  _testXpFormula(5, 409, 'level 5');
  _testXpFormula(10, 1074, 'level 10');

  // 测试 2：根据经验值计算等级
  print('\n--- 测试 2: 根据经验值计算等级 ---');
  _testLevelFromXp(0, 1, '0 XP');
  _testLevelFromXp(100, 2, '100 XP');
  _testLevelFromXp(260, 3, '260 XP');
  _testLevelFromXp(10000, 10, '10000 XP');

  // 测试 3：升级奖励
  print('\n--- 测试 3: 升级奖励 ---');
  final reward1 = GrowthManager.rewardForLevel(1);
  assert(reward1 != null, 'level 1 should have reward');
  assert(reward1!.type == RewardType.functional, 'level 1 reward should be functional');
  assert(reward1.item == 'hint_card', 'level 1 reward item should be hint_card');
  assert(reward1.quantity == 3, 'level 1 reward quantity should be 3');
  print('  ✓ level 1: functional hint_card x3');

  final reward3 = GrowthManager.rewardForLevel(3);
  assert(reward3 != null, 'level 3 should have reward');
  assert(reward3!.type == RewardType.decoration, 'level 3 reward should be decoration');
  assert(reward3.item == 'grid_skin_bamboo', 'level 3 reward item should be grid_skin_bamboo');
  print('  ✓ level 3: decoration grid_skin_bamboo');

  // 测试 4：称号系统
  print('\n--- 测试 4: 称号系统 ---');
  _testTitle(1, '童生', 'level 1');
  _testTitle(5, '举人', 'level 5');
  _testTitle(12, '状元', 'level 12');
  _testTitle(20, '位极人臣', 'level 20');

  // 测试 5：经验值计算
  print('\n--- 测试 5: 经验值计算 ---');
  final xpTeaching = GrowthManager.calculateXp(3, [5, 10, 15]);
  assert(xpTeaching == 10, 'teaching level should give 10 XP');
  print('  ✓ teaching level 3: 10 XP');

  final xpFormal = GrowthManager.calculateXp(10, [20, 30, 40]);
  final expectedXp = ((20 + 30 + 40) / 3 * 2).round();
  assert(xpFormal == expectedXp, 'formal level XP should be avgDifficulty * 2');
  print('  ✓ formal level 10: $xpFormal XP (avg=30, *2)');

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

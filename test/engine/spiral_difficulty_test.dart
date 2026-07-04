import 'package:idiom_crossword/src/engine/spiral_difficulty.dart';

/// 螺旋难度计算器测试

void main() {
  print('=== 螺旋难度计算器测试 ===\n');

  // 测试 1：基准难度计算
  print('--- 测试 1: 基准难度计算 ---');
  _testBaseDifficulty(1, 1, 'level 1');
  _testBaseDifficulty(200, 1, 'level 200');
  _testBaseDifficulty(201, 2, 'level 201');
  _testBaseDifficulty(10000, 50, 'level 10000');

  // 测试 2：主体范围 base ± 3
  print('\n--- 测试 2: 主体范围 ---');
  final r1000 = SpiralDifficulty.calculate(1000);
  print('  level 1000: base=${r1000.baseDifficulty}, '
      'main=${r1000.mainMin}-${r1000.mainMax}');
  assert(r1000.mainMin >= 1, 'mainMin should be >= 1');
  assert(r1000.mainMax <= 50, 'mainMax should be <= 50');
  assert(r1000.mainMax - r1000.mainMin == 6, 'main range should be 6 (base ± 3)');
  print('  ✓ 主体范围正确');

  // 测试 3：长尾范围 base - 10 to base - 5
  print('\n--- 测试 3: 长尾范围 ---');
  if (r1000.tailMax > 0) {
    assert(r1000.tailMax < r1000.baseDifficulty, 'tailMax should be < base');
    assert(r1000.tailMin >= 1, 'tailMin should be >= 1');
    print('  level 1000: tail=${r1000.tailMin}-${r1000.tailMax}');
    print('  ✓ 长尾范围正确');
  }

  // 测试 4：预览范围 base + 3 to base + 5
  print('\n--- 测试 4: 预览范围 ---');
  if (r1000.previewMax > 0) {
    assert(r1000.previewMin > r1000.baseDifficulty, 'previewMin should be > base');
    assert(r1000.previewMax <= 50, 'previewMax should be <= 50');
    print('  level 1000: preview=${r1000.previewMin}-${r1000.previewMax}');
    print('  ✓ 预览范围正确');
  }

  // 测试 5：教学关 (1-5) 无长尾/预览
  print('\n--- 测试 5: 教学关 ---');
  for (int level = 1; level <= 5; level++) {
    final r = SpiralDifficulty.calculate(level);
    assert(r.tailMax == 0, 'teaching level $level should have no tail');
    assert(r.previewMax == 0, 'teaching level $level should have no preview');
    print('  level $level: base=${r.baseDifficulty}, tail=${r.tailMin}-${r.tailMax}, '
        'preview=${r.previewMin}-${r.previewMax}');
  }
  print('  ✓ 教学关无长尾/预览');

  // 测试 6：成语数量选择
  print('\n--- 测试 6: 成语数量选择 ---');
  final (mainC1, tailC1, previewC1) = SpiralDifficulty.selectIdiomCounts(1);
  assert(mainC1 == 5 && tailC1 == 0 && previewC1 == 0,
      'teaching level should have 5 main, 0 tail, 0 preview');
  print('  level 1: main=$mainC1, tail=$tailC1, preview=$previewC1');

  final (mainC100, tailC100, previewC100) = SpiralDifficulty.selectIdiomCounts(100);
  assert(mainC100 == 5 && tailC100 == 1 && previewC100 == 0,
      'transition level should have 5 main, 1 tail, 0 preview');
  print('  level 100: main=$mainC100, tail=$tailC100, preview=$previewC100');

  final (mainC500, tailC500, previewC500) = SpiralDifficulty.selectIdiomCounts(500);
  assert(mainC500 >= 7 && mainC500 <= 9, 'main count should be 7-9');
  assert(tailC500 >= 1 && tailC500 <= 2, 'tail count should be 1-2');
  assert(previewC500 >= 0 && previewC500 <= 1, 'preview count should be 0-1');
  print('  level 500: main=$mainC500, tail=$tailC500, preview=$previewC500');
  print('  ✓ 成语数量选择正确');

  // 测试 7：边界值 - 高等级 base=50
  print('\n--- 测试 7: 高等级边界 ---');
  final rMax = SpiralDifficulty.calculate(10000);
  assert(rMax.baseDifficulty == 50, 'level 10000 base should be 50');
  assert(rMax.tailMax > 0, 'base 50 should have tail');
  assert(rMax.previewMax == 0, 'base 50 should have no preview (base >= 45)');
  print('  level 10000: base=${rMax.baseDifficulty}, '
      'tail=${rMax.tailMin}-${rMax.tailMax}, '
      'preview=${rMax.previewMin}-${rMax.previewMax}');
  print('  ✓ 高等级边界正确');

  print('\n=== 所有测试通过 ===');
}

void _testBaseDifficulty(int level, int expected, String label) {
  final result = SpiralDifficulty.calculate(level);
  final pass = result.baseDifficulty == expected;
  final icon = pass ? '✓' : '✗';
  print('  $icon $label: base=${result.baseDifficulty} (expected $expected)');
  assert(pass, '$label: expected base $expected, got ${result.baseDifficulty}');
}

import 'package:idiom_crossword/src/engine/distractor_engine.dart';

/// 干扰字引擎测试

void main() {
  final engine = DistractorEngine();

  print('=== 干扰字引擎测试 ===\n');

  // 测试 1：单个字干扰
  print('--- 测试 1: 单字干扰生成 ---');
  final words = ['画', '蛇', '添', '足', '守', '株', '待', '兔'];
  for (final w in words) {
    final distractors = engine.generate(w,
        count: 3,
        allAnswerChars: words);
    print('  $w → ${distractors.join(", ")}');
  }

  // 测试 2：候选字盘生成
  print('\n--- 测试 2: 候选字盘 ---');
  final correctAnswers = ['画', '蛇', '添', '足', '守', '株', '待', '兔'];
  final board = engine.generateCandidateBoard(
    correctAnswers: correctAnswers,
    rows: 3,
    countPerRow: 8,
  );

  for (int r = 0; r < board.length; r++) {
    final row = board[r];
    final marked = row.map((c) {
      if (correctAnswers.contains(c)) {
        return '[$c]';  // 正确答案标记
      }
      return ' $c ';
    }).join(' ');
    print('  第${r + 1}行: $marked');
  }

  // 验证：所有正确答案都在候选盘里
  final allCandidates = board.expand((row) => row).toSet();
  final missing = correctAnswers.where((a) => !allCandidates.contains(a)).toList();
  if (missing.isEmpty) {
    print('\n  ✓ 所有正确答案已包含在候选盘中');
  } else {
    print('\n  ✗ 缺失: $missing');
  }

  // 验证：干扰字没有重复
  final duplicates = <String>{};
  final seen = <String>{};
  for (final c in allCandidates) {
    if (seen.contains(c)) duplicates.add(c);
    seen.add(c);
  }
  if (duplicates.isEmpty) {
    print('  ✓ 候选盘无重复字');
  } else {
    print('  ✗ 重复字: $duplicates');
  }

  print('\n--- 测试 3: 核心混淆字对验证 ---');
  // 验证一些著名的混淆对确实存在于数据中
  final famousPairs = [
    ('未', '末'),
    ('己', '已'),
    ('大', '太'),
    ('人', '入'),
    ('千', '干'),
    ('兔', '免'),
    ('拔', '拨'),
    ('折', '拆'),
    ('辨', '辩'),
    ('候', '侯'),
  ];
  for (final (a, b) in famousPairs) {
    final distractors = engine.generate(a, count: 5, allAnswerChars: []);
    final found = distractors.contains(b);
    print('  $a ${found ? '→' : '✗'} $b ${found ? '' : '(未找到)'}');
  }
}

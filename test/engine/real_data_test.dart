/// 用真实成语数据实测关卡生成器

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:idiom_crossword/src/engine/grid_engine.dart';
import 'package:idiom_crossword/src/engine/generator.dart';

void main() {
  print('=== 关卡生成器实测（29502条真实成语）===\n');

  // 1. 加载数据
  final jsonStr = File(
      r'D:\HanaWorkspace\idiom_crossword\assets\data\scoring_progress.json')
      .readAsStringSync();
  final Map<String, dynamic> rawData = json.decode(jsonStr);
  final scores = rawData['scores'] as Map<String, dynamic>;
  final rawList = scores.entries
      .where((e) => (e.key as String).length == 4)
      .map((e) => {'word': e.key, 'difficulty': e.value})
      .toList();
  print('加载成语: ${rawList.length} 条');

  // 2. 转换为 Idiom 对象，按难度区间分组
  final allIdioms = <Idiom>[];
  final byDifficulty = <int, List<Idiom>>{};

  for (final item in rawList) {
    final word = item['word'] as String;
    final diff = item['difficulty'] as int;

    final idiom = Idiom(
      text: word,
      difficulty: diff,
    );
    allIdioms.add(idiom);

    final d = idiom.difficulty;
    byDifficulty.putIfAbsent(d, () => []);
    byDifficulty[d]!.add(idiom);
  }
  print('有效成语: ${allIdioms.length} 条\n');

  // 3. 按难度区间实测生成
  final testCases = [
    ('简单关', 10, 25, 5),
    ('中等关', 26, 45, 6),
    ('困难关', 46, 70, 7),
    ('混合关', 15, 60, 6),
  ];

  for (final (label, minDiff, maxDiff, targetCount) in testCases) {
    print('--- $label (难度$minDiff-$maxDiff, 目标${targetCount}个成语) ---');

    // 筛选该难度区间的成语
    final pool = allIdioms
        .where((i) => i.difficulty >= minDiff && i.difficulty <= maxDiff)
        .toList();
    print('  候选池: ${pool.length} 条');

    if (pool.length < targetCount * 3) {
      print('  ⚠ 候选池太小，跳过');
      continue;
    }

    // 尝试生成（最多20次）
    LevelGenerationResult? bestResult;
    var attempts = 0;
    const maxAttempts = 20;

    while (attempts < maxAttempts && bestResult == null) {
      attempts++;
      // 随机抽样（避免整个大池子打 shuffle 太慢）
      pool.shuffle();
      final sample = pool.take(min(500, pool.length)).toList();

      final generator = CrosswordGenerator(idiomPool: sample);
      final level = generator.generate(targetCount, maxAttempts: 200);

      if (level != null) {
        // 计算网格密度（填充格 / 总格）
        var filledCells = 0;
        var totalCells = 0;
        for (var r = 0; r < level.grid.rows; r++) {
          for (var c = 0; c < level.grid.cols; c++) {
            if (level.grid.cellAt(r, c).state != CellState.blocked) {
              totalCells++;
              if (!level.grid.cellAt(r, c).isGiven) {
                filledCells++;
              }
            }
          }
        }
        final density = totalCells > 0 ? filledCells / totalCells : 0.0;

        bestResult = LevelGenerationResult(
          level: level,
          attempt: attempts,
          density: density,
        );
      }
    }

    if (bestResult != null) {
      final lvl = bestResult.level;
      print('  ✓ 生成成功（第${bestResult.attempt}次尝试）');
      print('  成语数: ${lvl.idioms.length}');
      print('  成语: ${lvl.idioms.map((i) => i.text).join(", ")}');
      print('  网格: ${lvl.grid.rows}×${lvl.grid.cols}');
      print('  需填格: ${lvl.fillableCells}');
      print('  填充密度: ${(bestResult.density * 100).toStringAsFixed(0)}%');
      print('  平均难度: ${(lvl.idioms.map((i) => i.difficulty).reduce((a, b) => a + b) / lvl.idioms.length).toStringAsFixed(1)}');

      // 打印网格
      print('  网格可视化:');
      _printGrid(lvl.grid, lvl.placements);
    } else {
      print('  ✗ 生成失败（$maxAttempts 次尝试）');
    }
    print('');
  }

  // 4. 生成质量分析
  print('=== 批量生成质量分析 ===');
  _runBatchTest(allIdioms);
}

/// 打印网格
void _printGrid(CrosswordGrid grid, List<Placement> placements) {
  // 找出实际占用的区域
  var minR = grid.rows, maxR = 0, minC = grid.cols, maxC = 0;
  for (var r = 0; r < grid.rows; r++) {
    for (var c = 0; c < grid.cols; c++) {
      if (grid.cellAt(r, c).state != CellState.blocked) {
        minR = min(minR, r);
        maxR = max(maxR, r);
        minC = min(minC, c);
        maxC = max(maxC, c);
      }
    }
  }

  for (var r = minR; r <= maxR; r++) {
    final buf = StringBuffer('    ');
    for (var c = minC; c <= maxC; c++) {
      final cell = grid.cellAt(r, c);
      if (cell.state == CellState.blocked) {
        buf.write(' · ');
      } else if (cell.isGiven) {
        buf.write('[${cell.character}]');
      } else if (cell.isIntersection) {
        buf.write('⟨${cell.character}⟩');
      } else {
        buf.write(' ${cell.character} ');
      }
    }
    print(buf.toString());
  }
}

/// 批量测试生成成功率
void _runBatchTest(List<Idiom> allIdioms) {
  final difficulties = [25, 40, 55, 70];
  final targets = [5, 6, 7, 8];

  for (final diff in difficulties) {
    for (final target in targets) {
      final pool = allIdioms
          .where((i) => i.difficulty >= diff - 10 && i.difficulty <= diff + 10)
          .toList();

      if (pool.length < target * 3) continue;

      var success = 0;
      const trials = 5;

      for (var t = 0; t < trials; t++) {
        pool.shuffle();
        final sample = pool.take(min(300, pool.length)).toList();
        final generator = CrosswordGenerator(idiomPool: sample);
        final level = generator.generate(target, maxAttempts: 150);
        if (level != null) success++;
      }

      final rate = (success / trials * 100).toStringAsFixed(0);
      final icon = success >= 4 ? '✓' : success >= 2 ? '△' : '✗';
      print('  $icon 难度~$diff, ${target}成语: ${success}/${trials} ($rate%) '
          '[池:${pool.length}]');
    }
  }
}

/// 生成结果包装
class LevelGenerationResult {
  final CrosswordLevel level;
  final int attempt;
  final double density;

  LevelGenerationResult({
    required this.level,
    required this.attempt,
    required this.density,
  });
}

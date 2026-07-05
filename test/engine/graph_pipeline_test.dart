/// 连通图管道：真实数据实测
///
/// 测试不同难度、不同成语数量的生成效果

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:idiom_crossword/src/engine/grid_engine.dart';
import 'package:idiom_crossword/src/engine/graph_pipeline.dart';

void main() {
  print('=== 连通图管道实测（29502条真实成语）===\n');

  // 1. 加载数据
  final jsonStr = File(
    r'D:\HanaWorkspace\idiom_crossword\assets\data\scoring_progress.json',
  ).readAsStringSync();
  final Map<String, dynamic> rawData = json.decode(jsonStr);
  final scores = rawData['scores'] as Map<String, dynamic>;

  final allIdioms = <Idiom>[];
  for (final entry in scores.entries) {
    final word = entry.key;
    if (word.length != 4) continue;
    allIdioms.add(Idiom(text: word, difficulty: (entry.value as num).toInt()));
  }
  print('加载成语: ${allIdioms.length} 条');

  // 2. 构建图（只建一次）
  print('正在构建交叉图...');
  final stopwatch = Stopwatch()..start();
  final pipeline = GraphPipelineGenerator(idiomPool: allIdioms);
  print(
    '图构建完成: ${pipeline.graph.nodeCount} 节点, '
    '${pipeline.graph.uniqueCharCount} 个不同汉字, '
    '耗时 ${stopwatch.elapsedMilliseconds}ms\n',
  );

  // 3. 多场景测试
  final testCases = [
    _TestCase('简单关', 1, 30, 5),
    _TestCase('中等关', 31, 60, 6),
    _TestCase('困难关', 46, 70, 6),
    _TestCase('大师关(严格)', 76, 100, 5),
    _TestCase('大师关(混合)', 76, 100, 6),
    _TestCase('混合难度', 20, 60, 7),
  ];

  for (final tc in testCases) {
    print('--- ${tc.label} (难度${tc.minD}-${tc.maxD}, ${tc.size}成语) ---');

    final useMixed = tc.label.contains('混合');

    final result = pipeline.generate(
      targetSize: tc.size,
      minDifficulty: tc.minD,
      maxDifficulty: tc.maxD,
      maxAttempts: 50,
      allowMixed: useMixed,
      mixedLeafMinDifficulty: tc.minD,
    );

    if (result != null) {
      final lvl = result.level;
      final sg = result.subgraph;
      print('  ✓ 第${result.attempt}次成功');
      print(
        '  成语(${lvl.idioms.length}): ${lvl.idioms.map((i) => i.text).join(", ")}',
      );
      print(
        '  难度: ${lvl.idioms.map((i) => i.difficulty).join(", ")} '
        '(平均${sg.avgDifficulty.toStringAsFixed(0)})',
      );
      print('  网格: ${lvl.grid.rows}×${lvl.grid.cols}');
      print('  需填格: ${lvl.fillableCells}');
      print(
        '  子图密度: ${sg.density.toStringAsFixed(2)} '
        '(${sg.edges.length}/${tc.size * (tc.size - 1) ~/ 2})',
      );

      print('  网格可视化:');
      _printGrid(lvl.grid);
    } else {
      print('  ✗ 生成失败');
    }
    print('');
  }

  // 4. 批量成功率测试
  print('=== 批量成功率测试（各 20 次）===\n');

  final batchTests = [
    (5, 1, 30, '入门'),
    (5, 20, 50, '初级'),
    (6, 30, 60, '中级'),
    (6, 50, 75, '高级'),
    (4, 76, 100, '大师级-严格'),
    (5, 76, 100, '大师级-混合(4+1)'),
  ];

  for (final (size, minD, maxD, label) in batchTests) {
    var success = 0;
    var totalAttempts = 0;
    const trials = 20;

    final useMixed = label.contains('混合');

    for (var t = 0; t < trials; t++) {
      final result = pipeline.generate(
        targetSize: size,
        minDifficulty: minD,
        maxDifficulty: maxD,
        maxAttempts: 30,
        allowMixed: useMixed,
        mixedLeafMinDifficulty: minD,
      );
      totalAttempts += (result?.attempt ?? 5);
      if (result != null) success++;
    }

    final rate = (success / trials * 100).toStringAsFixed(0);
    final avgAtt = (totalAttempts / trials).toStringAsFixed(1);
    final icon = success >= 16
        ? '✓'
        : success >= 8
        ? '△'
        : '✗';
    print(
      '  $icon $label ($size成语, 难度$minD-$maxD): '
      '$success/$trials ($rate%), 平均${avgAtt}次',
    );
  }

  print('\n=== 完成 ===');
}

void _printGrid(CrosswordGrid grid) {
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

class _TestCase {
  final String label;
  final int minD;
  final int maxD;
  final int size;

  const _TestCase(this.label, this.minD, this.maxD, this.size);
}

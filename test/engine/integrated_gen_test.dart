/// 一体化生成器实测：重点测 6-8 成语

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:idiom_crossword/src/engine/grid_engine.dart';
import 'package:idiom_crossword/src/engine/crossing_graph.dart';
import 'package:idiom_crossword/src/engine/integrated_generator.dart';

void main() {
  print('=== 一体化生成器实测 ===\n');

  // 从 SQLite 数据库加载
  final db = r'D:\HanaWorkspace\idiom_crossword\assets\data\idiom_crossword.db';
  final idioms = _loadFromDb(db);

  print('建图...');
  final sw = Stopwatch()..start();
  final graph = CrossingGraph(idioms: idioms);
  final gen = IntegratedGenerator(graph: graph);
  print('图: ${graph.nodeCount}节点, ${graph.uniqueCharCount}字, ${sw.elapsedMilliseconds}ms\n');

  // 测试场景
  final tests = [
    _TC('5成语-简单', 5, 1, 25),
    _TC('5成语-中等', 5, 26, 50),
    _TC('6成语-简单', 6, 1, 30),
    _TC('6成语-中等', 6, 31, 55),
    _TC('7成语-混合', 7, 10, 55),
    _TC('8成语-混合', 8, 10, 60),
  ];

  for (final tc in tests) {
    print('--- ${tc.label} (难度${tc.minD}-${tc.maxD}) ---');
    sw.reset();

    final level = gen.generate(
      targetSize: tc.size,
      minDifficulty: tc.minD,
      maxDifficulty: tc.maxD,
      maxAttempts: 30,
    );

    if (level != null) {
      print('  ✓ ${sw.elapsedMilliseconds}ms');
      print('  成语: ${level.idioms.map((i) => i.text).join(", ")}');
      print('  难度: ${level.idioms.map((i) => i.difficulty).join(", ")}');
      print('  网格: ${level.grid.rows}×${level.grid.cols}');
      print('  需填格: ${level.fillableCells}');
      _printGrid(level.grid);
    } else {
      print('  ✗ 失败');
    }
    print('');
  }

  // 批量成功率
  print('=== 批量成功率 (各30次) ===\n');
  final batch = [
    (5, 1, 30, '5-简单'),
    (5, 20, 55, '5-中等'),
    (6, 1, 35, '6-简单'),
    (6, 20, 60, '6-中等'),
    (7, 10, 55, '7-混合'),
    (8, 10, 65, '8-混合'),
  ];

  for (final (size, minD, maxD, label) in batch) {
    var ok = 0;
    for (var i = 0; i < 30; i++) {
      if (gen.generate(
          targetSize: size,
          minDifficulty: minD,
          maxDifficulty: maxD,
          maxAttempts: 10) != null) {
        ok++;
      }
    }
    final pct = (ok / 30 * 100).toStringAsFixed(0);
    final icon = ok >= 24 ? '✓' : ok >= 15 ? '△' : '✗';
    print('  $icon $label (${size}成语): $ok/30 ($pct%)');
  }
  print('\n=== 完成 ===');
}

List<Idiom> _loadFromDb(String dbPath) {
  final jsonStr = File(
      r'D:\HanaWorkspace\idiom_crossword\assets\data\scoring_progress.json')
      .readAsStringSync();
  final data = json.decode(jsonStr) as Map<String, dynamic>;
  final scores = data['scores'] as Map<String, dynamic>;
  final idioms = <Idiom>[];
  for (final entry in scores.entries) {
    final word = entry.key as String;
    if (word.length != 4) continue;
    idioms.add(Idiom(
      text: word,
      difficulty: (entry.value as num).toInt(),
    ));
  }
  return idioms;
}

void _printGrid(CrosswordGrid grid) {
  var minR = grid.rows, maxR = 0, minC = grid.cols, maxC = 0;
  for (var r = 0; r < grid.rows; r++) {
    for (var c = 0; c < grid.cols; c++) {
      if (grid.cellAt(r, c).state != CellState.blocked) {
        minR = min(minR, r); maxR = max(maxR, r);
        minC = min(minC, c); maxC = max(maxC, c);
      }
    }
  }
  for (var r = minR; r <= maxR; r++) {
    final b = StringBuffer('    ');
    for (var c = minC; c <= maxC; c++) {
      final cell = grid.cellAt(r, c);
      if (cell.state == CellState.blocked) {
        b.write(' · ');
      } else if (cell.isGiven) {
        b.write('[${cell.character}]');
      } else if (cell.isIntersection) {
        b.write('⟨${cell.character}⟩');
      } else {
        b.write(' ${cell.character} ');
      }
    }
    print(b.toString());
  }
}

class _TC {
  final String label;
  final int size;
  final int minD;
  final int maxD;
  const _TC(this.label, this.size, this.minD, this.maxD);
}

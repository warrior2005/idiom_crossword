// 生成各难度段位的关卡样本报告（供人工复核，PLANS 1.6）
//
// 使用：dart run tool/level_samples_report.dart
// 输出：assets/data/level_samples_report.md

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:idiom_crossword/src/engine/crossing_graph.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart';
import 'package:idiom_crossword/src/engine/integrated_generator.dart';

const _samplesPerBand = 3;

void main() {
  final idioms = _loadIdioms();
  final generator = IntegratedGenerator(
    graph: CrossingGraph(idioms: idioms),
    random: Random(20260731),
  );

  const bands = [
    (label: '入门 (1-10)', minD: 1, maxD: 10),
    (label: '进阶 (11-20)', minD: 11, maxD: 20),
    (label: '中等 (21-30)', minD: 21, maxD: 30),
    (label: '高阶 (31-40)', minD: 31, maxD: 40),
    (label: '大师 (41-50)', minD: 41, maxD: 50),
  ];

  final buf = StringBuffer()
    ..writeln('# 关卡样本质量报告')
    ..writeln()
    ..writeln('> 自动生成（种子固定，可复现）。每段位 $_samplesPerBand 关，供人工复核成语合理性、交叉自然度与干扰字质量。')
    ..writeln();

  for (final band in bands) {
    buf.writeln('## ${band.label}\n');
    for (var i = 1; i <= _samplesPerBand; i++) {
      final level = generator.generate(
        targetSize: 5 + (i % 3),
        minDifficulty: band.minD,
        maxDifficulty: band.maxD,
        maxAttempts: 30,
        levelNumber: i,
      );
      if (level == null) {
        buf.writeln('### 样本 $i：生成失败\n');
        continue;
      }
      buf.writeln('### 样本 $i（${level.placements.length} 条成语）\n');
      buf.writeln('| 成语 | 难度 | 方向 | 起点 |');
      buf.writeln('|------|------|------|------|');
      for (final p in level.placements) {
        final dir = p.direction == Direction.horizontal ? '横' : '纵';
        buf.writeln(
          '| ${p.idiom.text} | ${p.idiom.difficulty} | $dir | (${p.startRow},${p.startCol}) |',
        );
      }

      final crossings = <int>[];
      for (final p in level.placements) {
        final count = level.placements
            .where(
              (o) =>
                  o != p &&
                  o.direction != p.direction &&
                  level.grid.findIntersection(p, o) != null,
            )
            .length;
        crossings.add(count);
      }
      final avgDifficulty =
          level.placements
              .map((p) => p.idiom.difficulty)
              .reduce((a, b) => a + b) /
          level.placements.length;
      buf.writeln(
        '- 网格：${level.grid.rows}×${level.grid.cols}，需填 ${level.fillableCells} 格，'
        '平均难度 ${avgDifficulty.toStringAsFixed(1)}，'
        '各成语交叉数 ${crossings.join("/")}',
      );
      buf.writeln();
      buf.writeln('```\n${_renderGrid(level.grid)}\n```\n');
    }
  }

  final outPath = 'assets/data/level_samples_report.md';
  File(outPath).writeAsStringSync(buf.toString());
  stdout.writeln('已生成 $outPath');
}

List<Idiom> _loadIdioms() {
  final data =
      json.decode(File('assets/data/scoring_progress.json').readAsStringSync())
          as Map<String, dynamic>;
  final scores = data['scores'] as Map<String, dynamic>;
  final idioms = <Idiom>[];
  for (final entry in scores.entries) {
    if (entry.key.length != 4) continue;
    idioms.add(
      Idiom(text: entry.key, difficulty: (entry.value as num).toInt()),
    );
  }
  return idioms;
}

String _renderGrid(CrosswordGrid grid) {
  final buf = StringBuffer();
  for (var r = 0; r < grid.rows; r++) {
    for (var c = 0; c < grid.cols; c++) {
      final cell = grid.cellAt(r, c);
      if (cell.state == CellState.blocked) {
        buf.write('· ');
      } else if (cell.isGiven) {
        buf.write('[${cell.character}]');
      } else if (cell.isIntersection) {
        buf.write('⟨${cell.character}⟩');
      } else {
        buf.write(' ${cell.character} ');
      }
    }
    buf.writeln();
  }
  return buf.toString();
}

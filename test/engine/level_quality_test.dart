// ignore_for_file: avoid_print

// 各难度段位的关卡生成质量验证

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/crossing_graph.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart';
import 'package:idiom_crossword/src/engine/integrated_generator.dart';

void main() {
  final allIdioms = _loadIdioms();
  final graph = CrossingGraph(idioms: allIdioms);
  final generator = IntegratedGenerator(graph: graph);

  // 段位划分（PRD 4.1 / PLANS 三）：入门 1-10 … 大师 41-50
  const bands = [
    (label: '入门(1-10)', minD: 1, maxD: 10),
    (label: '进阶(11-20)', minD: 11, maxD: 20),
    (label: '中等(21-30)', minD: 21, maxD: 30),
    (label: '高阶(31-40)', minD: 31, maxD: 40),
    (label: '大师(41-50)', minD: 41, maxD: 50),
  ];

  for (final band in bands) {
    test('段位 ${band.label} 生成 10 关并全部合法', () {
      var success = 0;
      final durations = <int>[];

      for (var i = 0; i < 10; i++) {
        final targetSize = 5 + (i % 4); // 5-8
        final sw = Stopwatch()..start();
        final level = generator.generate(
          targetSize: targetSize,
          minDifficulty: band.minD,
          maxDifficulty: band.maxD,
          maxAttempts: 30,
          levelNumber: i + 1,
        );
        sw.stop();
        if (level == null) continue;

        success++;
        durations.add(sw.elapsedMilliseconds);

        // 关卡编号与标题穿透
        expect(level.levelId, i + 1, reason: '${band.label} levelId 应等于关卡号');
        expect(level.title, '第 ${i + 1} 关');

        // 全部成语在难度区间内
        for (final idiom in level.idioms) {
          expect(
            idiom.difficulty,
            inInclusiveRange(band.minD, band.maxD),
            reason: '${band.label} 成语 ${idiom.text} 难度应落在区间内',
          );
        }

        // 每个成语的字都正确落入网格
        for (final placement in level.placements) {
          for (var k = 0; k < placement.idiom.text.length; k++) {
            final (r, c) = placement.cellAt(k);
            final cell = level.grid.cellAt(r, c);
            expect(cell.state, CellState.filled);
            expect(cell.character, placement.idiom.text[k]);
          }
        }

        // 连通性：每个成语至少与另一个成语有交叉
        expect(level.placements.length, targetSize);
        for (final placement in level.placements) {
          final hasCross = level.placements.any((other) =>
              other != placement &&
              level.grid.findIntersection(placement, other) != null);
          expect(hasCross, isTrue,
              reason: '${placement.idiom.text} 应有交叉点');
        }

        // 起始提示字非空且不剧透全部答案
        expect(level.givenCharacters, isNotEmpty);
        expect(level.fillableCells, greaterThan(0));
      }

      expect(success, greaterThanOrEqualTo(8),
          reason: '${band.label} 成功率应 ≥ 80%，实际 $success/10');
      final avg = durations.isEmpty
          ? 0
          : durations.reduce((a, b) => a + b) ~/ durations.length;
      print('  ${band.label}: $success/10 成功，平均生成 ${avg}ms');
    });
  }
}

List<Idiom> _loadIdioms() {
  final data = json.decode(
    File('assets/data/scoring_progress.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final scores = data['scores'] as Map<String, dynamic>;
  final idioms = <Idiom>[];
  for (final entry in scores.entries) {
    if (entry.key.length != 4) continue;
    idioms.add(Idiom(text: entry.key, difficulty: (entry.value as num).toInt()));
  }
  return idioms;
}

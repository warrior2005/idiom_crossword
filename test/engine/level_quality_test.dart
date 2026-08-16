// ignore_for_file: avoid_print

// 各难度段位的关卡生成质量验证

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/crossing_graph.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart';
import 'package:idiom_crossword/src/engine/integrated_generator.dart';
import 'package:idiom_crossword/src/engine/spiral_difficulty.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';

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
        final seenTexts = <String>{};
        for (final idiom in level.idioms) {
          expect(
            idiom.difficulty,
            inInclusiveRange(band.minD, band.maxD),
            reason: '${band.label} 成语 ${idiom.text} 难度应落在区间内',
          );
          expect(idiom.text.length, 4, reason: '成语应为四字');
          expect(
            seenTexts.add(idiom.text),
            isTrue,
            reason: '${band.label} 关卡内成语 ${idiom.text} 不应重复',
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
        expect(
          level.hasAmbiguousAdjacency,
          isFalse,
          reason: '${band.label} 布局不应出现同向紧邻或首尾相连',
        );
        for (final placement in level.placements) {
          final hasCross = level.placements.any(
            (other) =>
                other != placement &&
                level.grid.findIntersection(placement, other) != null,
          );
          expect(hasCross, isTrue, reason: '${placement.idiom.text} 应有交叉点');
        }

        // 起始提示字非空且不剧透全部答案
        expect(level.givenCharacters, isNotEmpty);
        expect(level.fillableCells, greaterThan(0));

        // 提示比例合理（太多提示失去挑战，太少无法起手）
        final filledCount = level.placements
            .expand((p) => p.cells)
            .toSet()
            .length;
        var givenCells = 0;
        for (var r = 0; r < level.grid.rows; r++) {
          for (var c = 0; c < level.grid.cols; c++) {
            if (level.grid.cellAt(r, c).isGiven) givenCells++;
          }
        }
        final givenRatio = filledCount == 0 ? 0.0 : givenCells / filledCount;
        expect(
          givenRatio,
          inInclusiveRange(0.15, 0.6),
          reason: '${band.label} 提示比例应合理，实际 ${givenRatio.toStringAsFixed(2)}',
        );
      }

      expect(
        success,
        greaterThanOrEqualTo(8),
        reason: '${band.label} 成功率应 ≥ 80%，实际 $success/10',
      );
      final avg = durations.isEmpty
          ? 0
          : durations.reduce((a, b) => a + b) ~/ durations.length;
      print('  ${band.label}: $success/10 成功，平均生成 ${avg}ms');
    });
  }

  for (var bandIndex = 0; bandIndex < bands.length; bandIndex++) {
    final band = bands[bandIndex];
    test('12 词关卡 ${band.label} 保持紧凑且可生成', () {
      final compactGenerator = IntegratedGenerator(
        graph: graph,
        random: Random(20260815 + bandIndex),
      );
      var success = 0;
      var maxSideTotal = 0;
      var imbalanceTotal = 0;
      var multiCrossTotal = 0;

      for (var i = 0; i < 10; i++) {
        final level = compactGenerator.generate(
          targetSize: 12,
          minDifficulty: band.minD,
          maxDifficulty: band.maxD,
          maxAttempts: 50,
          levelNumber: i + 1,
        );
        if (level == null) continue;
        success++;
        final (rows, cols) = _usedDimensions(level);
        maxSideTotal += max(rows, cols);
        imbalanceTotal += (rows - cols).abs();
        multiCrossTotal += level.multiCrossingPlacementCount;
        expect(level.hasAmbiguousAdjacency, isFalse);
      }

      expect(success, greaterThanOrEqualTo(9));
      expect(maxSideTotal / success, lessThanOrEqualTo(10.5));
      expect(imbalanceTotal / success, lessThanOrEqualTo(2.0));
      expect(multiCrossTotal / success, greaterThanOrEqualTo(6.0));
    });
  }

  test('同一种子生成结果确定（每日挑战全服同题）', () {
    const seed = 20454;
    final gen1 = IntegratedGenerator(
      graph: CrossingGraph(idioms: allIdioms),
      random: Random(seed),
    );
    final gen2 = IntegratedGenerator(
      graph: CrossingGraph(idioms: allIdioms),
      random: Random(seed),
    );

    final l1 = gen1.generate(
      targetSize: 6,
      minDifficulty: 10,
      maxDifficulty: 40,
      maxAttempts: 30,
      levelNumber: dailyLevelOffset + seed,
    );
    final l2 = gen2.generate(
      targetSize: 6,
      minDifficulty: 10,
      maxDifficulty: 40,
      maxAttempts: 30,
      levelNumber: dailyLevelOffset + seed,
    );

    expect(l1, isNotNull);
    String signature(CrosswordLevel level) => level.placements
        .map(
          (p) =>
              '${p.idiom.text}@${p.startRow},${p.startCol}:${p.direction.index}',
        )
        .join('|');
    expect(signature(l1!), signature(l2!));
  });

  test('每日挑战关卡号与种子由日期推导', () {
    final now = DateTime.utc(2026, 7, 31);
    expect(epochDay(now), dailyLevelNumber(now) - dailyLevelOffset);
    expect(dailyLevelNumber(DateTime.utc(1970)), dailyLevelOffset);
    expect(dailyLevelNumber(now), greaterThan(dailyLevelOffset));
  });

  test('螺旋关卡包含长尾/预览混排（设计 §4.3）', () {
    // 固定种子保证确定性（种子 16 已探测：严格间距下可生成混排）
    final spiralGen = IntegratedGenerator(
      graph: CrossingGraph(idioms: allIdioms),
      random: Random(16),
    );
    const levelNumber = 6000; // base 30：tail 20-25，preview 33-35
    final spiral = SpiralDifficulty.calculate(levelNumber);

    var mixed = false;
    for (var i = 0; i < 6; i++) {
      final level = spiralGen.generateSpiral(
        levelNumber: levelNumber,
        maxAttempts: 30,
      );
      expect(level, isNotNull, reason: '6000 关应能生成');
      final inMain = level!.idioms
          .where(
            (x) =>
                x.difficulty >= spiral.mainMin &&
                x.difficulty <= spiral.mainMax,
          )
          .length;
      if (inMain < level.idioms.length) {
        mixed = true;
        break;
      }
    }
    expect(mixed, isTrue, reason: '高阶螺旋关应包含主体区间外的长尾/预览成语');
  });

  test('10000 关后仍可继续生成关卡', () {
    final generator = IntegratedGenerator(
      graph: graph,
      random: Random(20260806),
    );
    for (final levelNumber in [10001, 20001, 50001]) {
      CrosswordLevel? level;
      for (var attempt = 0; attempt < 5 && level == null; attempt++) {
        level = generator.generateSpiral(
          levelNumber: levelNumber,
          maxAttempts: 60,
        );
      }
      expect(level, isNotNull, reason: '$levelNumber 关应能生成');
      expect(level!.levelId, levelNumber);
    }
  });
}

List<Idiom> _loadIdioms() {
  final data =
      json.decode(File('data/scoring_progress.json').readAsStringSync())
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

(int, int) _usedDimensions(CrosswordLevel level) {
  final cells = level.placements.expand((placement) => placement.cells);
  var minRow = level.grid.rows;
  var maxRow = -1;
  var minCol = level.grid.cols;
  var maxCol = -1;
  for (final (row, col) in cells) {
    minRow = min(minRow, row);
    maxRow = max(maxRow, row);
    minCol = min(minCol, col);
    maxCol = max(maxCol, col);
  }
  return (maxRow - minRow + 1, maxCol - minCol + 1);
}

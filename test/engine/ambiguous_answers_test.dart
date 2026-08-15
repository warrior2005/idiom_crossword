import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/crossing_graph.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart';
import 'package:idiom_crossword/src/engine/integrated_generator.dart';

void main() {
  test('相同约束的两个槽位可以互换答案', () {
    final level = _buildAmbiguousLevel();

    expect(level.hasInterchangeableAnswers, isTrue);
    expect(level.allowedCharactersAt(1, 1, const {}), {'马', '丘'});
    expect(level.allowedCharactersAt(2, 1, const {(1, 1): '丘'}), {'之'});
    expect(
      level.matchesAnswers({
        (0, 2): '心',
        (0, 4): '意',
        (1, 1): '马',
        (2, 1): '当',
        (3, 1): '先',
        (1, 3): '丘',
        (2, 3): '之',
        (3, 3): '貉',
      }),
      isTrue,
    );
  });

  test('互换槽位不能重复使用同一答案', () {
    final level = _buildAmbiguousLevel();

    expect(
      level.matchesAnswers({
        (0, 2): '心',
        (0, 4): '意',
        (1, 1): '马',
        (2, 1): '当',
        (3, 1): '先',
        (1, 3): '马',
        (2, 3): '当',
        (3, 3): '先',
      }),
      isFalse,
    );
  });

  test('增加可区分的交叉约束后不再可互换', () {
    final level = _buildAmbiguousLevel();
    level.grid.cellAt(3, 1).isIntersection = true;

    expect(level.hasInterchangeableAnswers, isFalse);
  });

  test('生成器放弃无法区分的布局', () {
    const idioms = [
      Idiom(text: '一心一意'),
      Idiom(text: '一马当先'),
      Idiom(text: '一丘之貉'),
    ];
    final generator = IntegratedGenerator(
      graph: CrossingGraph(idioms: idioms),
      random: Random(1),
    );

    expect(
      generator.generate(
        targetSize: 3,
        minDifficulty: 1,
        maxDifficulty: 5,
        maxAttempts: 10,
      ),
      isNull,
    );
  });
}

CrosswordLevel _buildAmbiguousLevel() {
  final grid = CrosswordGrid(rows: 5, cols: 5);
  const horizontal = Idiom(text: '一心一意');
  const left = Idiom(text: '一马当先');
  const right = Idiom(text: '一丘之貉');
  const placements = [
    Placement(
      idiom: horizontal,
      startRow: 0,
      startCol: 1,
      direction: Direction.horizontal,
    ),
    Placement(
      idiom: left,
      startRow: 0,
      startCol: 1,
      direction: Direction.vertical,
    ),
    Placement(
      idiom: right,
      startRow: 0,
      startCol: 3,
      direction: Direction.vertical,
    ),
  ];

  for (final placement in placements) {
    for (var k = 0; k < placement.idiom.text.length; k++) {
      final (row, col) = placement.cellAt(k);
      final cell = grid.cellAt(row, col);
      if (cell.state == CellState.filled) cell.isIntersection = true;
      cell.state = CellState.filled;
      cell.character = placement.idiom.text[k];
    }
  }
  grid.cellAt(0, 1).isGiven = true;
  grid.cellAt(0, 3).isGiven = true;

  return CrosswordLevel(
    levelId: 1,
    grid: grid,
    placements: placements,
    givenCharacters: {'一'},
    title: '测试',
  );
}

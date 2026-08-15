import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart';

void main() {
  test('三个字的伪连续片段不构成歧义', () {
    final grid = CrosswordGrid(rows: 3, cols: 4);
    const words = ['ABCD', 'EFGH', 'IJKL'];
    final placements = <Placement>[];

    for (var row = 0; row < words.length; row++) {
      final idiom = Idiom(text: words[row]);
      placements.add(
        Placement(
          idiom: idiom,
          startRow: row,
          startCol: 0,
          direction: Direction.horizontal,
        ),
      );
      for (var col = 0; col < idiom.text.length; col++) {
        final cell = grid.cellAt(row, col);
        cell
          ..state = CellState.filled
          ..character = idiom.text[col];
      }
    }

    final level = CrosswordLevel(
      levelId: 1,
      grid: grid,
      placements: placements,
      givenCharacters: const {},
      title: '',
    );

    expect(level.hasAmbiguousAdjacency, isFalse);
  });

  test('紧邻的同向成语会形成可视歧义', () {
    final grid = CrosswordGrid(rows: 4, cols: 4);
    const words = ['ABCD', 'EFGH', 'IJKL', 'MNOP'];
    final placements = <Placement>[];

    for (var row = 0; row < words.length; row++) {
      final idiom = Idiom(text: words[row]);
      placements.add(
        Placement(
          idiom: idiom,
          startRow: row,
          startCol: 0,
          direction: Direction.horizontal,
        ),
      );
      for (var col = 0; col < idiom.text.length; col++) {
        final cell = grid.cellAt(row, col);
        cell
          ..state = CellState.filled
          ..character = idiom.text[col];
      }
    }

    final level = CrosswordLevel(
      levelId: 1,
      grid: grid,
      placements: placements,
      givenCharacters: const {},
      title: '',
    );

    expect(level.hasAmbiguousAdjacency, isTrue);
  });

  test('首尾相连的同行成语会形成可视歧义', () {
    final grid = CrosswordGrid(rows: 1, cols: 8);
    const first = Idiom(text: 'ABCD');
    const second = Idiom(text: 'EFGH');
    const placements = [
      Placement(
        idiom: first,
        startRow: 0,
        startCol: 0,
        direction: Direction.horizontal,
      ),
      Placement(
        idiom: second,
        startRow: 0,
        startCol: 4,
        direction: Direction.horizontal,
      ),
    ];
    for (var col = 0; col < 8; col++) {
      final cell = grid.cellAt(0, col);
      cell
        ..state = CellState.filled
        ..character = 'ABCDEFGH'[col];
    }

    final level = CrosswordLevel(
      levelId: 1,
      grid: grid,
      placements: placements,
      givenCharacters: const {},
      title: '',
    );

    expect(level.hasAmbiguousAdjacency, isTrue);
  });
}

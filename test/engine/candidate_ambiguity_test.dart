import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/candidate_ambiguity.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart';

void main() {
  test('纯干扰字能组成关外成语时排除其中一个干扰字', () {
    final level = _singleWordLevel('有始有终');
    expect(candidatePatternsForLevel(level), {'有___'});
    final ambiguities = findCandidateAmbiguities(
      level: level,
      dictionaryWords: const ['有气无力'],
      availableChars: const ['始', '有', '终', '气', '无', '力'],
    );

    expect(ambiguities.map((item) => item.word), contains('有气无力'));
    expect(
      distractorCharsToExclude(ambiguities, {'始', '有', '终'}),
      hasLength(1),
    );
  });

  test('答案字能组成关外成语时增加区分提示而不丢弃关卡', () {
    final level = _answerPoolAmbiguousLevel();
    final resolved = addDisambiguatingGivens(
      level: level,
      dictionaryWords: const ['有气无力'],
    );

    expect(resolved.placements.length, level.placements.length);
    expect(resolved.fillableCells, level.fillableCells - 1);
    expect(level.fillableCells, 9, reason: '不能修改传入的原关卡');
    expect(
      findCandidateAmbiguities(
        level: resolved,
        dictionaryWords: const ['有气无力'],
        availableChars: _answerChars(resolved),
      ),
      isEmpty,
    );
  });

  test('候选字按数量匹配，单个字不能重复使用', () {
    final level = _singleWordLevel('一心一意');

    expect(
      findCandidateAmbiguities(
        level: level,
        dictionaryWords: const ['一心心意'],
        availableChars: const ['心', '意'],
      ),
      isEmpty,
    );
  });

  test('区分提示不能直接完成成语，改为提示字符来源格', () {
    final level = _lastCellAmbiguousLevel();
    final resolved = addDisambiguatingGivens(
      level: level,
      dictionaryWords: const ['有气无力'],
    );

    expect(resolved.grid.cellAt(0, 3).isGiven, isFalse);
    expect(resolved.grid.cellAt(1, 1).isGiven, isTrue);
    for (final placement in resolved.placements) {
      expect(
        placement.cells.every(
          (position) => resolved.grid.cellAt(position.$1, position.$2).isGiven,
        ),
        isFalse,
      );
    }
  });
}

CrosswordLevel _singleWordLevel(String word) {
  final grid = CrosswordGrid(rows: 1, cols: 4);
  final placement = Placement(
    idiom: Idiom(text: word),
    startRow: 0,
    startCol: 0,
    direction: Direction.horizontal,
  );
  for (var k = 0; k < word.length; k++) {
    final cell = grid.cellAt(0, k);
    cell
      ..state = CellState.filled
      ..character = word[k]
      ..isGiven = k == 0;
  }
  return CrosswordLevel(
    levelId: 1,
    grid: grid,
    placements: [placement],
    givenCharacters: {word[0]},
    title: '',
  );
}

CrosswordLevel _answerPoolAmbiguousLevel() {
  final grid = CrosswordGrid(rows: 3, cols: 4);
  const words = ['有备无患', '甲气乙丙', '丁力戊己'];
  final placements = <Placement>[];
  for (var row = 0; row < words.length; row++) {
    final word = words[row];
    placements.add(
      Placement(
        idiom: Idiom(text: word),
        startRow: row,
        startCol: 0,
        direction: Direction.horizontal,
      ),
    );
    for (var k = 0; k < word.length; k++) {
      final cell = grid.cellAt(row, k);
      cell
        ..state = CellState.filled
        ..character = word[k]
        ..isGiven = k == 0;
    }
  }
  return CrosswordLevel(
    levelId: 1,
    grid: grid,
    placements: placements,
    givenCharacters: const {'有', '甲', '丁'},
    title: '',
  );
}

CrosswordLevel _lastCellAmbiguousLevel() {
  final grid = CrosswordGrid(rows: 2, cols: 4);
  const words = ['有气无患', '甲力乙丙'];
  final placements = <Placement>[];
  for (var row = 0; row < words.length; row++) {
    final word = words[row];
    placements.add(
      Placement(
        idiom: Idiom(text: word),
        startRow: row,
        startCol: 0,
        direction: Direction.horizontal,
      ),
    );
    for (var k = 0; k < word.length; k++) {
      final cell = grid.cellAt(row, k);
      cell
        ..state = CellState.filled
        ..character = word[k]
        ..isGiven = row == 0 ? k < 3 : k == 0;
    }
  }
  return CrosswordLevel(
    levelId: 1,
    grid: grid,
    placements: placements,
    givenCharacters: const {'有', '气', '无', '甲'},
    title: '',
  );
}

List<String> _answerChars(CrosswordLevel level) {
  final result = <(int, int), String>{};
  for (final placement in level.placements) {
    for (var k = 0; k < placement.idiom.text.length; k++) {
      final position = placement.cellAt(k);
      if (!level.grid.cellAt(position.$1, position.$2).isGiven) {
        result[position] = placement.idiom.text[k];
      }
    }
  }
  return result.values.toList();
}

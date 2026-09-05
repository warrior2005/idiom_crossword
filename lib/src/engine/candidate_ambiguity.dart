import 'grid_engine.dart';

typedef CandidateAmbiguity = ({Placement placement, String word});

/// 每个槽位用于查询数据库候选词的模式；`_` 表示待填位置。
Set<String> candidatePatternsForLevel(CrosswordLevel level) {
  return {
    for (final placement in level.placements)
      _patternForPlacement(level, placement),
  };
}

String _patternForPlacement(CrosswordLevel level, Placement placement) {
  final pattern = StringBuffer();
  for (var k = 0; k < placement.idiom.text.length; k++) {
    final (row, col) = placement.cellAt(k);
    final cell = level.grid.cellAt(row, col);
    pattern.write(cell.isGiven || cell.isIntersection ? cell.character : '_');
  }
  return pattern.toString();
}

/// 找出候选字池可以拼成、但不属于该槽位答案的数据库成语。
List<CandidateAmbiguity> findCandidateAmbiguities({
  required CrosswordLevel level,
  required Iterable<String> dictionaryWords,
  required Iterable<String> availableChars,
  Map<String, Set<String>> allowedAlternatives = const {},
}) {
  final availableCounts = _counts(availableChars);
  final result = <CandidateAmbiguity>[];

  for (final placement in level.placements) {
    final answer = placement.idiom.text;
    final allowed = {answer, ...?allowedAlternatives[answer]};
    for (final word in dictionaryWords) {
      if (allowed.contains(word) || word.length != answer.length) continue;
      if (!_fitsFixedCells(level, placement, word)) continue;

      final required = <String>[];
      for (var k = 0; k < word.length; k++) {
        final (row, col) = placement.cellAt(k);
        if (!level.grid.cellAt(row, col).isGiven) required.add(word[k]);
      }
      if (_containsCounts(availableCounts, _counts(required))) {
        result.add((placement: placement, word: word));
      }
    }
  }
  return result;
}

/// 对仅由本关答案字就能形成的歧义，增加尽量少的区分提示。
///
/// 返回新关卡，不改变生成器的成功/失败结果。
CrosswordLevel addDisambiguatingGivens({
  required CrosswordLevel level,
  required Iterable<String> dictionaryWords,
  Map<String, Set<String>> allowedAlternatives = const {},
}) {
  final grid = _copyGrid(level.grid);
  final resolved = CrosswordLevel(
    levelId: level.levelId,
    grid: grid,
    placements: level.placements,
    givenCharacters: {
      for (var r = 0; r < grid.rows; r++)
        for (var c = 0; c < grid.cols; c++)
          if (grid.cellAt(r, c).isGiven) grid.cellAt(r, c).character,
    },
    title: level.title,
    storyHint: level.storyHint,
  );

  while (true) {
    final answers = _correctAnswerChars(resolved);
    final ambiguities = findCandidateAmbiguities(
      level: resolved,
      dictionaryWords: dictionaryWords,
      availableChars: answers,
      allowedAlternatives: allowedAlternatives,
    );
    if (ambiguities.isEmpty) break;

    final scores = <(int, int), int>{};
    for (final ambiguity in ambiguities) {
      for (var k = 0; k < ambiguity.word.length; k++) {
        final position = ambiguity.placement.cellAt(k);
        final cell = grid.cellAt(position.$1, position.$2);
        if (!cell.isGiven &&
            !cell.isIntersection &&
            !_wouldCompleteIdiom(resolved, position) &&
            ambiguity.word[k] != ambiguity.placement.idiom.text[k]) {
          scores.update(position, (score) => score + 1, ifAbsent: () => 1);
        }
      }
    }
    if (scores.isEmpty) {
      _scoreSupplierClues(resolved, ambiguities, answers, scores);
    }
    if (scores.isEmpty) break;
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final cell = grid.cellAt(best.key.$1, best.key.$2);
    cell.isGiven = true;
    resolved.givenCharacters.add(cell.character);
  }
  return resolved;
}

void _scoreSupplierClues(
  CrosswordLevel level,
  Iterable<CandidateAmbiguity> ambiguities,
  List<String> availableChars,
  Map<(int, int), int> scores,
) {
  final availableCounts = _counts(availableChars);
  final answerCells = <(int, int), String>{};
  for (final placement in level.placements) {
    for (var k = 0; k < placement.idiom.text.length; k++) {
      final position = placement.cellAt(k);
      final cell = level.grid.cellAt(position.$1, position.$2);
      if (!cell.isGiven) answerCells[position] = cell.character;
    }
  }

  for (final ambiguity in ambiguities) {
    final required = <String>[];
    for (var k = 0; k < ambiguity.word.length; k++) {
      final position = ambiguity.placement.cellAt(k);
      if (!level.grid.cellAt(position.$1, position.$2).isGiven) {
        required.add(ambiguity.word[k]);
      }
    }
    final requiredCounts = _counts(required);
    for (final entry in requiredCounts.entries) {
      if (entry.value != availableCounts[entry.key]) continue;
      for (final answerCell in answerCells.entries) {
        final position = answerCell.key;
        final cell = level.grid.cellAt(position.$1, position.$2);
        if (answerCell.value == entry.key &&
            !ambiguity.placement.cells.contains(position) &&
            !cell.isIntersection &&
            !_wouldCompleteIdiom(level, position)) {
          scores.update(position, (score) => score + 1, ifAbsent: () => 1);
        }
      }
    }
  }
}

bool _wouldCompleteIdiom(CrosswordLevel level, (int, int) position) {
  for (final placement in level.placements) {
    if (!placement.cells.contains(position)) continue;
    if (placement.cells.every((cellPosition) {
      return cellPosition == position ||
          level.grid.cellAt(cellPosition.$1, cellPosition.$2).isGiven;
    })) {
      return true;
    }
  }
  return false;
}

/// 返回至少需要从干扰池排除的字；正确答案字不会被排除。
Set<String> distractorCharsToExclude(
  Iterable<CandidateAmbiguity> ambiguities,
  Set<String> answerChars,
) {
  final excluded = <String>{};
  for (final ambiguity in ambiguities) {
    final placement = ambiguity.placement;
    for (var k = 0; k < ambiguity.word.length; k++) {
      final char = ambiguity.word[k];
      if (char != placement.idiom.text[k] && !answerChars.contains(char)) {
        excluded.add(char);
        break;
      }
    }
  }
  return excluded;
}

List<String> _correctAnswerChars(CrosswordLevel level) {
  final cells = <(int, int), String>{};
  for (final placement in level.placements) {
    for (var k = 0; k < placement.idiom.text.length; k++) {
      final position = placement.cellAt(k);
      if (!level.grid.cellAt(position.$1, position.$2).isGiven) {
        cells[position] = placement.idiom.text[k];
      }
    }
  }
  return cells.values.toList();
}

bool _fitsFixedCells(CrosswordLevel level, Placement placement, String word) {
  for (var k = 0; k < word.length; k++) {
    final (row, col) = placement.cellAt(k);
    final cell = level.grid.cellAt(row, col);
    if ((cell.isGiven || cell.isIntersection) && word[k] != cell.character) {
      return false;
    }
  }
  return true;
}

Map<String, int> _counts(Iterable<String> chars) {
  final result = <String, int>{};
  for (final char in chars) {
    result.update(char, (count) => count + 1, ifAbsent: () => 1);
  }
  return result;
}

bool _containsCounts(Map<String, int> available, Map<String, int> required) {
  for (final entry in required.entries) {
    if ((available[entry.key] ?? 0) < entry.value) return false;
  }
  return true;
}

CrosswordGrid _copyGrid(CrosswordGrid source) {
  final copy = CrosswordGrid(rows: source.rows, cols: source.cols);
  for (var r = 0; r < source.rows; r++) {
    for (var c = 0; c < source.cols; c++) {
      final from = source.cellAt(r, c);
      final to = copy.cellAt(r, c);
      to
        ..character = from.character
        ..state = from.state
        ..isIntersection = from.isIntersection
        ..isGiven = from.isGiven;
    }
  }
  return copy;
}

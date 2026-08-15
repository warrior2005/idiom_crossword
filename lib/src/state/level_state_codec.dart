import 'dart:convert';

import '../engine/grid_engine.dart';

/// CrosswordLevel 与游戏进行状态（答案、候选盘、历史等）的 JSON 编解码。
///
/// 用于"断点续玩"：退出未完成关卡时把完整关卡定义 + 玩家进度落库，
/// 下次进入同一关卡时原样恢复。

/// 序列化完整关卡定义
String encodeLevel(CrosswordLevel level) {
  final grid = level.grid;
  final cells = <List<Object?>>[];
  for (var r = 0; r < grid.rows; r++) {
    for (var c = 0; c < grid.cols; c++) {
      final cell = grid.cellAt(r, c);
      cells.add([
        cell.state.index,
        cell.character,
        cell.isIntersection ? 1 : 0,
        cell.isGiven ? 1 : 0,
      ]);
    }
  }

  final placements = level.placements
      .map(
        (p) => [
          p.idiom.text,
          p.idiom.pinyin,
          p.idiom.meaning,
          p.idiom.difficulty,
          p.idiom.source,
          p.startRow,
          p.startCol,
          p.direction.index,
        ],
      )
      .toList();

  return jsonEncode({
    'levelId': level.levelId,
    'title': level.title,
    'rows': grid.rows,
    'cols': grid.cols,
    'cells': cells,
    'placements': placements,
    'storyHint': level.storyHint,
  });
}

/// 反序列化关卡定义；数据损坏时返回 null
CrosswordLevel? decodeLevel(String source) {
  try {
    final data = jsonDecode(source) as Map<String, dynamic>;
    final rows = data['rows'] as int;
    final cols = data['cols'] as int;
    final grid = CrosswordGrid(rows: rows, cols: cols);

    final rawCells = data['cells'] as List;
    for (var i = 0; i < rawCells.length; i++) {
      final d = rawCells[i] as List;
      final cell = grid.cellAt(i ~/ cols, i % cols);
      cell.state = CellState.values[d[0] as int];
      cell.character = d[1] as String;
      cell.isIntersection = (d[2] as int) == 1;
      cell.isGiven = (d[3] as int) == 1;
    }

    final placements = (data['placements'] as List).map((p) {
      final d = p as List;
      return Placement(
        idiom: Idiom(
          text: d[0] as String,
          pinyin: d[1] as String,
          meaning: d[2] as String,
          difficulty: d[3] as int,
          source: d[4] as String,
        ),
        startRow: d[5] as int,
        startCol: d[6] as int,
        direction: Direction.values[d[7] as int],
      );
    }).toList();

    final given = <String>{};
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cell = grid.cellAt(r, c);
        if (cell.isGiven && cell.character.isNotEmpty) {
          given.add(cell.character);
        }
      }
    }

    return CrosswordLevel(
      levelId: data['levelId'] as int,
      grid: grid,
      placements: placements,
      givenCharacters: given,
      title: data['title'] as String,
      storyHint: data['storyHint'] as String?,
    );
  } catch (_) {
    return null;
  }
}

/// 游戏进行状态的快照
class SavedGameState {
  final Map<(int, int), String> answers;
  final Set<(int, int)> usedCandidateSlots;
  final List<({int row, int col, int candRow, int candCol})> fillHistory;
  final Map<(int, int), (int, int)> cellToCandidateSlot;
  final List<List<String>> candidateBoard;
  final int hintUsesThisLevel;
  final int errorsMade;
  final int correctStreak;
  final int totalFills;
  final Set<String> wrongIdiomWords;
  final int lives;
  final int remainingSeconds;
  final bool revived;
  final int reviveUsesThisLevel;
  final int? focusRow;
  final int? focusCol;
  final Direction? direction;

  const SavedGameState({
    required this.answers,
    required this.usedCandidateSlots,
    required this.fillHistory,
    required this.cellToCandidateSlot,
    required this.candidateBoard,
    required this.hintUsesThisLevel,
    required this.errorsMade,
    required this.correctStreak,
    required this.totalFills,
    this.wrongIdiomWords = const {},
    this.lives = 3,
    this.remainingSeconds = 180,
    this.revived = false,
    this.reviveUsesThisLevel = 0,
    this.focusRow,
    this.focusCol,
    this.direction,
  });
}

/// 序列化游戏进行状态
String encodeGameState(SavedGameState state) {
  return jsonEncode({
    'answers': state.answers.entries
        .map((e) => [e.key.$1, e.key.$2, e.value])
        .toList(),
    'used': state.usedCandidateSlots.map((p) => [p.$1, p.$2]).toList(),
    'history': state.fillHistory
        .map((h) => [h.row, h.col, h.candRow, h.candCol])
        .toList(),
    'slots': state.cellToCandidateSlot.entries
        .map((e) => [e.key.$1, e.key.$2, e.value.$1, e.value.$2])
        .toList(),
    'board': state.candidateBoard,
    'hints': state.hintUsesThisLevel,
    'errors': state.errorsMade,
    'streak': state.correctStreak,
    'fills': state.totalFills,
    'wrongWords': state.wrongIdiomWords.toList(),
    'lives': state.lives,
    'time': state.remainingSeconds,
    'revived': state.revived ? 1 : 0,
    'reviveUses': state.reviveUsesThisLevel,
    'focus': (state.focusRow == null || state.focusCol == null)
        ? null
        : [state.focusRow, state.focusCol],
    'dir': state.direction?.index,
  });
}

/// 反序列化游戏进行状态；数据损坏时返回 null
SavedGameState? decodeGameState(String source) {
  try {
    final data = jsonDecode(source) as Map<String, dynamic>;

    final answers = <(int, int), String>{};
    for (final e in data['answers'] as List) {
      final d = e as List;
      answers[(d[0] as int, d[1] as int)] = d[2] as String;
    }

    final used = <(int, int)>{};
    for (final e in data['used'] as List) {
      final d = e as List;
      used.add((d[0] as int, d[1] as int));
    }

    final history = <({int row, int col, int candRow, int candCol})>[];
    for (final e in data['history'] as List) {
      final d = e as List;
      history.add((
        row: d[0] as int,
        col: d[1] as int,
        candRow: d[2] as int,
        candCol: d[3] as int,
      ));
    }

    final slots = <(int, int), (int, int)>{};
    for (final e in data['slots'] as List) {
      final d = e as List;
      slots[(d[0] as int, d[1] as int)] = (d[2] as int, d[3] as int);
    }

    final board = (data['board'] as List)
        .map((row) => (row as List).cast<String>().toList())
        .toList();

    final focus = data['focus'] as List?;
    final dirRaw = data['dir'] as int?;
    return SavedGameState(
      answers: answers,
      usedCandidateSlots: used,
      fillHistory: history,
      cellToCandidateSlot: slots,
      candidateBoard: board,
      hintUsesThisLevel: data['hints'] as int,
      errorsMade: data['errors'] as int,
      correctStreak: data['streak'] as int,
      totalFills: data['fills'] as int? ?? 0,
      wrongIdiomWords: (data['wrongWords'] as List? ?? const [])
          .cast<String>()
          .toSet(),
      lives: data['lives'] as int? ?? 3,
      remainingSeconds: data['time'] as int? ?? 180,
      revived: (data['revived'] as int? ?? 0) == 1,
      reviveUsesThisLevel: data['reviveUses'] as int? ?? 0,
      focusRow: focus == null ? null : focus[0] as int,
      focusCol: focus == null ? null : focus[1] as int,
      direction: dirRaw == null ? null : Direction.values[dirRaw],
    );
  } catch (_) {
    return null;
  }
}

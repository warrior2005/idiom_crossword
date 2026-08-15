/// 交叉填字引擎核心数据结构
///
/// 整个问题的形式化定义：
///   给定成语集合 I = {i₁, i₂, ..., iₙ}，每个成语 iₖ = c₁c₂c₃c₄
///   寻找一个二维网格 G 和路径分配 P = {(iₖ, direction, origin)}
///   满足：
///     1. 所有成语路径都在 G 的边界内
///     2. 任意两条交叉的路径，交叉格子上的汉字一致
///     3. 所有成语构成一个连通图（以交叉点为边）
///     4. 没有孤立成语（每个成语至少与另一个成语交叉）

library;

class Idiom {
  final String text; // 成语原文，如 "画蛇添足"
  final String pinyin; // 拼音
  final String meaning; // 释义
  final int difficulty; // 难度 1-5
  final String source; // 出处

  const Idiom({
    required this.text,
    this.pinyin = '',
    this.meaning = '',
    this.difficulty = 3,
    this.source = '',
  });

  String get firstChar => text[0];
  String get lastChar => text[text.length - 1];
  List<String> get chars => text.split('');

  /// 该字在成语中的位置索引（从 0 开始）
  int indexOfChar(String c) => text.indexOf(c);
}

/// 网格中的一个格子
enum CellState { empty, filled, blocked }

class Cell {
  final int row;
  final int col;
  String character; // 填入的字
  CellState state;
  bool isIntersection; // 是否为交叉点（纵横成语共享）
  bool isGiven; // 是否为系统给出的初始字（提示）

  Cell({
    required this.row,
    required this.col,
    this.character = '',
    this.state = CellState.blocked,
    this.isIntersection = false,
    this.isGiven = false,
  });
}

enum Direction { horizontal, vertical }

/// 一个成语在网格中的放置描述
class Placement {
  final Idiom idiom;
  final int startRow;
  final int startCol;
  final Direction direction;

  const Placement({
    required this.idiom,
    required this.startRow,
    required this.startCol,
    required this.direction,
  });

  /// 该成语占据的所有格子坐标
  List<(int, int)> get cells {
    return List.generate(idiom.text.length, (i) {
      return direction == Direction.horizontal
          ? (startRow, startCol + i)
          : (startRow + i, startCol);
    });
  }

  /// 该成语第 k 个字所在的格子
  (int, int) cellAt(int k) {
    return direction == Direction.horizontal
        ? (startRow, startCol + k)
        : (startRow + k, startCol);
  }
}

/// 填字游戏网格
class CrosswordGrid {
  final int rows;
  final int cols;
  late final List<List<Cell>> cells;

  CrosswordGrid({required this.rows, required this.cols}) {
    cells = List.generate(
      rows,
      (r) => List.generate(cols, (c) => Cell(row: r, col: c)),
    );
  }

  Cell cellAt(int row, int col) => cells[row][col];

  /// 检查某个放置是否与已有成语产生合法交叉
  /// 合法交叉：共享字在同一格子，且汉字一致
  bool isValidPlacement(Placement placement, List<Placement> existing) {
    final cells = placement.cells;
    // 边界检查
    for (var (r, c) in cells) {
      if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
    }
    // 交叉检查
    for (var existingPlacement in existing) {
      final intersection = findIntersection(placement, existingPlacement);
      if (intersection != null) {
        final (pIdx, eIdx) = intersection;
        if (placement.idiom.text[pIdx] != existingPlacement.idiom.text[eIdx]) {
          return false; // 共享字不一致
        }
      }
    }
    return true;
  }

  /// 寻找两个放置的交叉点
  /// 返回 (placementA中字的索引, placementB中字的索引)，无交叉则返回 null
  (int, int)? findIntersection(Placement a, Placement b) {
    if (a.direction == b.direction) return null; // 同向不交叉
    for (int i = 0; i < a.idiom.text.length; i++) {
      for (int j = 0; j < b.idiom.text.length; j++) {
        if (a.cellAt(i) == b.cellAt(j)) return (i, j);
      }
    }
    return null;
  }
}

/// 填字游戏关卡定义（最终产物）
class CrosswordLevel {
  final int levelId;
  final CrosswordGrid grid;
  final List<Placement> placements;
  final Set<String> givenCharacters; // 初始给出的字（提示）
  final String title;
  final String? storyHint; // 隐藏成语的典故提示

  const CrosswordLevel({
    required this.levelId,
    required this.grid,
    required this.placements,
    required this.givenCharacters,
    required this.title,
    this.storyHint,
  });

  /// 本关涉及的所有成语
  List<Idiom> get idioms => placements.map((p) => p.idiom).toList();

  /// 玩家需要填入的格子数
  int get fillableCells {
    int count = 0;
    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        final cell = grid.cellAt(r, c);
        if (cell.state == CellState.filled && !cell.isGiven) count++;
      }
    }
    return count;
  }

  /// 是否存在两个槽位的答案在当前提示/交叉约束下可互换。
  bool get hasInterchangeableAnswers {
    for (var i = 0; i < placements.length; i++) {
      for (var j = i + 1; j < placements.length; j++) {
        if (_wordFitsSlot(placements[i].idiom.text, placements[j]) &&
            _wordFitsSlot(placements[j].idiom.text, placements[i])) {
          return true;
        }
      }
    }
    return false;
  }

  /// 是否存在传统填字规则不允许的视觉粘连。
  ///
  /// 同向词首尾不能直接相接；非交叉格的垂直方向也不能紧邻其他格子。
  bool get hasAmbiguousAdjacency {
    final useCounts = <(int, int), int>{};
    for (final placement in placements) {
      for (final cell in placement.cells) {
        useCounts.update(cell, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    for (final placement in placements) {
      final before = placement.direction == Direction.horizontal
          ? (placement.startRow, placement.startCol - 1)
          : (placement.startRow - 1, placement.startCol);
      final after = placement.direction == Direction.horizontal
          ? (
              placement.startRow,
              placement.startCol + placement.idiom.text.length,
            )
          : (
              placement.startRow + placement.idiom.text.length,
              placement.startCol,
            );
      if (useCounts.containsKey(before) || useCounts.containsKey(after)) {
        return true;
      }

      for (final (row, col) in placement.cells) {
        if (useCounts[(row, col)]! > 1) continue;
        final sideA = placement.direction == Direction.horizontal
            ? (row - 1, col)
            : (row, col - 1);
        final sideB = placement.direction == Direction.horizontal
            ? (row + 1, col)
            : (row, col + 1);
        if (useCounts.containsKey(sideA) || useCounts.containsKey(sideB)) {
          return true;
        }
      }
    }
    return false;
  }

  bool isInterchangeablePlacement(Placement placement) {
    return placements.any(
      (other) =>
          other != placement &&
          _wordFitsSlot(other.idiom.text, placement) &&
          _wordFitsSlot(placement.idiom.text, other),
    );
  }

  /// 某格在当前已填内容下可继续构成的答案字符。
  Set<String> allowedCharactersAt(
    int row,
    int col,
    Map<(int, int), String> answers,
  ) {
    final result = <String>{};
    final containing = placements.where((p) => p.cells.contains((row, col)));
    var firstPlacement = true;
    for (final placement in containing) {
      final position = placement.cells.indexOf((row, col));
      final allowedForPlacement = <String>{};
      for (final answer in _answersForSlot(placement).map((i) => i.text)) {
        if (!_wordFitsSlot(answer, placement)) continue;
        var matches = true;
        for (var k = 0; k < answer.length; k++) {
          if (k == position) continue;
          final filled = answers[placement.cellAt(k)];
          if (filled != null && filled != answer[k]) {
            matches = false;
            break;
          }
        }
        if (matches) allowedForPlacement.add(answer[position]);
      }
      if (firstPlacement) {
        result.addAll(allowedForPlacement);
        firstPlacement = false;
      } else {
        result.retainAll(allowedForPlacement);
      }
    }
    return result;
  }

  /// 所有槽位填满后，检查是否能将本关答案一对一分配给槽位。
  bool matchesAnswers(Map<(int, int), String> answers) {
    final candidates = <List<int>>[];
    for (final placement in placements) {
      final slotCandidates = <int>[];
      for (
        var answerIndex = 0;
        answerIndex < placements.length;
        answerIndex++
      ) {
        final word = placements[answerIndex].idiom.text;
        if (!_wordFitsSlot(word, placement)) continue;
        var matches = true;
        for (var k = 0; k < word.length; k++) {
          final (row, col) = placement.cellAt(k);
          final cell = grid.cellAt(row, col);
          final filled = cell.isGiven ? cell.character : answers[(row, col)];
          if (filled == null || filled != word[k]) {
            matches = false;
            break;
          }
        }
        if (matches) slotCandidates.add(answerIndex);
      }
      if (slotCandidates.isEmpty) return false;
      candidates.add(slotCandidates);
    }

    final answerToSlot = List<int>.filled(placements.length, -1);
    bool assign(int slot, Set<int> seen) {
      for (final answer in candidates[slot]) {
        if (!seen.add(answer)) continue;
        if (answerToSlot[answer] == -1 || assign(answerToSlot[answer], seen)) {
          answerToSlot[answer] = slot;
          return true;
        }
      }
      return false;
    }

    for (var slot = 0; slot < placements.length; slot++) {
      if (!assign(slot, <int>{})) return false;
    }
    return true;
  }

  Idiom? completedIdiomFor(
    Placement placement,
    Map<(int, int), String> answers,
  ) {
    final text = StringBuffer();
    for (var k = 0; k < placement.idiom.text.length; k++) {
      final (row, col) = placement.cellAt(k);
      final cell = grid.cellAt(row, col);
      final char = cell.isGiven ? cell.character : answers[(row, col)];
      if (char == null) return null;
      text.write(char);
    }
    final word = text.toString();
    for (final candidate in _answersForSlot(placement)) {
      if (candidate.text == word) {
        return candidate;
      }
    }
    return null;
  }

  bool _wordFitsSlot(String word, Placement placement) {
    if (word.length != placement.idiom.text.length) return false;
    for (var k = 0; k < word.length; k++) {
      final (row, col) = placement.cellAt(k);
      final cell = grid.cellAt(row, col);
      if ((cell.isGiven || cell.isIntersection) && word[k] != cell.character) {
        return false;
      }
    }
    return true;
  }

  Iterable<Idiom> _answersForSlot(Placement placement) sync* {
    yield placement.idiom;
    for (final other in placements) {
      if (other != placement &&
          _wordFitsSlot(other.idiom.text, placement) &&
          _wordFitsSlot(placement.idiom.text, other)) {
        yield other.idiom;
      }
    }
  }
}

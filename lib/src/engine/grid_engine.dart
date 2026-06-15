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

class Idiom {
  final String text;       // 成语原文，如 "画蛇添足"
  final String pinyin;     // 拼音
  final String meaning;    // 释义
  final int difficulty;    // 难度 1-5
  final String source;     // 出处

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
  String character;         // 填入的字
  CellState state;
  bool isIntersection;      // 是否为交叉点（纵横成语共享）
  bool isGiven;             // 是否为系统给出的初始字（提示）

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
    cells = List.generate(rows, (r) =>
        List.generate(cols, (c) => Cell(row: r, col: c)));
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
  final String? storyHint;           // 隐藏成语的典故提示

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
}

import 'grid_engine.dart';

/// 成语交叉填字生成器
/// 
/// 算法策略（三层递进）：
///   第一层：模板驱动（MVP 用）—— 预定义网格形状，往里面填成语
///   第二层：回溯搜索 —— 从种子成语开始，逐步扩展交叉，约束求解
///   第三层：优化 —— 加入难度评分、多解检测、形状优化
///
/// 此处先实现第二层的回溯算法框架

class CrosswordGenerator {
  final List<Idiom> idiomPool;
  late final Map<String, List<int>> charIndex;  // 字 -> 包含该字的成语索引列表

  CrosswordGenerator({required this.idiomPool}) {
    _buildIndex();
  }

  /// 构建倒排索引：汉字 → 包含该字的成语ID列表
  /// 这是加速交叉匹配的关键
  void _buildIndex() {
    charIndex = {};
    for (int i = 0; i < idiomPool.length; i++) {
      for (int pos = 0; pos < idiomPool[i].text.length; pos++) {
        final c = idiomPool[i].text[pos];
        charIndex.putIfAbsent(c, () => []);
        charIndex[c]!.add(i);
      }
    }
  }

  /// 找到所有与给定成语在指定位置共享某个字的其他成语
  /// 返回：[(成语索引, 共享字在该成语中的位置)]
  List<(int, int)> findCrossingIdioms(String character) {
    if (!charIndex.containsKey(character)) return [];
    return charIndex[character]!
        .map((idx) => (idx, idiomPool[idx].text.indexOf(character)))
        .where((pair) => pair.$2 >= 0)
        .toList();
  }

  /// 主入口：生成一个包含 targetCount 个成语的填字关卡
  /// 使用回溯搜索
  CrosswordLevel? generate(int targetCount, {int maxAttempts = 1000}) {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // 随机选择种子成语
      idiomPool.shuffle();
      final seed = idiomPool.first;

      // 种子水平放置，从网格中心偏左开始
      final grid = CrosswordGrid(rows: 12, cols: 12);
      final placements = <Placement>[];

      final seedPlacement = Placement(
        idiom: seed,
        startRow: 5,
        startCol: 2,
        direction: Direction.horizontal,
      );
      placements.add(seedPlacement);

      // 回溯扩展
      if (_backtrack(grid, placements, targetCount, 10, 10)) {
        // 构建关卡
        _fillGrid(grid, placements);
        final givenChars = _selectGivenChars(grid, placements);

        return CrosswordLevel(
          levelId: attempt,
          grid: grid,
          placements: placements,
          givenCharacters: givenChars,
          title: '第 ${attempt + 1} 关',
        );
      }
    }
    return null; // 生成失败
  }

  /// 回溯搜索核心
  /// 每次迭代选择一个已放置的成语，从其未使用过的字出发，尝试垂直交叉一个新成语
  bool _backtrack(
    CrosswordGrid grid,
    List<Placement> placements,
    int targetCount,
    int maxRows,
    int maxCols,
  ) {
    if (placements.length >= targetCount) return true;

    // 对每个已放置的成语，尝试从其每个字扩展
    for (int p = 0; p < placements.length; p++) {
      final placement = placements[p];
      for (int charIdx = 0; charIdx < placement.idiom.text.length; charIdx++) {
        final char = placement.idiom.text[charIdx];

        // 该位置是否已被其他成语占据为交叉点
        bool alreadyCrossed = false;
        for (final other in placements) {
          if (other == placement) continue;
          for (int k = 0; k < other.idiom.text.length; k++) {
            if (other.cellAt(k) == placement.cellAt(charIdx)) {
              alreadyCrossed = true;
              break;
            }
          }
          if (alreadyCrossed) break;
        }
        if (alreadyCrossed) continue;

        // 查找共享这个字的其他成语
        final candidates = findCrossingIdioms(char);
        candidates.shuffle();

        for (final (idiomIdx, crossPos) in candidates) {
          final newIdiom = idiomPool[idiomIdx];
          // 不能重复使用同一个成语
          if (placements.any((pl) => pl.idiom.text == newIdiom.text)) continue;

          // 新成语的方向与当前成语垂直
          final newDir = placement.direction == Direction.horizontal
              ? Direction.vertical
              : Direction.horizontal;

          // 计算新成语的起始位置
          final (crossRow, crossCol) = placement.cellAt(charIdx);
          late int newStartRow, newStartCol;
          if (newDir == Direction.vertical) {
            newStartRow = crossRow - crossPos;
            newStartCol = crossCol;
          } else {
            newStartRow = crossRow;
            newStartCol = crossCol - crossPos;
          }

          final newPlacement = Placement(
            idiom: newIdiom,
            startRow: newStartRow,
            startCol: newStartCol,
            direction: newDir,
          );

          // 验证合法性
          if (!grid.isValidPlacement(newPlacement, placements)) continue;

          placements.add(newPlacement);
          if (_backtrack(grid, placements, targetCount, maxRows, maxCols)) {
            return true;
          }
          placements.removeLast(); // 回溯
        }
      }
    }
    return false;
  }

  /// 将放置方案写入网格
  void _fillGrid(CrosswordGrid grid, List<Placement> placements) {
    // 先全部清空
    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        grid.cellAt(r, c).state = CellState.blocked;
        grid.cellAt(r, c).character = '';
      }
    }

    // 写入每个放置
    final intersectionCells = <(int, int)>{};
    // 第一遍：标记交叉点
    for (int i = 0; i < placements.length; i++) {
      for (int j = i + 1; j < placements.length; j++) {
        final inter = grid.findIntersection(placements[i], placements[j]);
        if (inter != null) {
          final cell = placements[i].cellAt(inter.$1);
          intersectionCells.add(cell);
        }
      }
    }

    // 第二遍：填入字符
    for (final placement in placements) {
      for (int k = 0; k < placement.idiom.text.length; k++) {
        final (r, c) = placement.cellAt(k);
        final cell = grid.cellAt(r, c);
        cell.state = CellState.filled;
        cell.character = placement.idiom.text[k];
        cell.isIntersection = intersectionCells.contains((r, c));
      }
    }
  }

  /// 选择哪些字作为初始提示给出
  Set<String> _selectGivenChars(
      CrosswordGrid grid, List<Placement> placements) {
    final given = <String>{};
    // 策略：每个成语给出首字作为提示
    for (final placement in placements) {
      final (r, c) = placement.cellAt(0);
      grid.cellAt(r, c).isGiven = true;
      given.add(placement.idiom.text[0]);
    }
    return given;
  }
}

/// 难度评估器
class DifficultyEvaluator {
  /// 评估一个关卡的难度（1-5）
  static int evaluate(CrosswordLevel level) {
    double score = 0;

    // 因素1：成语数量
    final idiomCount = level.idioms.length;
    if (idiomCount <= 3) score += 1;
    else if (idiomCount <= 5) score += 2;
    else if (idiomCount <= 8) score += 3;
    else score += 4;

    // 因素2：成语本身的平均难度
    final avgDifficulty = level.idioms
        .map((i) => i.difficulty)
        .reduce((a, b) => a + b) / idiomCount;
    score += avgDifficulty;

    // 因素3：提示比例（提示越少越难）
    final fillableRatio = level.fillableCells / level.idioms.length;
    if (fillableRatio > 6) score += 2;
    else if (fillableRatio > 4) score += 1;

    return (score / 3).round().clamp(1, 5);
  }
}

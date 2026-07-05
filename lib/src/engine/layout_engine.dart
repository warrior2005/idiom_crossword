import 'dart:math';
import 'crossing_graph.dart';
import 'grid_engine.dart';

/// 布局引擎 v2
///
/// 算法：递归回溯 + 多起点尝试
///   1. 选度数最高的节点作为种子，固定位置
///   2. 递归扩展邻居，每次尝试所有可行方向和交叉位置
///   3. 失败时回溯到上一个决策点
///   4. 多次尝试不同种子位置

class _PlacedNode {
  final int idiomIdx;
  Direction direction;
  int startRow;
  int startCol;

  _PlacedNode({
    required this.idiomIdx,
    required this.direction,
    required this.startRow,
    required this.startCol,
  });

  List<(int, int)> cells(int length) {
    return List.generate(length, (i) {
      return direction == Direction.horizontal
          ? (startRow, startCol + i)
          : (startRow + i, startCol);
    });
  }

  (int, int) cellAt(int k, int length) {
    return direction == Direction.horizontal
        ? (startRow, startCol + k)
        : (startRow + k, startCol);
  }

  _PlacedNode copy() => _PlacedNode(
        idiomIdx: idiomIdx,
        direction: direction,
        startRow: startRow,
        startCol: startCol,
      );
}

class LayoutResult {
  final CrosswordLevel level;
  final List<_PlacedNode> placedNodes;

  const LayoutResult({required this.level, required this.placedNodes});
}

class LayoutEngine {
  CrossingGraph graph;

  LayoutEngine({required this.graph});

  /// 主入口
  LayoutResult? layout({
    required List<int> nodeIndices,
    required List<CrossEdge> subEdges,
    int maxAttempts = 30,
  }) {
    if (nodeIndices.isEmpty) return null;

    // 计算度数
    final degrees = <int, int>{};
    for (final edge in subEdges) {
      degrees[edge.idiomA] = (degrees[edge.idiomA] ?? 0) + 1;
      degrees[edge.idiomB] = (degrees[edge.idiomB] ?? 0) + 1;
    }

    // 排序
    final sorted = List<int>.from(nodeIndices);
    sorted.sort((a, b) => (degrees[b] ?? 0).compareTo(degrees[a] ?? 0));

    // 邻接表（仅子图内的边）
    final adj = <int, List<CrossEdge>>{};
    for (final edge in subEdges) {
      adj.putIfAbsent(edge.idiomA, () => []);
      adj.putIfAbsent(edge.idiomB, () => []);
      adj[edge.idiomA]!.add(edge);
      adj[edge.idiomB]!.add(edge);
    }

    // 多起点重试
    final startPositions = [
      (10, 5), (5, 5), (5, 10), (10, 10),
      (7, 3), (3, 7), (12, 8), (8, 12),
    ];

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final startPos = startPositions[attempt % startPositions.length];

      final result = _backtrack(
        sorted: sorted,
        adj: adj,
        degrees: degrees,
        startPos: startPos,
      );
      if (result != null) return result;
    }
    return null;
  }

  /// 递归回溯搜索
  LayoutResult? _backtrack({
    required List<int> sorted,
    required Map<int, List<CrossEdge>> adj,
    required Map<int, int> degrees,
    required (int, int) startPos,
  }) {
    final placed = <int, _PlacedNode>{};
    final occupied = <(int, int), int>{};

    // 放置种子
    if (sorted.isEmpty) return null;
    placed[sorted[0]] = _PlacedNode(
      idiomIdx: sorted[0],
      direction: Direction.horizontal,
      startRow: startPos.$1,
      startCol: startPos.$2,
    );
    _markOccupied(placed[sorted[0]]!, graph.idioms[sorted[0]].text.length,
        occupied, sorted[0]);

    // 递归扩展
    final success = _placeRemaining(
      sorted: sorted,
      adj: adj,
      placed: placed,
      occupied: occupied,
      nextIdx: 1,
    );

    if (!success) return null;

    return _buildResult(placed);
  }

  /// 递归放置剩余节点
  /// 返回 true 表示全部放置成功
  bool _placeRemaining({
    required List<int> sorted,
    required Map<int, List<CrossEdge>> adj,
    required Map<int, _PlacedNode> placed,
    required Map<(int, int), int> occupied,
    required int nextIdx,
    int depth = 0,
  }) {
    if (nextIdx >= sorted.length) return true;
    if (depth > 50) return false; // 安全阀

    final node = sorted[nextIdx];
    final edges = adj[node];
    if (edges == null) return false;

    // 收集所有与已放置节点的交叉约束
    final constraints = <_CrossConstraint>[];
    for (final edge in edges) {
      final other = edge.idiomA == node ? edge.idiomB : edge.idiomA;
      if (!placed.containsKey(other)) continue;

      final placedOther = placed[other]!;
      final int posInNode =
          edge.idiomA == node ? edge.posInA : edge.posInB;
      final int posInOther =
          edge.idiomA == node ? edge.posInB : edge.posInA;

      final otherLen = graph.idioms[other].text.length;
      final (crossRow, crossCol) = placedOther.cellAt(posInOther, otherLen);

      constraints.add(_CrossConstraint(
        posInNode: posInNode,
        crossRow: crossRow,
        crossCol: crossCol,
      ));
    }

    if (constraints.isEmpty) return false;

    // 对每个方向，从所有约束推导起始位置
    // 所有约束必须推导出相同的 startRow/startCol
    final candidates = <_PlacementCandidate>[];
    final idiomLen = graph.idioms[node].text.length;

    for (final dir in Direction.values) {
      int? agreedStartRow;
      int? agreedStartCol;
      bool consistent = true;
      final allCrossPoints = <(int, int)>{};

      for (final c in constraints) {
        int sr, sc;
        if (dir == Direction.horizontal) {
          sr = c.crossRow;
          sc = c.crossCol - c.posInNode;
        } else {
          sr = c.crossRow - c.posInNode;
          sc = c.crossCol;
        }

        agreedStartRow ??= sr;
        agreedStartCol ??= sc;

        if (sr != agreedStartRow || sc != agreedStartCol) {
          consistent = false;
          break;
        }

        final r = dir == Direction.vertical ? sr + c.posInNode : sr;
        final col = dir == Direction.horizontal ? sc + c.posInNode : sc;
        allCrossPoints.add((r, col));
      }

      if (consistent && agreedStartRow != null && agreedStartCol != null &&
          _canPlaceMulti(node, dir, agreedStartRow, agreedStartCol, idiomLen,
              allCrossPoints, occupied)) {
        candidates.add(_PlacementCandidate(
          node: node,
          direction: dir,
          startRow: agreedStartRow,
          startCol: agreedStartCol,
          crossRow: constraints.first.crossRow,
          crossCol: constraints.first.crossCol,
        ));
      }
    }

    if (candidates.isEmpty) return false;

    // 按"自由度"排序：优先选择占用新格子少的方案（更紧凑）
    candidates.sort((a, b) {
      final aNew = _countNewCells(a, occupied);
      final bNew = _countNewCells(b, occupied);
      return aNew.compareTo(bNew);
    });

    // 尝试每个候选
    for (final cand in candidates) {
      // 放置
      placed[node] = _PlacedNode(
        idiomIdx: node,
        direction: cand.direction,
        startRow: cand.startRow,
        startCol: cand.startCol,
      );
      _markOccupied(placed[node]!, graph.idioms[node].text.length,
          occupied, node);

      // 递归
      if (_placeRemaining(
        sorted: sorted,
        adj: adj,
        placed: placed,
        occupied: occupied,
        nextIdx: nextIdx + 1,
        depth: depth + 1,
      )) {
        return true;
      }

      // 回溯：撤销放置
      _unmarkOccupied(placed[node]!, graph.idioms[node].text.length,
          occupied, node);
      placed.remove(node);
    }

    return false;
  }

  /// 检查放置是否可行（支持多个交叉点）
  bool _canPlaceMulti(
    int node,
    Direction dir,
    int startRow,
    int startCol,
    int length,
    Set<(int, int)> crossPoints,
    Map<(int, int), int> occupied,
  ) {
    for (int k = 0; k < length; k++) {
      final r = dir == Direction.vertical ? startRow + k : startRow;
      final c = dir == Direction.horizontal ? startCol + k : startCol;

      if (r < -5 || r >= 30 || c < -5 || c >= 30) return false;

      // 所有交叉点允许重叠
      if (crossPoints.contains((r, c))) continue;

      final occ = occupied[(r, c)];
      if (occ != null && occ != node) return false;
    }
    return true;
  }

  int _countNewCells(_PlacementCandidate cand,
      Map<(int, int), int> occupied) {
    int count = 0;
    final len = graph.idioms[cand.node].text.length;
    for (int k = 0; k < len; k++) {
      final r = cand.direction == Direction.vertical
          ? cand.startRow + k
          : cand.startRow;
      final c = cand.direction == Direction.horizontal
          ? cand.startCol + k
          : cand.startCol;
      if (r == cand.crossRow && c == cand.crossCol) continue;
      if (!occupied.containsKey((r, c))) count++;
    }
    return count;
  }

  void _markOccupied(
    _PlacedNode node,
    int length,
    Map<(int, int), int> occupied,
    int nodeIdx,
  ) {
    for (int k = 0; k < length; k++) {
      final (r, c) = node.cellAt(k, length);
      occupied[(r, c)] = nodeIdx;
    }
  }

  void _unmarkOccupied(
    _PlacedNode node,
    int length,
    Map<(int, int), int> occupied,
    int nodeIdx,
  ) {
    for (int k = 0; k < length; k++) {
      final (r, c) = node.cellAt(k, length);
      if (occupied[(r, c)] == nodeIdx) {
        occupied.remove((r, c));
      }
    }
  }

  /// 构建 CrosswordLevel
  LayoutResult _buildResult(Map<int, _PlacedNode> placed) {
    int minRow = 999, maxRow = -999;
    int minCol = 999, maxCol = -999;

    for (final node in placed.values) {
      final len = graph.idioms[node.idiomIdx].text.length;
      for (int k = 0; k < len; k++) {
        final (r, c) = node.cellAt(k, len);
        minRow = min(minRow, r);
        maxRow = max(maxRow, r);
        minCol = min(minCol, c);
        maxCol = max(maxCol, c);
      }
    }

    minRow -= 1;
    maxRow += 1;
    minCol -= 1;
    maxCol += 1;

    final rows = maxRow - minRow + 1;
    final cols = maxCol - minCol + 1;
    final grid = CrosswordGrid(rows: rows, cols: cols);

    final placements = <Placement>[];
    final occupiedCells = <(int, int), String>{};

    for (final entry in placed.entries) {
      final idx = entry.key;
      final node = entry.value;
      final idiom = graph.idioms[idx];
      final len = idiom.text.length;

      for (int k = 0; k < len; k++) {
        final (origR, origC) = node.cellAt(k, len);
        final r = origR - minRow;
        final c = origC - minCol;
        final cell = grid.cellAt(r, c);

        if (occupiedCells.containsKey((r, c))) {
          cell.isIntersection = true;
        }
        cell.state = CellState.filled;
        cell.character = idiom.text[k];
        occupiedCells[(r, c)] = idiom.text[k];
      }

      placements.add(Placement(
        idiom: idiom,
        startRow: node.startRow - minRow,
        startCol: node.startCol - minCol,
        direction: node.direction,
      ));
    }

    final givenChars = <String>{};
    for (final p in placements) {
      givenChars.add(p.idiom.text[0]);
      final (r, c) = p.cellAt(0);
      grid.cellAt(r, c).isGiven = true;
    }

    final avgDiff = placed.keys
        .map((i) => graph.idioms[i].difficulty)
        .reduce((a, b) => a + b) /
        placed.length;

    return LayoutResult(
      level: CrosswordLevel(
        levelId: 0,
        grid: grid,
        placements: placements,
        givenCharacters: givenChars,
        title: '难度 ${avgDiff.toInt()}',
      ),
      placedNodes: placed.values.toList(),
    );
  }
}

class _CrossConstraint {
  final int posInNode;
  final int crossRow;
  final int crossCol;

  const _CrossConstraint({
    required this.posInNode,
    required this.crossRow,
    required this.crossCol,
  });
}

class _PlacementCandidate {
  final int node;
  final Direction direction;
  final int startRow;
  final int startCol;
  final int crossRow;
  final int crossCol;

  const _PlacementCandidate({
    required this.node,
    required this.direction,
    required this.startRow,
    required this.startCol,
    required this.crossRow,
    required this.crossCol,
  });
}

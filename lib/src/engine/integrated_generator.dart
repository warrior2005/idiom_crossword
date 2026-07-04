/// 一体化生成器：子图扩展 + 布局同时进行
///
/// 核心思路：
///   不在"选子图→布局"之间画线，而是把布局作为子图选择的约束条件。
///   从种子开始，每次找一个邻居尝试放置，放得下就加入子图，放不下就换邻居。
///   这样保证输出的子图一定是几何可布局的。

import 'dart:math';
import 'crossing_graph.dart';
import 'grid_engine.dart';
import 'spiral_difficulty.dart';

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

  (int, int) cellAt(int k, int length) {
    return direction == Direction.horizontal
        ? (startRow, startCol + k)
        : (startRow + k, startCol);
  }
}

class IntegratedGenerator {
  final CrossingGraph graph;
  final Random _random;

  IntegratedGenerator({required this.graph}) : _random = Random();

  /// 生成关卡：边扩展子图边布局
  /// 返回 null 表示生成失败
  CrosswordLevel? generate({
    required int targetSize,
    required int minDifficulty,
    required int maxDifficulty,
    int maxAttempts = 50,
    int? levelNumber,
    SpiralDifficultyResult? spiralResult,
  }) {
    // 如果提供了 spiralResult，使用螺旋难度范围
    if (spiralResult != null) {
      minDifficulty = spiralResult.mainMin;
      maxDifficulty = spiralResult.mainMax;
    }
    
    // 候选池
    final candidates = <int>{};
    for (int i = 0; i < graph.idioms.length; i++) {
      final d = graph.idioms[i].difficulty;
      if (d >= minDifficulty && d <= maxDifficulty) {
        candidates.add(i);
      }
    }
    if (candidates.length < targetSize) return null;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final result = _tryGenerate(candidates, targetSize);
      if (result != null) return result;
    }
    return null;
  }

  CrosswordLevel? _tryGenerate(Set<int> candidates, int targetSize) {
    final occupied = <(int, int), int>{}; // 已占用的格子
    final placed = <int, _PlacedNode>{}; // 已放置的节点

    // 1. 选种子（随机）
    final seedList = candidates.toList()..shuffle(_random);
    final seed = seedList.first;

    placed[seed] = _PlacedNode(
      idiomIdx: seed,
      direction: Direction.horizontal,
      startRow: 10,
      startCol: 5,
    );
    _markCells(placed[seed]!, graph.idioms[seed].text.length, occupied, seed);

    // 记录已放置成语的倒装形式，避免同关出现互逆对
    final reversedForms = <String>{_reverse(graph.idioms[seed].text)};

    // 2. BFS 扩展：从已放置节点的邻居中找可放置的，逐步加入
    final frontier = <int>[seed];
    final visited = <int>{seed};

    while (placed.length < targetSize && frontier.isNotEmpty) {
      // 打乱 frontier 顺序
      frontier.shuffle(_random);
      final current = frontier.removeAt(0);

      // 找 current 的邻居（在候选池中）
      final neighbors = graph.getNeighbors(current)
          .where((n) => candidates.contains(n) && !visited.contains(n))
          .toList();
      neighbors.shuffle(_random);

      bool addedAny = false;
      for (final neighbor in neighbors) {
        visited.add(neighbor);

        // 跳过倒装对：如果这个成语的倒装形式已经在本关中，跳过
        final neighborText = graph.idioms[neighbor].text;
        if (reversedForms.contains(neighborText)) continue;
        final success = _tryPlaceNeighbor(
          node: neighbor,
          neighborOf: current,
          placed: placed,
          occupied: occupied,
        );

        if (success) {
          frontier.add(neighbor);
          reversedForms.add(_reverse(neighborText));
          addedAny = true;
          if (placed.length >= targetSize) break;
        }
        // 放不下就继续试下一个邻居，不影响
      }

      // 如果 current 的所有邻居都放不下，它可能是个死胡同
      // 把它放回 frontier 末尾再试（可能后续有其他节点改变布局后就能放了）
      if (!addedAny && frontier.isEmpty && placed.length < targetSize) {
        // 尝试从任意已放置节点扩展
        final allPlaced = placed.keys.toList()..shuffle(_random);
        for (final pid in allPlaced) {
          if (pid == current) continue;
          final otherNeighbors = graph.getNeighbors(pid)
              .where((n) => candidates.contains(n) && !placed.containsKey(n))
              .toList();
          otherNeighbors.shuffle(_random);

          for (final n in otherNeighbors) {
            visited.add(n);
            // 跳过倒装对
            final nText = graph.idioms[n].text;
            if (reversedForms.contains(nText)) continue;
            if (_tryPlaceNeighbor(
              node: n,
              neighborOf: pid,
              placed: placed,
              occupied: occupied,
            )) {
              frontier.add(n);
              reversedForms.add(_reverse(nText));
              if (placed.length >= targetSize) break;
            }
          }
          if (placed.length >= targetSize) break;
        }
      }
    }

    if (placed.length < targetSize) return null;

    // 3. 构建 CrosswordLevel
    return _buildLevel(placed);
  }

  /// 计算四字成语的倒装形式（ABCD → CDAB）
  String _reverse(String word) => word.substring(2) + word.substring(0, 2);

  /// 尝试放置一个邻居节点
  bool _tryPlaceNeighbor({
    required int node,
    required int neighborOf,
    required Map<int, _PlacedNode> placed,
    required Map<(int, int), int> occupied,
  }) {
    final placedOther = placed[neighborOf]!;
    final idiom = graph.idioms[node];
    final otherIdiom = graph.idioms[neighborOf];
    final length = idiom.text.length;
    final otherLength = otherIdiom.text.length;

    // 找到所有共享字和位置
    final word = idiom.text;
    final otherWord = otherIdiom.text;

    // 收集所有交叉候选
    final crossCandidates = <_CrossOption>[];
    for (int posA = 0; posA < word.length; posA++) {
      for (int posB = 0; posB < otherWord.length; posB++) {
        if (word[posA] == otherWord[posB]) {
          final (crossRow, crossCol) = placedOther.cellAt(posB, otherLength);

          // 两种方向
          for (final dir in Direction.values) {
            final startRow = dir == Direction.vertical
                ? crossRow - posA
                : crossRow;
            final startCol = dir == Direction.horizontal
                ? crossCol - posA
                : crossCol;

            crossCandidates.add(_CrossOption(
              posInNode: posA,
              posInOther: posB,
              direction: dir,
              startRow: startRow,
              startCol: startCol,
              crossRow: crossRow,
              crossCol: crossCol,
            ));
          }
        }
      }
    }

    if (crossCandidates.isEmpty) return false;

    // 打乱尝试顺序
    crossCandidates.shuffle(_random);

    for (final opt in crossCandidates) {
      // 检查是否可以放置
      if (_canPlace(opt, length, occupied, placed, node)) {
        // 还需要验证与所有已放置节点的其他交叉约束
        // （如果 node 跟多个已放置节点共享字，需要检查所有交叉点）
        if (_verifyAllCrossings(node, opt, placed, length)) {
          placed[node] = _PlacedNode(
            idiomIdx: node,
            direction: opt.direction,
            startRow: opt.startRow,
            startCol: opt.startCol,
          );
          _markCells(placed[node]!, length, occupied, node);
          return true;
        }
      }
    }

    return false;
  }

  /// 检查放置是否不与已有格子冲突。
  /// 如果格子已被其他成语占用，只有当字符相同时才允许（构成额外交叉）。
  bool _canPlace(
    _CrossOption opt,
    int length,
    Map<(int, int), int> occupied,
    Map<int, _PlacedNode> placed,
    int node,
  ) {
    final word = graph.idioms[node].text;

    for (int k = 0; k < length; k++) {
      final r = opt.direction == Direction.vertical
          ? opt.startRow + k
          : opt.startRow;
      final c = opt.direction == Direction.horizontal
          ? opt.startCol + k
          : opt.startCol;

      if (r < -5 || r >= 30 || c < -5 || c >= 30) return false;

      final occ = occupied[(r, c)];
      if (occ != null && occ != node) {
        // 格子已被其他成语占用，检查字符是否一致
        final otherPlaced = placed[occ];
        if (otherPlaced == null) return false;
        final otherWord = graph.idioms[occ].text;
        final otherLen = otherWord.length;
        int? otherPos;
        for (int pk = 0; pk < otherLen; pk++) {
          final (pr, pc) = otherPlaced.cellAt(pk, otherLen);
          if (pr == r && pc == c) {
            otherPos = pk;
            break;
          }
        }
        if (otherPos == null || word[k] != otherWord[otherPos]) {
          return false; // 字符不匹配，冲突
        }
        // 字符匹配，允许额外交叉
      }
    }
    return true;
  }

  /// 验证与所有已放置成语的交叉一致性。
  /// 注意：_canPlace 已通过"同格必同字"规则处理了所有冲突，
  /// 此处仅做最终的一致性兜底检查。
  bool _verifyAllCrossings(
    int node,
    _CrossOption opt,
    Map<int, _PlacedNode> placed,
    int length,
  ) {
    final word = graph.idioms[node].text;

    for (final entry in placed.entries) {
      final otherIdx = entry.key;
      final otherPlaced = entry.value;
      final otherWord = graph.idioms[otherIdx].text;
      final otherLen = otherWord.length;

      for (int pa = 0; pa < word.length; pa++) {
        final r = opt.direction == Direction.vertical
            ? opt.startRow + pa
            : opt.startRow;
        final c = opt.direction == Direction.horizontal
            ? opt.startCol + pa
            : opt.startCol;

        for (int pb = 0; pb < otherWord.length; pb++) {
          final (otherR, otherC) = otherPlaced.cellAt(pb, otherLen);
          // 两个成语的格子重叠时，字符必须一致
          if (r == otherR && c == otherC && word[pa] != otherWord[pb]) {
            return false;
          }
        }
      }
    }
    return true;
  }

  void _markCells(
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

  /// 构建 CrosswordLevel
  CrosswordLevel _buildLevel(Map<int, _PlacedNode> placed) {
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
    final cellChars = <(int, int), String>{};

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

        if (cellChars.containsKey((r, c))) {
          cell.isIntersection = true;
        }
        cell.state = CellState.filled;
        cell.character = idiom.text[k];
        cellChars[(r, c)] = idiom.text[k];
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

    return CrosswordLevel(
      levelId: 0,
      grid: grid,
      placements: placements,
      givenCharacters: givenChars,
      title: '',
    );
  }

  /// 生成螺旋难度关卡
  /// 
  /// [levelNumber] 关卡编号 (1-based)
  /// [totalLevels] 总关卡数
  CrosswordLevel? generateSpiral({
    required int levelNumber,
    int totalLevels = 10000,
    int maxAttempts = 50,
  }) {
    final spiral = SpiralDifficulty.calculate(levelNumber);
    final (mainCount, tailCount, previewCount) = 
        SpiralDifficulty.selectIdiomCounts(levelNumber);
    
    final targetSize = mainCount + tailCount + previewCount;
    
    // First try with main range
    var level = generate(
      targetSize: targetSize,
      minDifficulty: spiral.mainMin,
      maxDifficulty: spiral.mainMax,
      maxAttempts: maxAttempts ~/ 2,
    );
    
    // If failed, try with wider range
    level ??= generate(
      targetSize: targetSize,
      minDifficulty: (spiral.mainMin - 2).clamp(1, 50),
      maxDifficulty: (spiral.mainMax + 2).clamp(1, 50),
      maxAttempts: maxAttempts ~/ 2,
    );
    
    return level;
  }
}

class _CrossOption {
  final int posInNode;
  final int posInOther;
  final Direction direction;
  final int startRow;
  final int startCol;
  final int crossRow;
  final int crossCol;

  const _CrossOption({
    required this.posInNode,
    required this.posInOther,
    required this.direction,
    required this.startRow,
    required this.startCol,
    required this.crossRow,
    required this.crossCol,
  });
}

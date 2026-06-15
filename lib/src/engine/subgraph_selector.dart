import 'dart:math';
import 'crossing_graph.dart';
import 'grid_engine.dart';

/// 子图选取器
/// 
/// 从交叉图中选取一个满足难度约束的连通子图。
/// 支持纯难度模式（所有节点都在范围内）和混合模式（允许桥接节点）。

enum SubgraphMode {
  /// 所有成语必须在难度区间内
  strict,

  /// 允许少数桥接成语超出区间（解决大师级连通性差的问题）
  mixed,
}

class SubgraphResult {
  final List<int> nodeIndices; // 选中的成语索引
  final List<CrossEdge> edges; // 子图内的边
  final double avgDifficulty;
  final double density;

  const SubgraphResult({
    required this.nodeIndices,
    required this.edges,
    required this.avgDifficulty,
    required this.density,
  });

  List<Idiom> getIdioms(CrossingGraph graph) =>
      nodeIndices.map((i) => graph.idioms[i]).toList();
}

class SubgraphSelector {
  CrossingGraph graph;
  final Random _random;

  SubgraphSelector({required this.graph}) : _random = Random();

  /// 选取一个连通子图
  ///
  /// [targetSize]: 目标成语数量
  /// [minDifficulty], [maxDifficulty]: 难度区间（1-100）
  /// [mode]: 选取模式
  /// [maxAttempts]: 最大尝试次数
  SubgraphResult? select({
    required int targetSize,
    required int minDifficulty,
    required int maxDifficulty,
    SubgraphMode mode = SubgraphMode.strict,
    int maxAttempts = 50,
  }) {
    // 筛出候选节点
    final candidates = <int>{};
    for (int i = 0; i < graph.idioms.length; i++) {
      final d = graph.idioms[i].difficulty;
      if (d >= minDifficulty && d <= maxDifficulty) {
        candidates.add(i);
      }
    }

    if (candidates.length < targetSize) return null;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // 从候选池中随机选种子
      final seedList = candidates.toList();
      final seed = seedList[_random.nextInt(seedList.length)];

      // BFS 扩展
      final visited = <int>{seed};
      final queue = <int>[seed];
      final selected = <int>[];

      while (queue.isNotEmpty && selected.length < targetSize) {
        final cur = queue.removeAt(0);

        if (mode == SubgraphMode.strict && !candidates.contains(cur)) {
          continue;
        }

        selected.add(cur);

        // 扩展邻居
        final neighbors = graph.getNeighbors(cur, withinPool: candidates);
        neighbors.shuffle(_random);

        for (final neighbor in neighbors) {
          if (!visited.contains(neighbor)) {
            visited.add(neighbor);
            queue.add(neighbor);
          }
        }
      }

      if (selected.length >= targetSize) {
        final subNodes = selected.take(targetSize).toList();

        // 计算子图内的边
        final subEdges = <CrossEdge>[];
        for (int i = 0; i < subNodes.length; i++) {
          final edgesA = graph.getEdges(subNodes[i]);
          for (final edge in edgesA) {
            if (subNodes.contains(edge.idiomB) && edge.idiomA < edge.idiomB) {
              subEdges.add(edge);
            }
          }
        }

        // 统计
        final diffs = subNodes.map((i) => graph.idioms[i].difficulty);
        final avgDiff = diffs.reduce((a, b) => a + b) / diffs.length;
        final maxEdges = targetSize * (targetSize - 1) ~/ 2;
        final density = maxEdges > 0 ? subEdges.length / maxEdges : 0.0;

        return SubgraphResult(
          nodeIndices: subNodes,
          edges: subEdges,
          avgDifficulty: avgDiff,
          density: density,
        );
      }
    }
    return null;
  }

  /// 混合难度选取：N-1 个在范围内，1 个超出（作为叶子节点）
  /// 专为解决大师级连通性问题
  SubgraphResult? selectMixed({
    required int targetSize,
    required int minDifficulty,
    required int maxDifficulty,
    int leafDifficulty = 76, // 大师级叶子的最低难度
    int maxAttempts = 50,
  }) {
    // 核心池：在难度区间内
    final coreCandidates = <int>{};
    // 叶子池：超出区间的
    final leafCandidates = <int>{};

    for (int i = 0; i < graph.idioms.length; i++) {
      final d = graph.idioms[i].difficulty;
      if (d >= minDifficulty && d <= maxDifficulty) {
        coreCandidates.add(i);
      } else if (d >= leafDifficulty) {
        leafCandidates.add(i);
      }
    }

    if (coreCandidates.length < targetSize - 1 || leafCandidates.isEmpty) {
      return null;
    }

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // 先选一个叶子
      final leafList = leafCandidates.toList();
      final leaf = leafList[_random.nextInt(leafList.length)];

      // 找到叶子的邻居中，哪些在核心池里
      final leafNeighbors = graph
          .getNeighbors(leaf)
          .where((n) => coreCandidates.contains(n))
          .toList();

      if (leafNeighbors.isEmpty) continue;

      // 从邻居中选一个作为种子，扩展核心子图
      final seed = leafNeighbors[_random.nextInt(leafNeighbors.length)];

      final visited = <int>{seed, leaf};
      final queue = <int>[seed];
      final selected = <int>[];

      while (queue.isNotEmpty && selected.length < targetSize - 1) {
        final cur = queue.removeAt(0);
        if (!coreCandidates.contains(cur)) continue;
        selected.add(cur);

        final neighbors = graph
            .getNeighbors(cur, withinPool: coreCandidates);
        neighbors.shuffle(_random);

        for (final n in neighbors) {
          if (!visited.contains(n)) {
            visited.add(n);
            queue.add(n);
          }
        }
      }

      if (selected.length >= targetSize - 1) {
        final core = selected.take(targetSize - 1).toList();
        final subNodes = [...core, leaf];

        // 计算边
        final subEdges = <CrossEdge>[];
        for (int i = 0; i < subNodes.length; i++) {
          final edgesA = graph.getEdges(subNodes[i]);
          for (final edge in edgesA) {
            if (subNodes.contains(edge.idiomB) && edge.idiomA < edge.idiomB) {
              subEdges.add(edge);
            }
          }
        }

        final diffs = subNodes.map((i) => graph.idioms[i].difficulty);
        final avgDiff = diffs.reduce((a, b) => a + b) / diffs.length;
        final maxEdges = targetSize * (targetSize - 1) ~/ 2;
        final density = maxEdges > 0 ? subEdges.length / maxEdges : 0.0;

        return SubgraphResult(
          nodeIndices: subNodes,
          edges: subEdges,
          avgDifficulty: avgDiff,
          density: density,
        );
      }
    }
    return null;
  }
}

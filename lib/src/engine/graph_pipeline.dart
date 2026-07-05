/// 连通图方案：关卡生成管道
/// 
/// 流程：图构建 → 子图选取 → 布局 → 关卡
/// 替代原来的 CrosswordGenerator（纯回溯）

import 'crossing_graph.dart';
import 'subgraph_selector.dart';
import 'layout_engine.dart';
import 'grid_engine.dart';

class GraphPipelineGenerator {
  final CrossingGraph graph;
  final SubgraphSelector selector;
  final LayoutEngine layout;

  GraphPipelineGenerator({required List<Idiom> idiomPool})
      : graph = CrossingGraph(idioms: idiomPool),
        selector = SubgraphSelector(graph: CrossingGraph(idioms: [])), // temp
        layout = LayoutEngine(graph: CrossingGraph(idioms: [])) {       // temp
    selector.graph = graph;
    layout.graph = graph;
  }

  /// 生成一个关卡
  /// 
  /// [targetSize]: 目标成语数量（建议 4-8）
  /// [minDifficulty], [maxDifficulty]: 难度区间
  /// [maxAttempts]: 最大尝试次数
  GenerationResult? generate({
    required int targetSize,
    int minDifficulty = 1,
    int maxDifficulty = 100,
    int maxAttempts = 30,
    bool allowMixed = true,
    int? mixedLeafMinDifficulty,
  }) {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      // Step 1: 选子图（每次尝试都可以换子图）
      SubgraphResult? subgraph;

      // 先尝试严格模式
      subgraph = selector.select(
        targetSize: targetSize,
        minDifficulty: minDifficulty,
        maxDifficulty: maxDifficulty,
        maxAttempts: 5,
      );

      // 严格模式失败 + 允许混合 → 尝试混合模式
      if (subgraph == null && allowMixed) {
        subgraph = selector.selectMixed(
          targetSize: targetSize,
          minDifficulty: minDifficulty,
          maxDifficulty: maxDifficulty,
          leafDifficulty: mixedLeafMinDifficulty ?? maxDifficulty + 1,
          maxAttempts: 5,
        );
      }

      if (subgraph == null) continue;

      // Step 2: 布局
      final layoutResult = layout.layout(
        nodeIndices: subgraph.nodeIndices,
        subEdges: subgraph.edges,
        maxAttempts: 10,
      );

      if (layoutResult == null) continue;

      // Step 3: 验证
      final level = layoutResult.level;
      if (_validate(level)) {
        return GenerationResult(
          level: level,
          subgraph: subgraph,
          attempt: attempt + 1,
        );
      }
    }
    return null;
  }

  /// 验证关卡的合法性
  bool _validate(CrosswordLevel level) {
    // 检查每个成语的每个字是否都正确填入
    for (final placement in level.placements) {
      for (int k = 0; k < placement.idiom.text.length; k++) {
        final (r, c) = placement.cellAt(k);
        final cell = level.grid.cellAt(r, c);
        if (cell.character != placement.idiom.text[k]) {
          return false;
        }
      }
    }

    // 检查所有成语是否连通（至少有一个交叉）
    if (level.placements.length == 1) return true;

    final connected = <int>{0};
    final queue = <int>[0];
    while (queue.isNotEmpty) {
      final cur = queue.removeAt(0);
      for (int i = 0; i < level.placements.length; i++) {
        if (connected.contains(i)) continue;
        if (level.grid.findIntersection(
                level.placements[cur], level.placements[i]) !=
            null) {
          connected.add(i);
          queue.add(i);
        }
      }
    }
    return connected.length == level.placements.length;
  }
}

/// 生成结果
class GenerationResult {
  final CrosswordLevel level;
  final SubgraphResult subgraph;
  final int attempt;

  const GenerationResult({
    required this.level,
    required this.subgraph,
    required this.attempt,
  });
}

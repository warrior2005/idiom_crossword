import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/crossing_graph.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart';
import 'package:idiom_crossword/src/engine/subgraph_selector.dart';

/// 子图选取器单元测试（固定种子保证确定性）
void main() {
  final idioms = [
    const Idiom(text: '画蛇添足', difficulty: 5),
    const Idiom(text: '画龙点睛', difficulty: 10),
    const Idiom(text: '龙腾虎跃', difficulty: 15),
    const Idiom(text: '虎头蛇尾', difficulty: 20),
    const Idiom(text: '守株待兔', difficulty: 25),
    const Idiom(text: '兔死狐悲', difficulty: 30),
    const Idiom(text: '狐假虎威', difficulty: 30),
  ];
  final graph = CrossingGraph(idioms: idioms);

  test('strict 模式：全部节点在区间内且连通', () {
    final selector = SubgraphSelector(graph: graph, random: Random(1));
    final result = selector.select(
      targetSize: 4,
      minDifficulty: 5,
      maxDifficulty: 25,
      maxAttempts: 200,
    );
    expect(result, isNotNull);
    expect(result!.nodeIndices.length, 4);
    for (final i in result.nodeIndices) {
      expect(idioms[i].difficulty, inInclusiveRange(5, 25));
    }
    // 子图内边非空（连通性由 BFS 保证）
    expect(result.edges, isNotEmpty);
    expect(result.avgDifficulty, inInclusiveRange(5, 25));
    expect(result.density, greaterThan(0));
  });

  test('候选不足返回 null', () {
    final selector = SubgraphSelector(graph: graph, random: Random(1));
    expect(
      selector.select(
        targetSize: 6,
        minDifficulty: 5,
        maxDifficulty: 10,
        maxAttempts: 50,
      ),
      isNull,
    );
  });

  test('selectMixed 允许一个桥接叶子节点', () {
    final selector = SubgraphSelector(graph: graph, random: Random(2));
    final result = selector.selectMixed(
      targetSize: 4,
      minDifficulty: 5,
      maxDifficulty: 20,
      leafDifficulty: 25,
      maxAttempts: 200,
    );
    expect(result, isNotNull);
    expect(result!.nodeIndices.length, 4);
    // 至少一个节点来自叶子池（难度 ≥ 25）
    expect(
      result.nodeIndices.any((i) => idioms[i].difficulty >= 25),
      isTrue,
    );
    expect(result.edges, isNotEmpty);
  });
}

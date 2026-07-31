import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/crossing_graph.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart';

/// 交叉图 API 单元测试
void main() {
  final idioms = [
    const Idiom(text: '画蛇添足'),
    const Idiom(text: '守株待兔'),
    const Idiom(text: '画龙点睛'),
    const Idiom(text: '添油加醋'),
    const Idiom(text: '兔死狐悲'),
  ];
  final graph = CrossingGraph(idioms: idioms);

  test('规模统计', () {
    expect(graph.nodeCount, idioms.length);
    expect(graph.uniqueCharCount, greaterThan(0));
  });

  test('getEdges 返回共享字成语，两端字符一致', () {
    final edges = graph.getEdges(0); // 画蛇添足
    final texts = edges.map((e) => idioms[e.idiomB].text).toSet();
    expect(texts, contains('画龙点睛'));
    expect(texts, contains('添油加醋'));
    for (final e in edges) {
      expect(idioms[e.idiomA].text[e.posInA], idioms[e.idiomB].text[e.posInB]);
    }
  });

  test('findCrossings 两端位置过滤独立生效（回归修复）', () {
    // 画蛇添足[2]=添 ↔ 添油加醋[0]=添
    final cross = graph.findCrossings(char: '添', posInA: 2, posInB: 0);
    expect(cross, hasLength(1));
    expect(idioms[cross.single.idiomA].text, '画蛇添足');
    expect(idioms[cross.single.idiomB].text, '添油加醋');

    // 两端位置都要求 2 → 无结果（旧实现会错误返回）
    expect(graph.findCrossings(char: '添', posInA: 2, posInB: 2), isEmpty);
  });

  test('getNeighbors 支持 withinPool 过滤', () {
    final all = graph.getNeighbors(0);
    expect(all, containsAll([2, 3]));
    expect(graph.getNeighbors(0, withinPool: {2}), [2]);
  });

  test('charFrequency / getMostCommonChar', () {
    expect(graph.charFrequency('画'), 2);
    expect(graph.charFrequency('蛇'), 1);
    final (ch, pos, freq) = graph.getMostCommonChar(0);
    expect(freq, greaterThan(0));
    expect(idioms[0].text[pos], ch);
  });
}

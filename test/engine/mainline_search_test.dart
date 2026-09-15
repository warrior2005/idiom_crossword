import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/crossing_graph.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart';
import 'package:idiom_crossword/src/engine/integrated_generator.dart';

void main() {
  test('普通词不足时可用末尾备用词补齐，仍受选词约束', () {
    final graph = CrossingGraph(
      idioms: [
        const Idiom(text: '十全十美', difficulty: 1),
        const Idiom(text: '五光十色', difficulty: 1),
        const Idiom(text: '五彩缤纷', difficulty: 1),
      ],
    );
    CrosswordLevel? run(bool allow) =>
        IntegratedGenerator(graph: graph, random: Random(9)).generate(
          targetSize: 3,
          minDifficulty: 1,
          maxDifficulty: 50,
          boundedSearch: true,
          candidatePool: {0, 1},
          fallbackPool: {2},
          preferredSeeds: {'十全十美'},
          canSelect: (words) => allow || !words.any((i) => i.text == '五彩缤纷'),
        );
    expect(run(true)?.idioms.map((i) => i.text), contains('五彩缤纷'));
    expect(run(false), isNull);
  });
  test('后续布局尝试仍保留必需熟悉词起点，不只用于前三次', () {
    final graph = CrossingGraph(
      idioms: [
        const Idiom(text: '画龙点睛', difficulty: 1),
        const Idiom(text: '龙飞凤舞', difficulty: 1),
        const Idiom(text: '飞黄腾达', difficulty: 1),
      ],
    );
    final roots = <String>[];
    final level = IntegratedGenerator(graph: graph, random: Random(8)).generate(
      targetSize: 3,
      minDifficulty: 1,
      maxDifficulty: 50,
      maxAttempts: 4,
      boundedSearch: true,
      preferredSeeds: {'龙飞凤舞'},
      fallbackSeeds: {'龙飞凤舞'},
      accept: (candidate) {
        roots.add(candidate.idioms.first.text);
        return roots.length == 4;
      },
    );
    expect(level, isNotNull);
    expect(roots, List.filled(4, '龙飞凤舞'));
  });

  test('选入死路词后能撤回，保留已找到的合法布局继续扩展', () {
    final graph = CrossingGraph(
      idioms: [
        const Idiom(text: '画龙点睛', difficulty: 1),
        const Idiom(text: '画蛇添足', difficulty: 1),
        const Idiom(text: '龙飞凤舞', difficulty: 1),
        const Idiom(text: '飞黄腾达', difficulty: 1),
      ],
    );
    final result = IntegratedGenerator(graph: graph, random: Random(7))
        .generate(
          targetSize: 3,
          minDifficulty: 1,
          maxDifficulty: 50,
          boundedSearch: true,
          maxAttempts: 1,
          preferredSeeds: {'画龙点睛'},
          wordPriority: (w) => w == '画蛇添足' ? 0 : 1,
          canSelect: (words) =>
              words.length < 3 || !words.any((i) => i.text == '画蛇添足'),
        );
    expect(result, isNotNull);
    expect(result!.idioms.map((i) => i.text), isNot(contains('画蛇添足')));
  });
}

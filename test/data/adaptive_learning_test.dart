import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/adaptive_learning.dart';
import 'package:idiom_crossword/src/engine/adaptive_policy.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart';

CrosswordLevel puzzle(
  int n, {
  List<int> tiers = const [1, 1, 1, 1, 1, 1],
  int givens = 1,
}) {
  final grid = CrosswordGrid(rows: tiers.length, cols: 4);
  final placements = <Placement>[];
  for (var i = 0; i < tiers.length; i++) {
    final word =
        '词${String.fromCharCode(0x4e00 + n)}${String.fromCharCode(0x4e00 + i)}语';
    for (var j = 0; j < 4; j++) {
      grid.cellAt(i, j).state = CellState.filled;
      grid.cellAt(i, j).character = word[j];
      grid.cellAt(i, j).isGiven = j < givens;
    }
    placements.add(
      Placement(
        idiom: Idiom(text: word),
        startRow: i,
        startCol: 0,
        direction: Direction.horizontal,
      ),
    );
  }
  return CrosswordLevel(
    levelId: n,
    grid: grid,
    placements: placements,
    givenCharacters: {},
    title: 'test',
    strategyVersion: 4,
    instanceId: 'v4_$n',
    strategy: {
      'wordTiers': {
        for (var i = 0; i < tiers.length; i++)
          placements[i].idiom.text: tiers[i],
      },
    },
  );
}

Map<String, dynamic> fresh({int tier = 1, int step = 0}) {
  final data = <String, dynamic>{
    'sessions': [],
    'words': {},
    'adaptive': {'step': step},
  };
  AdaptiveLearning.initialize(data, {
    for (var i = 0; i < 10000; i++) 'word$i': i % 4 + 1,
  }, 6);
  final s = data['adaptiveV4'] as Map;
  s['tier'] = tier;
  s['mix'] = [...AdaptiveLearning.mixes[tier - 1]];
  return data;
}

void observe(
  Map<String, dynamic> data,
  CrosswordLevel p, {
  bool success = true,
  int hints = 0,
  int errors = 0,
  int ms = 0,
  Set<String> wrong = const {},
  Set<String>? hinted = const {},
}) {
  AdaptiveLearning.observe(
    data,
    p,
    successful: success,
    solved: success ? p.idioms.map((i) => i.text).toSet() : {},
    wrong: wrong,
    hinted: hinted,
    hints: hints,
    errors: errors,
    activeTimeMs: ms,
  );
}

void cover(Map<String, dynamic> data, int tier, double fraction) {
  final s = data['adaptiveV4'] as Map;
  s['totals']['$tier'] = 10000;
  s['coverage']['$tier'] = List.generate(
    (fraction * 10000).round(),
    (i) => 'covered$i',
  );
}

List<double> mix(Map<String, dynamic> data) =>
    (data['adaptiveV4']['mix'] as List).cast<double>();

void main() {
  test('覆盖率边界与全档分母；重复词不增加，改档重新归属', () {
    expect(
      [
        .1999,
        .2,
        .2999,
        .3,
        .3999,
        .4,
        .4999,
        .5,
      ].map(AdaptiveLearning.explorationCap),
      [0, .2, .2, .35, .35, .5, .5, 1],
    );
    final data = fresh();
    final p = puzzle(1);
    observe(data, p);
    observe(data, p);
    expect(data['adaptiveV4']['coverage']['1'].length, 6);
    expect(
      AdaptiveLearning.coverage(AdaptiveLearning.state(data), 1),
      6 / 2500,
    );
    AdaptiveLearning.initialize(data, {for (final w in p.idioms) w.text: 2}, 7);
    expect(data['adaptiveV4']['coverage']['1'], isEmpty);
    expect(data['adaptiveV4']['coverage']['2'].length, 6);
    expect(data['adaptiveV4']['totals']['2'], 6);
  });
  test('词级提示不污染其他词；未知提示归属与三字预填不计覆盖', () {
    final data = fresh();
    final p = puzzle(1);
    observe(data, p, hints: 1, hinted: {p.idioms.first.text});
    expect(data['adaptiveV4']['coverage']['1'].length, 5);
    observe(data, puzzle(2), hints: 1, hinted: null);
    observe(data, puzzle(3, givens: 3));
    expect(data['adaptiveV4']['coverage']['1'].length, 5);
  });
  test('不满20%不引入；满20%且10次顺利后仅一个试探词', () {
    final below = fresh();
    for (var i = 1; i <= 20; i++) {
      observe(below, puzzle(i));
    }
    expect(mix(below)[1], 0);
    final data = fresh();
    cover(data, 1, .2);
    for (var i = 1; i <= 9; i++) {
      observe(data, puzzle(i));
    }
    expect(mix(data)[1], 0);
    observe(data, puzzle(10));
    expect(mix(data)[1], closeTo(1 / 6, 1e-8));
    expect(data['adaptive']['step'], 0);
    for (var seq = 0; seq < 10; seq++) {
      expect(AdaptiveLearning.quotas(mix(data), 6, seq)[2], 1);
    }
  });
  test('配额上限有效且未到50%不交接；达到50%才逐步进入下一阶段', () {
    for (final fraction in [.2, .3, .4, .5]) {
      final data = fresh();
      cover(data, 1, fraction);
      for (var i = 1; i <= 100; i++) {
        observe(data, puzzle(i, tiers: const [1, 2, 2, 2, 2, 2]));
      }
      expect(
        mix(data)[1],
        lessThanOrEqualTo(AdaptiveLearning.explorationCap(fraction) + 1e-8),
      );
      expect(data['adaptiveV4']['tier'], fraction < .5 ? 1 : 2);
    }
  });
  test('高覆盖仍可受挫回退，清除已消费窗口，3次后才再减负', () {
    final data = fresh(tier: 2);
    cover(data, 2, .9);
    final before = [...mix(data)];
    for (var i = 1; i <= 3; i++) {
      observe(data, puzzle(i, tiers: const [1, 2, 2, 2, 2, 2]), success: false);
    }
    expect(mix(data)[1], closeTo(before[1] - 1 / 6, 1e-8));
    final after = [...mix(data)];
    observe(data, puzzle(4, tiers: const [1, 2, 2, 2, 2, 2]));
    observe(data, puzzle(5, tiers: const [1, 2, 2, 2, 2, 2]));
    expect(mix(data), after);
    expect(
      data['adaptiveV4']['coverage']['2'].length,
      greaterThanOrEqualTo(9000),
    );
  });
  test('持续提示可减负；题面减负跳过相同预算的step', () {
    final data = fresh(step: 2);
    final before = AdaptivePolicy(100, 2);
    for (var i = 100; i < 105; i++) {
      observe(data, puzzle(i), hints: 1);
    }
    final step = data['adaptive']['step'] as int;
    final after = AdaptivePolicy(100, step);
    expect(step, lessThan(2));
    expect(
      after.answerTarget < before.answerTarget ||
          after.candidateCount(after.answerTarget) <
              before.candidateCount(before.answerTarget),
      isTrue,
    );
  });
  test('时间去掉一次挂机，持续变慢阻止升级并减负；缺失时间不计0', () {
    final data = fresh(step: 15);
    for (var i = 1; i <= 15; i++) {
      observe(data, puzzle(i), ms: 18000);
    }
    expect(data['adaptiveV4']['timeRatio'], closeTo(1, 1e-8));
    observe(data, puzzle(16), ms: 1800000);
    expect(data['adaptiveV4']['timeRatio'], closeTo(1, 1e-8));
    final step = data['adaptive']['step'];
    for (var i = 17; i <= 23; i++) {
      observe(data, puzzle(i), ms: 36000);
    }
    expect(data['adaptive']['step'], lessThan(step as int));
    final count = (data['adaptiveV4']['timings'] as List).length;
    observe(data, puzzle(24), ms: 0);
    expect((data['adaptiveV4']['timings'] as List).length, count);
  });
  test('计时按待填字数归一化，失败快速退出不提供速度证据', () {
    final data = fresh();
    for (var i = 1; i <= 15; i++) {
      observe(data, puzzle(i), ms: 18000);
    }
    observe(data, puzzle(16, tiers: const [1, 1, 1, 1, 1, 1, 1, 1]), ms: 24000);
    expect(data['adaptiveV4']['timeRatio'], closeTo(1, 1e-8));
    final count = (data['adaptiveV4']['timings'] as List).length;
    observe(data, puzzle(17), success: false, ms: 1);
    expect((data['adaptiveV4']['timings'] as List).length, count);
  });
  test('生僻稳定混合覆盖低档；关号10000不影响配额', () {
    for (var size = 6; size <= 12; size++) {
      final totals = [0, 0, 0, 0];
      for (var seq = 0; seq < 10; seq++) {
        final q = AdaptiveLearning.quotas(AdaptiveLearning.mixes[3], size, seq);
        expect(q.values.reduce((a, b) => a + b), size);
        for (var t = 1; t <= 4; t++) {
          totals[t - 1] += q[t]!;
        }
      }
      for (var i = 0; i < 4; i++) {
        expect(
          totals[i] / (10 * size),
          closeTo(AdaptiveLearning.mixes[3][i], .017),
        );
      }
    }
  });
  test('高覆盖连续顺利逐档交接，长期混合稳定；转弱后可以逐步退回', () {
    final data = fresh();
    for (var t = 1; t <= 3; t++) {
      cover(data, t, .6);
    }
    for (var n = 11; n <= 500; n++) {
      final step = data['adaptive']['step'] as int;
      final size = AdaptivePolicy(n, step).size;
      final before = [...mix(data)];
      final previousTier = data['adaptiveV4']['tier'] as int;
      final q = AdaptiveLearning.quotas(before, size, n);
      observe(
        data,
        puzzle(
          n,
          tiers: [
            for (var t = 1; t <= 4; t++)
              for (var j = 0; j < q[t]!; j++) t,
          ],
        ),
      );
      final moved = List.generate(
        4,
        (i) => maxPositive(mix(data)[i] - before[i]),
      ).reduce((a, b) => a + b);
      expect(moved, lessThanOrEqualTo(1 / size + 1e-8));
      expect(
        (data['adaptiveV4']['tier'] as int) - previousTier,
        inInclusiveRange(0, 1),
      );
    }
    expect(data['adaptiveV4']['tier'], 4);
    for (var i = 0; i < 4; i++) {
      expect(mix(data)[i], closeTo(AdaptiveLearning.mixes[3][i], 1e-8));
    }
    for (var n = 501; n <= 650; n++) {
      final size = AdaptivePolicy(n, data['adaptive']['step'] as int).size;
      final q = AdaptiveLearning.quotas(mix(data), size, n);
      observe(
        data,
        puzzle(
          n,
          tiers: [
            for (var t = 1; t <= 4; t++)
              for (var j = 0; j < q[t]!; j++) t,
          ],
        ),
        success: false,
      );
    }
    expect(data['adaptiveV4']['tier'], 1);
    expect(mix(data)[0], closeTo(1, 1e-8));
    expect(data['adaptive']['step'], lessThan(0));
  });

  test('旧玩家保留阶段与证据，10次观察后每次最多转移一个名额', () {
    final data = <String, dynamic>{
      'sessions': [],
      'words': {},
      'adaptive': {'step': 30},
      'progression': {
        'tier': 4,
        'next': 0,
        'evidence': {
          '4': {
            'words': ['old'],
          },
        },
      },
    };
    AdaptiveLearning.initialize(data, {'old': 4}, 6);
    expect(data['adaptiveV4']['tier'], 4);
    expect(data['adaptiveV4']['coverage']['4'], ['old']);
    final before = [...mix(data)];
    for (var i = 1; i <= 10; i++) {
      observe(data, puzzle(i, tiers: const [4, 4, 4, 4, 4, 4]));
    }
    expect(mix(data), before);
    observe(data, puzzle(11, tiers: const [4, 4, 4, 4, 4, 4]));
    final moved = List.generate(
      4,
      (i) => maxPositive(mix(data)[i] - before[i]),
    ).reduce((a, b) => a + b);
    expect(moved, lessThanOrEqualTo(1 / 6 + 1e-8));
    expect(moved, greaterThan(0));
    final encoded = jsonEncode(data);
    AdaptiveLearning.initialize(data, {'old': 4}, 6);
    expect(data['adaptiveV4']['tier'], 4);
    expect(jsonDecode(encoded)['adaptiveV4']['mix'], mix(data));
  });
}

double maxPositive(double v) => v < 0 ? 0 : v;

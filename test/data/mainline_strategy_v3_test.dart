import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/mainline_exposure.dart';
import 'package:idiom_crossword/src/data/mainline_learning.dart';
import 'package:idiom_crossword/src/data/tier_progression.dart';
import 'package:idiom_crossword/src/engine/adaptive_policy.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart' as e;

e.CrosswordLevel puzzle(int n, List<String> words, Map<String, int> tiers) {
  final grid = e.CrosswordGrid(rows: words.length, cols: 4);
  final placements = <e.Placement>[];
  for (var j = 0; j < words.length; j++) {
    for (var k = 0; k < 4; k++) {
      final c = grid.cellAt(j, k);
      c.state = e.CellState.filled;
      c.character = words[j][k];
      c.isGiven = k == 0;
    }
    placements.add(
      e.Placement(
        idiom: e.Idiom(text: words[j], difficulty: 1),
        startRow: j,
        startCol: 0,
        direction: e.Direction.horizontal,
      ),
    );
  }
  return e.CrosswordLevel(
    levelId: n,
    grid: grid,
    placements: placements,
    givenCharacters: {},
    title: 'test',
    strategyVersion: 3,
    instanceId: 'v3_$n',
    strategy: {'wordTiers': tiers},
  );
}

void main() {
  test('入门可快速试探基础；反复相同词不会跳档，各阶段不越档', () {
    final data = <String, dynamic>{};
    for (var n = 1; n <= 3; n++) {
      final words = ['甲乙丙$n', '丁戊己$n'];
      TierProgression.observe(
        data,
        puzzle(n, words, {for (final w in words) w: 1}),
        words.toSet(),
        {},
        0,
      );
    }
    expect(data['progression']['tier'], 1);
    expect(data['progression']['next'], 1);
    final single = <String, dynamic>{};
    for (var n = 1; n <= 30; n++) {
      TierProgression.observe(
        single,
        puzzle(n, ['画蛇添足'], {'画蛇添足': 1}),
        {'画蛇添足'},
        {},
        0,
      );
    }
    expect(single['progression']['next'], 0);
    for (var tier = 1; tier <= 4; tier++) {
      for (var next = 0; next < 12; next++) {
        final p = AdaptivePolicy(100, 30, tier: tier, nextCount: next);
        expect(p.quotas.values.reduce((a, b) => a + b), 12);
        expect(
          p.quotas.entries
              .where((e) => e.value > 0)
              .every((e) => e.key <= tier + 1),
          isTrue,
        );
      }
    }
  });

  test('旧版有可靠证据时承接阶段；受挫回撤不同时撤掉多词', () {
    final data = <String, dynamic>{
      'words': <String, dynamic>{},
      'tierPerformance': {
        '1': {'observations': 20, 'trend': .9},
        '2': {'observations': 20, 'trend': .9},
      },
    };
    final tiers = <String, int>{};
    for (var t = 1; t <= 2; t++) {
      for (var i = 0; i < 30; i++) {
        final word = '$t:$i';
        (data['words'] as Map)[word] = {'supported': 3};
        tiers[word] = t;
      }
    }
    TierProgression.restoreLegacy(data, tiers);
    expect(data['progression']['tier'], 2);
    final saved = jsonEncode(data);
    TierProgression.restoreLegacy(data, {});
    expect(jsonEncode(data), saved);
    final retreat = <String, dynamic>{
      'progression': {
        'tier': 3,
        'next': 0,
        'sinceChange': 7,
        'evidence': {
          '3': {'observations': 10, 'trend': .3, 'words': []},
        },
      },
    };
    final before = AdaptivePolicy(101, 0, tier: 3).quotas;
    TierProgression.observe(retreat, puzzle(101, ['画蛇添足'], {'画蛇添足': 3}), {}, {
      '画蛇添足',
    }, 1);
    final state = retreat['progression'] as Map;
    final after = AdaptivePolicy(
      101,
      0,
      tier: state['tier'] as int,
      nextCount: state['next'] as int,
    ).quotas;
    expect(state['tier'], 2);
    expect(
      [1, 2, 3, 4].fold<int>(
        0,
        (n, t) =>
            n + ((after[t]! - before[t]!) > 0 ? after[t]! - before[t]! : 0),
      ),
      1,
    );
  });

  test('持续只完成一半仍会缓慢减负，不把失败当成稳定通过', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.setSetting(
      MainlineLearning.key,
      jsonEncode({
        'sessions': [],
        'words': {},
        'adaptive': {'step': 10, 'trend': .9, 'sinceChange': 0},
      }),
    );
    var last = 10, lastChange = 0;
    for (var n = 1; n <= 100; n++) {
      await MainlineLearning.record(
        db,
        puzzle(n, ['画蛇添足', '同行伴${String.fromCharCode(0x4e00 + n)}'], {}),
        status: 'failed',
        hints: 0,
        errors: 1,
        completed: ['画蛇添足'],
      );
      final step = await MainlineLearning.ability(db);
      if (step != last) {
        expect(n - lastChange, greaterThanOrEqualTo(5));
        lastChange = n;
      }
      expect((step - last).abs(), lessThanOrEqualTo(1));
      last = step;
    }
    expect(last, -5);
    expect(
      (await MainlineLearning.read(db))['words']['画蛇添足']['practices'],
      100,
    );
  });

  test('主动复习只来自词级薄弱证据；冷却优先于到期，自然成功退出', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final start = DateTime(2026, 9, 14);
    final first = puzzle(1, ['画蛇添足', '画龙点睛'], {'画蛇添足': 2, '画龙点睛': 2});
    await MainlineLearning.record(
      db,
      first,
      status: 'complete',
      hints: 1,
      errors: 1,
      wrong: {'画蛇添足'},
      completed: ['画蛇添足', '画龙点睛'],
      now: start,
    );
    var data = await MainlineLearning.read(db);
    expect(data['words']['画蛇添足']['reviewNeeded'], isTrue);
    expect(data['words']['画龙点睛']['reviewNeeded'], isNot(true));
    expect(
      await MainlineLearning.dueWords(
        db,
        now: start.add(const Duration(days: 2)),
      ),
      isEmpty,
    );
    for (var n = 2; n <= 7; n++) {
      await MainlineLearning.record(
        db,
        puzzle(n, ['甲乙丙$n'], {}),
        status: 'active',
        hints: 0,
        errors: 0,
        now: start,
      );
    }
    expect(await MainlineLearning.dueWords(db, now: start), {'画蛇添足'});
    for (final n in [8, 15]) {
      await MainlineLearning.record(
        db,
        puzzle(
          n,
          ['画蛇添足', '同行伴${String.fromCharCode(0x4e00 + n)}'],
          {'画蛇添足': 2},
        ),
        status: 'complete',
        hints: 0,
        errors: 0,
        completed: ['画蛇添足'],
        now: start,
      );
      if (n == 8) {
        for (var j = 9; j < 15; j++) {
          await MainlineLearning.record(
            db,
            puzzle(j, ['甲乙丙${String.fromCharCode(0x4e00 + j)}'], {}),
            status: 'active',
            hints: 0,
            errors: 0,
            now: start,
          );
        }
      }
    }
    data = await MainlineLearning.read(db);
    expect(data['words']['画蛇添足']['reviewNeeded'], isFalse);
    final before = await db.getSetting(MainlineLearning.key);
    await MainlineLearning.record(
      db,
      first,
      status: 'complete',
      hints: 1,
      errors: 1,
      wrong: {'画蛇添足'},
      now: start,
    );
    expect(await db.getSetting(MainlineLearning.key), before);
  });

  test('并发初始化曝光记录不会覆盖刚展示的题', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final level = puzzle(1, ['画蛇添足'], {});
    await Future.wait([
      MainlineExposure.read(db),
      db.transaction(() => MainlineExposure.show(db, level)),
    ]);
    expect((await MainlineExposure.read(db))['sequence'], 1);
    expect(MainlineExposure.recentWords(await MainlineExposure.read(db)), {
      '画蛇添足',
    });
  });

  test('指纹无关词序；并发接纳防重；未展示不计曝光；失败题计冷却', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final a = puzzle(1, ['画蛇添足', '画龙点睛'], {});
    final b = puzzle(2, ['画龙点睛', '画蛇添足'], {});
    expect(
      MainlineExposure.fingerprint(a.idioms.map((i) => i.text)),
      MainlineExposure.fingerprint(b.idioms.map((i) => i.text)),
    );
    final reservations = await Future.wait([
      MainlineExposure.reserve(db, a),
      MainlineExposure.reserve(db, b),
    ]);
    expect(reservations.where((v) => v).length, 1);
    expect((await MainlineExposure.read(db))['sequence'], 0);
    await MainlineLearning.record(db, a, status: 'failed', hints: 0, errors: 1);
    var state = await MainlineExposure.read(db);
    expect(state['sequence'], 1);
    expect(MainlineExposure.recentWords(state), {'画蛇添足', '画龙点睛'});
    expect(await MainlineExposure.reserve(db, b), isFalse);
    final saved = jsonEncode(state);
    await MainlineLearning.record(db, a, status: 'paused', hints: 0, errors: 1);
    state = await MainlineExposure.read(db);
    expect(jsonEncode(state), saved);
  });
}

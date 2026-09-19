import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/adaptive_learning.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/mainline_exposure.dart';
import 'package:idiom_crossword/src/data/mainline_learning.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';
import 'package:idiom_crossword/src/state/level_state_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late AppDatabase db;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('adaptive_v4_');
    final file = await File(
      'assets/data/idiom_crossword.db',
    ).copy('${dir.path}/db');
    db = AppDatabase(NativeDatabase(file));
  });
  tearDown(() async {
    await db.close();
    await dir.delete(recursive: true);
  });

  test('真实数据库覆盖分母、幂等结算、提示归属及冻结题面兼容', () async {
    final level = (await generateLevel(db, 128, seed: 1200))!;
    final data = await MainlineLearning.read(db);
    final all = await db.select(db.idioms).get();
    for (var t = 1; t <= 4; t++) {
      expect(
        data['adaptiveV4']['totals']['$t'],
        all.where((w) => w.difficultyTier == t).length,
      );
    }
    final hinted = level.idioms.first.text;
    await MainlineLearning.record(
      db,
      level,
      status: 'complete',
      hints: 1,
      errors: 0,
      hinted: {hinted},
      completed: level.idioms.map((i) => i.text),
      activeTimeMs: 60000,
    );
    final settled = await MainlineLearning.read(db);
    final coverage = (settled['adaptiveV4']['coverage'] as Map).values.expand(
      (v) => (v as List),
    );
    expect(coverage, isNot(contains(hinted)));
    final eligible = level.placements.where(
      (p) =>
          p.idiom.text != hinted &&
          p.cells.where((c) => level.grid.cellAt(c.$1, c.$2).isGiven).length <=
              2,
    );
    expect(coverage, containsAll(eligible.map((p) => p.idiom.text)));
    final before = await db.getSetting(MainlineLearning.key);
    await MainlineLearning.record(
      db,
      level,
      status: 'complete',
      hints: 0,
      errors: 0,
      activeTimeMs: 1,
    );
    expect(await db.getSetting(MainlineLearning.key), before);
    final encoded = encodeLevel(level);
    await db.addLevelHistory(
      levelNumber: 128,
      xpGained: 0,
      idiomsUsed: [],
      levelJson: encoded,
    );
    expect(encodeLevel((await loadOrGenerateLevel(db, 128))!), encoded);
  });

  test('实际生成与结算连续推进，先顺利后变慢会停止加难并回退', () async {
    final data = await MainlineLearning.read(db);
    await MainlineLearning.prepareAdaptive(db, data);
    final s = data['adaptiveV4'] as Map;
    s['tier'] = 3;
    s['mix'] = [...AdaptiveLearning.mixes[2]];
    final words = await (db.select(
      db.idioms,
    )..where((t) => t.difficultyTier.equals(3))).get();
    s['coverage']['3'] = words
        .take((words.length * .6).ceil())
        .map((w) => w.word)
        .toList();
    data['adaptive'] = {'step': 15};
    await db.setSetting(MainlineLearning.key, jsonEncode(data));
    var relieved = false;
    for (var n = 1; n <= 70; n++) {
      final level = await generateLevel(db, 200 + n, seed: 60000 + n);
      expect(level, isNotNull, reason: 'dynamic sample $n');
      final p = level!;
      await MainlineLearning.record(
        db,
        p,
        status: 'complete',
        hints: 0,
        errors: 0,
        hinted: {},
        completed: p.idioms.map((w) => w.text),
        activeTimeMs: p.fillableCells * (n <= 30 ? 5000 : 15000),
      );
      final after = await MainlineLearning.read(db);
      final reason = after['adaptiveV4']['lastReason'];
      if (n > 30 && ['vocabulary_relief', 'board_relief'].contains(reason)) {
        relieved = true;
      }
      if (n > 40) {
        expect(reason, isNot('vocabulary_progress'));
        expect(reason, isNot('board_progress'));
      }
    }
    expect(relieved, isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));

  for (final tier in [1, 2, 3, 4]) {
    test('真实词库阶段$tier连续40题跨10000关，低档配额及平滑约束', () async {
      final data = await MainlineLearning.read(db);
      await MainlineLearning.prepareAdaptive(db, data);
      final state = data['adaptiveV4'] as Map;
      state['tier'] = tier;
      state['mix'] = [...AdaptiveLearning.mixes[tier - 1]];
      // 稳定阶段生成轨迹：固定阶段，结算只负责覆盖、计时与实例去重。
      data['adaptive'] = {'step': tier == 4 ? 20 : 0};
      await db.setSetting(MainlineLearning.key, jsonEncode(data));
      final totals = [0, 0, 0, 0];
      final recent = <Set<String>>[];
      final fingerprints = <String>{};
      int? lastAnswers, lastCandidates;
      for (var i = 0; i < 40; i++) {
        final level = await generateLevel(
          db,
          9981 + i,
          seed: 9000 + tier * 100 + i,
        );
        expect(level, isNotNull, reason: 'tier $tier, sample $i');
        final p = level!;
        final words = p.idioms.map((w) => w.text).toSet();
        expect(fingerprints.add(MainlineExposure.fingerprint(words)), isTrue);
        for (final previous in recent.reversed.take(3)) {
          expect(words.intersection(previous), isEmpty);
        }
        recent.add(words);
        final actual = {for (var t = 1; t <= 4; t++) '$t': 0};
        for (final t in (p.strategy['wordTiers'] as Map).values.cast<int>()) {
          actual['$t'] = actual['$t']! + 1;
          totals[t - 1]++;
          expect(t, lessThanOrEqualTo(tier));
        }
        expect(actual, p.strategy['quotas']);
        final answers = p.fillableCells,
            candidates = p.initialCandidates!.expand((r) => r).length;
        if (lastAnswers != null) {
          expect((answers - lastAnswers).abs(), lessThanOrEqualTo(3));
          expect((candidates - lastCandidates!).abs(), lessThanOrEqualTo(5));
        }
        lastAnswers = answers;
        lastCandidates = candidates;
        await MainlineLearning.record(
          db,
          p,
          status: 'complete',
          hints: 0,
          errors: 0,
          hinted: {},
          completed: words,
          activeTimeMs: answers * 5000,
        );
        final current = await MainlineLearning.read(db);
        current['adaptiveV4']['tier'] = tier;
        current['adaptiveV4']['mix'] = [...AdaptiveLearning.mixes[tier - 1]];
        current['adaptive'] = {'step': tier == 4 ? 20 : 0};
        await db.setSetting(MainlineLearning.key, jsonEncode(current));
      }
      final total = totals.reduce((a, b) => a + b);
      for (var t = 0; t < 4; t++) {
        expect(
          totals[t] / total,
          closeTo(AdaptiveLearning.mixes[tier - 1][t], .017),
        );
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  }
}

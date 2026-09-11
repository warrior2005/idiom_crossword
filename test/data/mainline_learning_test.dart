import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/mainline_learning.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart' as e;
import 'dart:convert';

e.CrosswordLevel sample(int id, {int givens = 1}) {
  const word = e.Idiom(text: '画蛇添足', difficulty: 1);
  final grid = e.CrosswordGrid(rows: 1, cols: 4);
  for (var i = 0; i < 4; i++) {
    final c = grid.cellAt(0, i);
    c.state = e.CellState.filled;
    c.character = word.text[i];
    c.isGiven = i < givens;
  }
  return e.CrosswordLevel(
    levelId: id,
    grid: grid,
    placements: [
      const e.Placement(
        idiom: word,
        startRow: 0,
        startCol: 0,
        direction: e.Direction.horizontal,
      ),
    ],
    givenCharacters: {'画'},
    title: 'test',
    strategyVersion: 2,
    contentVersion: 1,
    instanceId: 'test_$id',
    strategy: const {
      'wordTiers': {'画蛇添足': 2},
    },
  );
}

void main() {
  test('持续受挫缓慢减负到下限，各档观察不重复', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var lastChange = 0;
    var previous = 0;
    for (var n = 1; n <= 40; n++) {
      await MainlineLearning.record(
        db,
        sample(n),
        status: 'failed',
        hints: 3,
        errors: 4,
      );
      await MainlineLearning.record(
        db,
        sample(n),
        status: 'failed',
        hints: 3,
        errors: 4,
      );
      final step = await MainlineLearning.ability(db);
      expect((step - previous).abs(), lessThanOrEqualTo(1));
      if (step != previous) {
        expect(n - lastChange, greaterThanOrEqualTo(5));
        lastChange = n;
      }
      previous = step;
    }
    expect(previous, -5);
    final data = await MainlineLearning.read(db);
    expect(data['tierPerformance']['2']['observations'], 40);
    expect(await MainlineLearning.weakTiers(db), {2});
  });

  test('超过四十题明细窗口后，重玩旧实例仍不重复观察或记忆计数', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (var n = 1; n <= 45; n++) {
      await MainlineLearning.record(
        db,
        sample(n),
        status: 'complete',
        hints: 0,
        errors: 0,
        completed: ['画蛇添足'],
      );
    }
    final before = await db.getSetting(MainlineLearning.key);
    await MainlineLearning.record(
      db,
      sample(1),
      status: 'complete',
      hints: 0,
      errors: 0,
      completed: ['画蛇添足'],
    );
    expect(await db.getSetting(MainlineLearning.key), before);
  });

  test('旧偏好不控制新策略，单次失败不降档，同题失败复活不重复观察', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.setSetting('mainline_ability', '2');
    expect(await MainlineLearning.ability(db), 0);
    await db.setSetting(
      MainlineLearning.key,
      jsonEncode({
        'sessions': [],
        'words': {},
        'adaptive': {'step': 10, 'trend': 0.7, 'sinceChange': 0},
      }),
    );
    for (final status in ['failed', 'paused', 'failed', 'complete']) {
      await MainlineLearning.record(
        db,
        sample(1),
        status: status,
        hints: 0,
        errors: 4,
      );
    }
    expect(await MainlineLearning.ability(db), 10);
    final data = await MainlineLearning.read(db);
    expect(data['adaptive']['sinceChange'], 1);
  });

  test('提示和多字支持不计独立完成；断点保存与通关不会重复计数', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime(2026, 9, 9);
    await MainlineLearning.record(
      db,
      sample(1),
      status: 'active',
      hints: 1,
      errors: 0,
      completed: ['画蛇添足'],
      now: now,
      activeTimeMs: 1234,
    );
    await MainlineLearning.record(
      db,
      sample(1),
      status: 'complete',
      hints: 1,
      errors: 0,
      completed: ['画蛇添足'],
      now: now,
      activeTimeMs: 1234,
    );
    var data = await MainlineLearning.read(db);
    expect(data['words']['画蛇添足']['practices'], 1);
    expect(data['words']['画蛇添足']['independent'], 0);
    expect(data['sessions'][0]['activeTimeMs'], 1234);
    expect(await MainlineLearning.dueWords(db, now: now), isEmpty);
    expect(
      await MainlineLearning.dueWords(
        db,
        now: now.add(const Duration(days: 1)),
      ),
      contains('画蛇添足'),
    );
    await MainlineLearning.record(
      db,
      sample(2, givens: 3),
      status: 'complete',
      hints: 0,
      errors: 0,
      completed: ['画蛇添足'],
      now: now,
    );
    data = await MainlineLearning.read(db);
    expect(data['words']['画蛇添足']['independent'], 0);
    await MainlineLearning.record(
      db,
      sample(3),
      status: 'complete',
      hints: 0,
      errors: 0,
      completed: ['画蛇添足'],
      now: now,
    );
    data = await MainlineLearning.read(db);
    expect(data['words']['画蛇添足']['independent'], 1);
    expect(data['words']['画蛇添足']['exposures'], 3);
    final cross = sample(4);
    cross.grid.cellAt(0, 1).isIntersection = true;
    await MainlineLearning.record(
      db,
      cross,
      status: 'complete',
      hints: 0,
      errors: 0,
      completed: ['画蛇添足'],
      now: now.add(const Duration(days: 2)),
    );
    data = await MainlineLearning.read(db);
    expect(data['words']['画蛇添足']['independent'], 1);
    await MainlineLearning.record(
      db,
      sample(5),
      status: 'complete',
      hints: 0,
      errors: 0,
      completed: ['画蛇添足'],
      now: now.add(const Duration(days: 2)),
    );
    data = await MainlineLearning.read(db);
    expect(data['words']['画蛇添足']['delayedIndependent'], 1);
    expect(
      await MainlineLearning.dueWords(
        db,
        now: now.add(const Duration(days: 8)),
      ),
      isEmpty,
    );
    expect(
      await MainlineLearning.dueWords(
        db,
        now: now.add(const Duration(days: 9)),
      ),
      contains('画蛇添足'),
    );
  });
  test('连续成功缓慢提升、交替成败不抖动，中断无影响，40次后仍保持观察间隔', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    var previous = 0;
    var lastChange = 0;
    for (var i = 1; i <= 80; i++) {
      await MainlineLearning.record(
        db,
        sample(i),
        status: 'complete',
        hints: 0,
        errors: 0,
      );
      final step = await MainlineLearning.ability(db);
      expect(step - previous, inInclusiveRange(0, 1));
      if (step != previous) {
        expect(i - lastChange, greaterThanOrEqualTo(5));
        lastChange = i;
      }
      previous = step;
    }
    expect(previous, greaterThan(0));
    for (var i = 81; i <= 100; i++) {
      await MainlineLearning.record(
        db,
        sample(i),
        status: i.isEven ? 'complete' : 'failed',
        hints: 0,
        errors: i.isEven ? 0 : 4,
      );
    }
    final before = await MainlineLearning.ability(db);
    for (var i = 101; i <= 110; i++) {
      await MainlineLearning.record(
        db,
        sample(i),
        status: 'paused',
        hints: 0,
        errors: 0,
      );
    }
    expect(await MainlineLearning.ability(db), before);
    expect(before, lessThanOrEqualTo(previous + 1));
  });
}

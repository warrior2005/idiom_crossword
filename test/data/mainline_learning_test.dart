import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/mainline_learning.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart' as e;
import 'package:idiom_crossword/src/engine/mainline_policy.dart';

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
    strategyVersion: 1,
    contentVersion: 1,
    instanceId: 'test_$id',
  );
}

void main() {
  test('默认轻松玩家连续失败后可进一步减轻，切换偏好重置窗口', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (var i = 1; i <= 5; i++) {
      await MainlineLearning.record(
        db,
        sample(i),
        status: 'failed',
        hints: 0,
        errors: 4,
      );
    }
    expect(await MainlineLearning.ability(db), -1);
    final policy = MainlinePolicy.forLevel(51, ability: -1);
    expect(policy.size, 5);
    expect(policy.support, 3);
    expect(policy.expansionLimit, 0);
    await MainlineLearning.setPreference(db, 2);
    await MainlineLearning.setPreference(db, 0);
    expect(await MainlineLearning.ability(db), 0);
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
  test('每5次终态才调整；中断不降级，40次后窗口仍稳定', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.setSetting('mainline_ability', '1');
    for (var i = 1; i <= 4; i++) {
      await MainlineLearning.record(
        db,
        sample(i),
        status: 'complete',
        hints: 0,
        errors: 0,
      );
      expect(await MainlineLearning.ability(db), 1);
    }
    await MainlineLearning.record(
      db,
      sample(5),
      status: 'complete',
      hints: 0,
      errors: 0,
    );
    expect(await MainlineLearning.ability(db), 2);
    for (var i = 6; i <= 40; i++) {
      await MainlineLearning.record(
        db,
        sample(i),
        status: 'complete',
        hints: 0,
        errors: 0,
      );
    }
    for (var i = 41; i <= 44; i++) {
      await MainlineLearning.record(
        db,
        sample(i),
        status: 'failed',
        hints: 0,
        errors: 4,
      );
      expect(await MainlineLearning.ability(db), 2);
    }
    await MainlineLearning.record(
      db,
      sample(45),
      status: 'paused',
      hints: 0,
      errors: 0,
    );
    expect(await MainlineLearning.ability(db), 2);
    await MainlineLearning.record(
      db,
      sample(45),
      status: 'failed',
      hints: 0,
      errors: 4,
    );
    expect(await MainlineLearning.ability(db), 1);
    await db.setSetting('mainline_ability', '2');
    expect(await MainlineLearning.ability(db), 2);
  });
}

import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/mainline_learning.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart' as e;
import 'package:idiom_crossword/src/state/level_generation.dart';

const target = '画蛇添足';

e.CrosswordLevel puzzle(
  int n,
  List<String> words, {
  int givens = 1,
  bool crossings = false,
}) {
  final grid = e.CrosswordGrid(rows: crossings ? 4 : words.length, cols: 4);
  final placements = <e.Placement>[];
  for (var i = 0; i < words.length; i++) {
    final p = e.Placement(
      idiom: e.Idiom(text: words[i]),
      startRow: crossings ? 0 : i,
      startCol: crossings ? i : 0,
      direction: crossings && i > 0
          ? e.Direction.vertical
          : e.Direction.horizontal,
    );
    for (var k = 0; k < 4; k++) {
      final pos = p.cells[k];
      final cell = grid.cellAt(pos.$1, pos.$2);
      cell.state = e.CellState.filled;
      cell.character = words[i][k];
      if (!crossings || i == 0) cell.isGiven = k < givens;
      if (crossings && i > 0 && k == 0) cell.isIntersection = true;
    }
    placements.add(p);
  }
  return e.CrosswordLevel(
    levelId: n,
    grid: grid,
    placements: placements,
    givenCharacters: {},
    title: 'test',
    strategyVersion: 3,
    instanceId: 'review_$n',
    strategy: {
      'wordTiers': {for (final w in words) w: 1},
    },
  );
}

Future<void> enterReview(AppDatabase db) => MainlineLearning.record(
  db,
  puzzle(1, [target]),
  status: 'complete',
  hints: 0,
  errors: 1,
  wrong: {target},
  completed: [target],
);

Future<void> intervening(AppDatabase db, int from, int to) async {
  for (var n = from; n <= to; n++) {
    await MainlineLearning.record(
      db,
      puzzle(n, ['旁${String.fromCharCode(0x4e00 + n)}支词']),
      status: 'active',
      hints: 0,
      errors: 0,
    );
  }
}

Future<Map<String, dynamic>> wordState(AppDatabase db) async =>
    Map<String, dynamic>.from(
      (await MainlineLearning.read(db))['words'][target],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('目标词正确，其他词提示或误填不影响两次成功退出', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await enterReview(db);
    await intervening(db, 2, 7);
    for (final n in [8, 15]) {
      final other = n == 8 ? '画龙点睛' : '五光十色';
      await MainlineLearning.record(
        db,
        puzzle(n, [target, other]),
        status: 'complete',
        hints: 1,
        errors: 1,
        hinted: {other},
        wrong: {other},
        completed: [target, other],
      );
      final state = await wordState(db);
      expect(state['reviewSuccesses'], n == 8 ? 1 : 2);
      expect(state['reviewNeeded'], n == 8);
      if (n == 8) await intervening(db, 9, 14);
    }
  });

  test('两个待填交叉格不阻止目标词退出复习', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await enterReview(db);
    await intervening(db, 2, 7);
    for (final n in [8, 15]) {
      final p = puzzle(
        n,
        n == 8 ? [target, '蛇鼠一窝', '添砖加瓦'] : [target, '蛇蝎心肠', '添油加醋'],
        crossings: true,
      );
      expect(
        p.placements.first.cells
            .where(
              (c) =>
                  p.grid.cellAt(c.$1, c.$2).isIntersection &&
                  !p.grid.cellAt(c.$1, c.$2).isGiven,
            )
            .length,
        2,
      );
      await MainlineLearning.record(
        db,
        p,
        status: 'complete',
        hints: 0,
        errors: 0,
        hinted: {},
        completed: p.idioms.map((i) => i.text),
      );
      expect((await wordState(db))['reviewSuccesses'], n == 8 ? 1 : 2);
      if (n == 8) await intervening(db, 9, 14);
    }
    expect((await wordState(db))['reviewNeeded'], isFalse);
  });

  test('目标词自身有提示、错误或三字预填时不计复习成功', () async {
    for (final signal in ['hint', 'wrong', 'given']) {
      final db = AppDatabase(NativeDatabase.memory());
      try {
        await enterReview(db);
        await intervening(db, 2, 7);
        await MainlineLearning.record(
          db,
          puzzle(8, [target, '画龙点睛'], givens: signal == 'given' ? 3 : 1),
          status: 'complete',
          hints: signal == 'hint' ? 1 : 0,
          errors: signal == 'wrong' ? 1 : 0,
          hinted: signal == 'hint' ? {target} : {},
          wrong: signal == 'wrong' ? {target} : {},
          completed: [target],
        );
        final state = await wordState(db);
        expect(state['reviewSuccesses'], 0, reason: signal);
        expect(state['reviewNeeded'], isTrue, reason: signal);
      } finally {
        await db.close();
      }
    }
  });

  test('旧提示归属缺失时按词级错误判断，无关提示不阻止退出', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await enterReview(db);
    await intervening(db, 2, 7);
    await MainlineLearning.record(
      db,
      puzzle(8, [target, '画龙点睛']),
      status: 'complete',
      hints: 1,
      errors: 0,
      wrong: {'画龙点睛'},
      completed: [target],
    );
    expect((await wordState(db))['reviewSuccesses'], 1);
  });

  test('累计错误次数不改变相同候选和随机种子下的选词', () async {
    final dir = await Directory.systemTemp.createTemp('review_priority_');
    const seeds = [17, 29, 881];
    final results = <int, List<e.CrosswordLevel>>{
      for (final seed in seeds) seed: [],
    };
    try {
      for (var i = 0; i < 2; i++) {
        final file = await File(
          'assets/data/idiom_crossword.db',
        ).copy('${dir.path}/db$i');
        final db = AppDatabase(NativeDatabase(file));
        try {
          for (final seed in seeds) {
            await db.setSetting(
              MainlineLearning.key,
              jsonEncode({
                'sessions': [],
                'adaptive': {'step': 0},
                'words': {
                  for (final word in [target, '四面八方', '一心一意', '五光十色'])
                    word: {
                      'reviewNeeded': true,
                      'reviewDue': 0,
                      'seenSequence': -100,
                      'reviewSignals': word == target && i == 1 ? 1000 : 1,
                    },
                },
              }),
            );
            final level = await generateLevel(
              db,
              1000 + seed,
              seed: seed,
              now: DateTime(2026, 10, 12),
            );
            expect(level, isNotNull);
            results[seed]!.add(level!);
          }
        } finally {
          await db.close();
        }
      }
      for (final seed in seeds) {
        final pair = results[seed]!;
        expect(
          pair[1].strategy['reviewWords'],
          pair[0].strategy['reviewWords'],
          reason: 'seed $seed',
        );
        expect(
          pair[1].idioms.map((w) => w.text).toList(),
          pair[0].idioms.map((w) => w.text).toList(),
          reason: 'seed $seed',
        );
      }
    } finally {
      await dir.delete(recursive: true);
    }
  });
}

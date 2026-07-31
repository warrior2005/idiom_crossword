import 'dart:io';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/state/level_state_codec.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart' as engine;
import 'package:idiom_crossword/src/state/level_generation.dart';

void main() {
  test('prebuilt DB matches drift v2 schema end to end', () async {
    // 在临时副本上验证，避免污染仓库内的资产数据库
    final tmpDir = await Directory.systemTemp.createTemp('idiom_db_test');
    final tmpDb = File('${tmpDir.path}/test.db');
    await File('assets/data/idiom_crossword.db').copy(tmpDb.path);
    final db = AppDatabase(NativeDatabase(tmpDb));

    // 核心查询：按难度取成语
    final idioms = await db.findIdiomsByDifficulty(1, 5, 10);
    expect(idioms, isNotEmpty);
    expect(idioms.length, 10);
    expect(idioms.first.word.length, 4);
    expect(idioms.first.createdAt, isNotNull);

    // 学习模式用：按词查询完整资料（含出处/例句）
    final byWord = await db.findIdiomByWord(idioms.first.word);
    expect(byWord, isNotNull);
    expect(byWord!.explanation, isNotEmpty);
    expect(byWord.derivation, isNotNull);
    expect(byWord.example, isNotNull);

    // 自定义关卡：固定难度区间 + 目标数量 + 标题
    final custom = await generateLevel(
      db,
      0,
      targetSize: 6,
      difficultyRange: (1, 30),
      title: '自定义关卡',
    );
    expect(custom, isNotNull);
    expect(custom!.levelId, 0);
    expect(custom.title, '自定义关卡');
    expect(custom.placements.length, 6);
    expect(custom.placements.first.idiom.difficulty, inInclusiveRange(1, 30));

    // 每日挑战全链路确定性：同一天种子 + 非随机取数 → 两次生成一致
    final dailyNumber = dailyLevelNumber(DateTime.utc(2026, 7, 31));
    final dailyA = await generateLevel(
      db,
      dailyNumber,
      seed: 20454,
      targetSize: 6,
      difficultyRange: (10, 40),
    );
    final dailyB = await generateLevel(
      db,
      dailyNumber,
      seed: 20454,
      targetSize: 6,
      difficultyRange: (10, 40),
    );
    expect(dailyA, isNotNull);
    String signature(engine.CrosswordLevel l) => l.placements
        .map(
          (p) =>
              '${p.idiom.text}@${p.startRow},${p.startCol}:${p.direction.index}',
        )
        .join('|');
    expect(signature(dailyA!), signature(dailyB!));

    // 倒装对查询
    final first = idioms.first;
    final reversible = await db.findReversibleForm(first.id);
    expect(reversible, isA<Idiom?>());

    // 玩家进度 upsert + 回读
    expect(await db.getPlayerProgress(), isNull);
    await db.updatePlayerProgress(
      level: 2,
      totalXp: 260,
      completedLevels: 3,
      hintCards: 5,
      reviveCards: 1,
    );
    final progress = await db.getPlayerProgress();
    expect(progress, isNotNull);
    expect(progress!.level, 2);
    expect(progress.hintCards, 5);

    // 收藏 + 回读
    await db.addToCollection(first.id);
    expect(await db.isInCollection(first.id), isTrue);
    final collection = await db.getCollectionWithDetails();
    expect(collection, isNotEmpty);
    expect(collection.first.word, first.word);

    // 关卡历史 + 完成状态查询
    expect(await db.isLevelCompleted(7), isFalse);
    await db.addLevelHistory(
      levelNumber: 7,
      xpGained: 20,
      idiomsUsed: [first.id],
      timeSpentMs: 12345,
      hintsUsed: 2,
      errorsMade: 3,
    );
    expect(await db.isLevelCompleted(7), isTrue);
    expect(await db.getCompletedLevelNumbers(), contains(7));
    final history = await db.getLevelHistory();
    expect(history.single.errorsMade, 3);
    expect(history.single.timeSpentMs, 12345);

    // 统计查询
    expect(await db.getCollectionCount(), 1);

    // 装饰
    expect(await db.getOwnedDecorationIds(), isEmpty);
    await db.addDecoration('grid_skin', 'bamboo');
    expect(await db.getOwnedDecorationIds(), contains('grid_skin_bamboo'));

    // 成就
    expect(await db.getUnlockedAchievementIds(), isEmpty);
    await db.unlockAchievement('firstLevel');
    await db.unlockAchievement('firstLevel'); // 幂等
    expect(await db.getUnlockedAchievementIds(), {'firstLevel'});

    // 设置
    expect(await db.getSetting('sound_enabled'), isNull);
    await db.setSetting('sound_enabled', 'false');
    expect(await db.getSetting('sound_enabled'), 'false');
    await db.setSetting('sound_enabled', 'true'); // 覆盖式
    expect(await db.getSetting('sound_enabled'), 'true');

    // 关卡存档（断点续玩）
    expect(await db.getLevelState(first.id), isNull);
    await db.saveLevelState(
      levelNumber: first.id,
      levelJson: '{"levelId":1}',
      stateJson: '{"answers":[]}',
    );
    final savedState = await db.getLevelState(first.id);
    expect(savedState, isNotNull);
    expect(savedState!.stateJson, contains('answers'));
    await db.clearLevelState(first.id);
    expect(await db.getLevelState(first.id), isNull);

    // schema 版本应与 database.dart 一致
    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 6);

    await db.close();
    await tmpDir.delete(recursive: true);
  });

  test('level codec roundtrips a level and game state', () {
    final grid = engine.CrosswordGrid(rows: 2, cols: 3);
    final cells = [grid.cellAt(0, 0), grid.cellAt(0, 1), grid.cellAt(1, 0)];
    for (final cell in cells) {
      cell.state = engine.CellState.filled;
    }
    grid.cellAt(0, 0).character = '画';
    grid.cellAt(0, 0).isGiven = true;
    grid.cellAt(0, 1).character = '蛇';
    grid.cellAt(1, 0).isIntersection = true;

    const idiom = engine.Idiom(
      text: '画蛇添足',
      pinyin: 'hua she tian zu',
      meaning: '比喻做了多余的事',
      difficulty: 3,
      source: '《战国策》',
    );
    final level = engine.CrosswordLevel(
      levelId: 7,
      grid: grid,
      placements: [
        engine.Placement(
          idiom: idiom,
          startRow: 0,
          startCol: 0,
          direction: engine.Direction.horizontal,
        ),
      ],
      givenCharacters: {'画'},
      title: '第 7 关',
    );

    final restored = decodeLevel(encodeLevel(level));
    expect(restored, isNotNull);
    expect(restored!.levelId, 7);
    expect(restored.title, '第 7 关');
    expect(restored.grid.rows, 2);
    expect(restored.grid.cols, 3);
    expect(restored.grid.cellAt(0, 0).character, '画');
    expect(restored.grid.cellAt(0, 0).isGiven, isTrue);
    expect(restored.grid.cellAt(1, 0).isIntersection, isTrue);
    expect(restored.placements.single.idiom.text, '画蛇添足');
    expect(restored.placements.single.idiom.meaning, '比喻做了多余的事');
    expect(restored.givenCharacters, {'画'});

    const state = SavedGameState(
      answers: {(0, 1): '蛇'},
      usedCandidateSlots: {(0, 0)},
      fillHistory: [(row: 0, col: 1, candRow: 0, candCol: 0)],
      cellToCandidateSlot: {(0, 1): (0, 0)},
      candidateBoard: [
        ['蛇', '添', '足'],
        ['画', '守', '株'],
      ],
      hintUsesThisLevel: 2,
      idiomHintUsed: true,
      errorsMade: 1,
      correctStreak: 3,
      focusRow: 0,
      focusCol: 2,
      direction: engine.Direction.vertical,
    );
    final restoredState = decodeGameState(encodeGameState(state));
    expect(restoredState, isNotNull);
    expect(restoredState!.answers, {(0, 1): '蛇'});
    expect(restoredState.usedCandidateSlots, {(0, 0)});
    expect(restoredState.fillHistory.single.candCol, 0);
    expect(restoredState.cellToCandidateSlot[(0, 1)], (0, 0));
    expect(restoredState.candidateBoard[1][1], '守');
    expect(restoredState.hintUsesThisLevel, 2);
    expect(restoredState.idiomHintUsed, isTrue);
    expect(restoredState.errorsMade, 1);
    expect(restoredState.correctStreak, 3);
    expect(restoredState.focusCol, 2);
    expect(restoredState.direction, engine.Direction.vertical);

    expect(decodeLevel('not json'), isNull);
    expect(decodeGameState('not json'), isNull);
  });

  test('v5 数据库可正常升级到 v6（onUpgrade 迁移）', () async {
    final tmpDir = await Directory.systemTemp.createTemp('idiom_migrate');
    final tmpDb = File('${tmpDir.path}/migrate.db');
    await File('assets/data/idiom_crossword.db').copy(tmpDb.path);

    // 模拟 v5 状态：移除 settings_table 并把 user_version 置为 5
    final conn = sqlite.sqlite3.open(tmpDb.path);
    conn.execute('DROP TABLE settings_table');
    conn.execute('PRAGMA user_version = 5');
    conn.close();

    final db = AppDatabase(NativeDatabase(tmpDb));
    expect(await db.getSetting('sound_enabled'), isNull);
    await db.setSetting('sound_enabled', 'true');
    expect(await db.getSetting('sound_enabled'), 'true');
    await db.close();
    await tmpDir.delete(recursive: true);
  });
}

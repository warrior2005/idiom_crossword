import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/state/level_state_codec.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart' as engine;
import 'package:idiom_crossword/src/state/level_generation.dart';

/// 内存库 + 插入一条成语（供 getIdiomAtOffset 等测试）
Future<AppDatabase> _memoryDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  await db
      .into(db.idioms)
      .insert(
        IdiomsCompanion(
          word: const Value('画蛇添足'),
          pinyin: const Value('hua she tian zu'),
          pinyinAbbr: const Value('hstz'),
          explanation: const Value('比喻做了多余的事'),
          firstChar: const Value('画'),
          lastChar: const Value('足'),
          difficulty: const Value(5),
        ),
      );
  return db;
}

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
      levelJson: '{"frozen":true}',
    );
    expect(await db.isLevelCompleted(7), isTrue);
    expect(await db.getCompletedLevelNumbers(), contains(7));
    final history = await db.getLevelHistory();
    expect(history.single.errorsMade, 3);
    expect(history.single.timeSpentMs, 12345);
    expect(await db.getLevelDefinition(7), '{"frozen":true}');
    expect(await db.getLevelDefinition(8), isNull);

    // 下一主关卡（level_history 最大主关卡 +1）
    expect(await db.getNextMainLevel(), 8);
    await db.addLevelHistory(
      levelNumber: 1000001,
      xpGained: 1,
      idiomsUsed: const [],
    );
    expect(await db.getNextMainLevel(), 8); // 每日号段不参与

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
    expect(version.data.values.first, 10);

    await db.close();
    await tmpDir.delete(recursive: true);
  });

  test('列已存在但版本号落后时迁移仍成功（幂等修复）', () async {
    // 模拟用户设备上的历史库：player_progress_table 已含连胜两列，
    // 但 PRAGMA user_version 仍为 8。旧代码会重复 ALTER TABLE 而崩溃。
    final tmpDir = await Directory.systemTemp.createTemp('idiom_db_dupe_test');
    final tmpDb = File('${tmpDir.path}/test.db');
    await File('assets/data/idiom_crossword.db').copy(tmpDb.path);

    final conn = sqlite.sqlite3.open(tmpDb.path);
    conn.execute('PRAGMA user_version = 8');
    conn.execute(
      'ALTER TABLE player_progress_table '
      'ADD COLUMN current_correct_streak INTEGER NOT NULL DEFAULT 0',
    );
    conn.execute(
      'ALTER TABLE player_progress_table '
      'ADD COLUMN best_correct_streak INTEGER NOT NULL DEFAULT 0',
    );
    conn.close();

    final db = AppDatabase(NativeDatabase(tmpDb));
    // 迁移应跳过重复列，正常写入连胜与积分
    await db.updatePlayerProgress(
      level: 1,
      totalXp: 10,
      completedLevels: 1,
      hintCards: 0,
      reviveCards: 0,
      currentCorrectStreak: 3,
      bestCorrectStreak: 5,
    );
    final progress = await db.getPlayerProgress();
    expect(progress, isNotNull);
    expect(progress!.currentCorrectStreak, 3);
    expect(progress.bestCorrectStreak, 5);
    expect(progress.points, 0);

    final version = await db.customSelect('PRAGMA user_version').getSingle();
    expect(version.data.values.first, 10);

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
      errorsMade: 1,
      correctStreak: 3,
      totalFills: 7,
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
    expect(restoredState.errorsMade, 1);
    expect(restoredState.correctStreak, 3);
    expect(restoredState.focusCol, 2);
    expect(restoredState.direction, engine.Direction.vertical);

    expect(decodeLevel('not json'), isNull);
    expect(decodeGameState('not json'), isNull);
  });

  test('v5 数据库可正常升级到当前版本（onUpgrade 迁移）', () async {
    final tmpDir = await Directory.systemTemp.createTemp('idiom_migrate');
    final tmpDb = File('${tmpDir.path}/migrate.db');
    await File('assets/data/idiom_crossword.db').copy(tmpDb.path);

    // 模拟 v5 状态：移除 settings_table、level_json 列，并把 user_version 置为 5
    final conn = sqlite.sqlite3.open(tmpDb.path);
    conn.execute('DROP TABLE settings_table');
    conn.execute('ALTER TABLE level_history DROP COLUMN level_json');
    conn.execute('PRAGMA user_version = 5');
    conn.close();

    final db = AppDatabase(NativeDatabase(tmpDb));
    expect(await db.getSetting('sound_enabled'), isNull);
    await db.setSetting('sound_enabled', 'true');
    expect(await db.getSetting('sound_enabled'), 'true');
    await db.close();
    await tmpDir.delete(recursive: true);
  });

  test('schema v8：totalFills 列可写入读取', () async {
    final db = await _memoryDb(); // 含画蛇添足一条
    addTearDown(db.close);
    final id = await db.findIdiomIdByWord('画蛇添足');
    await db.addLevelHistory(
      levelNumber: 3,
      xpGained: 20,
      idiomsUsed: [id!],
      errorsMade: 1,
      totalFills: 5,
    );
    final history = await db.getLevelHistory();
    expect(history.single.totalFills, 5);
  });

  test('schema v9：跨关卡连胜列可写入读取', () async {
    final db = await _memoryDb();
    addTearDown(db.close);
    await db.updatePlayerProgress(
      level: 1,
      totalXp: 10,
      completedLevels: 1,
      hintCards: 0,
      reviveCards: 0,
      currentCorrectStreak: 7,
      bestCorrectStreak: 12,
    );
    final progress = await db.getPlayerProgress();
    expect(progress, isNotNull);
    expect(progress!.currentCorrectStreak, 7);
    expect(progress.bestCorrectStreak, 12);
  });

  test('Lv20 后三区混排仍可生成关卡', () async {
    final tmpDir = await Directory.systemTemp.createTemp('idiom_global_db');
    final tmpDb = File('${tmpDir.path}/test.db');
    await File('assets/data/idiom_crossword.db').copy(tmpDb.path);
    final db = AppDatabase(NativeDatabase(tmpDb));
    addTearDown(db.close);
    addTearDown(() => tmpDir.delete(recursive: true));

    engine.CrosswordLevel? level;
    for (var attempt = 0; attempt < 3 && level == null; attempt++) {
      level = await generateLevel(
        db,
        20001,
        globalRange: true,
        maxAttempts: 80,
      );
    }
    expect(level, isNotNull, reason: 'Lv20 后的全局难度关卡应能生成');
    expect(level!.levelId, 20001);
    expect(
      level.idioms.every((i) => i.difficulty >= 1 && i.difficulty <= 50),
      isTrue,
    );
  });

  test('getIdiomAtOffset：空库返回 null，非空按偏移取', () async {
    final db = await _memoryDb(); // 含画蛇添足一条
    addTearDown(db.close);
    final first = await db.getIdiomAtOffset(0);
    expect(first, isNotNull);
    expect(first!.word, '画蛇添足');
    final same = await db.getIdiomAtOffset(5); // 循环取模
    expect(same!.word, '画蛇添足');
  });
}

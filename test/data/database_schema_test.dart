import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';

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
    );
    expect(await db.isLevelCompleted(7), isTrue);
    expect(await db.getCompletedLevelNumbers(), contains(7));

    // 装饰
    expect(await db.getOwnedDecorationIds(), isEmpty);
    await db.addDecoration('grid_skin', 'bamboo');
    expect(await db.getOwnedDecorationIds(), contains('grid_skin_bamboo'));

    await db.close();
    await tmpDir.delete(recursive: true);
  });
}

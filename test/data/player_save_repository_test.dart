import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/player_save_repository.dart';

Future<AppDatabase> _databaseWithIdiom() async {
  final db = AppDatabase(NativeDatabase.memory());
  await db
      .into(db.idioms)
      .insert(
        IdiomsCompanion(
          id: const Value(1),
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
  test('用户存档完整往返，并排除头像与当前装饰选择', () async {
    final source = await _databaseWithIdiom();
    final restored = await _databaseWithIdiom();
    addTearDown(source.close);
    addTearDown(restored.close);

    await source.updatePlayerProgress(
      level: 8,
      totalXp: 2345,
      completedLevels: 7,
      hintCards: 12,
      reviveCards: 4,
      currentCorrectStreak: 6,
      bestCorrectStreak: 19,
      points: 321,
    );
    await source.addToCollection(1);
    await source.addToFavorites(1);
    await source.addLevelHistory(
      levelNumber: 7,
      xpGained: 80,
      idiomsUsed: const [1],
      timeSpentMs: 12000,
      hintsUsed: 1,
      errorsMade: 2,
      totalFills: 10,
      levelJson: '{"level":7}',
    );
    await source.addDecoration('grid_skin', 'gold');
    await source.addDecoration('avatar_frame', 'wusha');
    await source.addDecoration('background', 'palace');
    await source.setActiveDecoration('grid_skin', 'gold');
    await source.saveLevelState(
      levelNumber: 8,
      levelJson: '{"level":8}',
      stateJson: '{"answers":["画"]}',
    );
    await source.unlockAchievement('level_5');
    await source.setSetting('daily_login_streak', '4');
    await source.setSetting('custom_avatar_path', '/local/avatar.jpg');
    await source.setSetting('active_background', 'palace');

    final snapshot = await PlayerSaveRepository.exportSnapshot(source);
    await PlayerSaveRepository.importJson(restored, jsonEncode(snapshot));

    final progress = await restored.getPlayerProgress();
    expect(progress?.level, 8);
    expect(progress?.totalXp, 2345);
    expect(progress?.points, 321);
    expect(progress?.hintCards, 12);
    expect(progress?.reviveCards, 4);
    expect(await restored.getCompletedLevelNumbers(), {7});
    expect(await restored.getCollection(), [1]);
    expect(await restored.getFavoriteIds(), [1]);
    expect(await restored.getOwnedDecorationIds(), {
      'grid_skin_gold',
      'avatar_frame_wusha',
      'background_palace',
    });
    expect(await restored.getActiveDecorationId('grid_skin'), isNull);
    expect((await restored.getLevelState(8))?.stateJson, contains('画'));
    expect(await restored.getUnlockedAchievementIds(), {'level_5'});
    expect(await restored.getSetting('daily_login_streak'), '4');
    expect(await restored.getSetting('custom_avatar_path'), isNull);
    expect(await restored.getSetting('active_background'), isNull);
    expect(await PlayerSaveRepository.isLocalSaveEmpty(restored), isFalse);
  });

  test('拒绝未知版本，且不写入半份存档', () async {
    final db = await _databaseWithIdiom();
    addTearDown(db.close);

    await expectLater(
      PlayerSaveRepository.importJson(
        db,
        jsonEncode({'formatVersion': 99, 'tables': {}}),
      ),
      throwsFormatException,
    );
    expect(await PlayerSaveRepository.isLocalSaveEmpty(db), isTrue);
  });
}

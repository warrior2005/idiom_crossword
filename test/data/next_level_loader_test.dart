import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/mainline_exposure.dart';
import 'package:idiom_crossword/src/state/level_state_codec.dart';
import 'package:idiom_crossword/src/state/next_level_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('后台生成完整题面和候选盘，不记录曝光、通关或积分，并复用存档', () async {
    final dir = await Directory.systemTemp.createTemp('next_level_');
    final file = await File(
      'assets/data/idiom_crossword.db',
    ).copy('${dir.path}/test.db');
    final db = AppDatabase(NativeDatabase.createInBackground(file));
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    final before = await db.getPlayerProgress();
    final exposureBefore = await MainlineExposure.read(db);
    final level = await loadNextLevelInBackground(db, 2);
    expect(level, isNotNull);
    expect(level!.levelId, 2);
    expect(level.initialCandidates, isNotEmpty);
    expect(await db.isLevelCompleted(2), isFalse);
    expect(await db.getLevelState(2), isNull);
    expect((await db.getPlayerProgress())?.points, before?.points);
    expect((await db.getPlayerProgress())?.totalXp, before?.totalXp);
    expect(await MainlineExposure.read(db), exposureBefore);

    await db.saveLevelState(
      levelNumber: 2,
      levelJson: encodeLevel(level),
      stateJson: '{}',
    );
    final restored = await loadNextLevelInBackground(db, 2);
    expect(encodeLevel(restored!), encodeLevel(level));
  });
}

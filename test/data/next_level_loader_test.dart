import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/mainline_exposure.dart';
import 'package:idiom_crossword/src/state/level_state_codec.dart';
import 'package:idiom_crossword/src/state/next_level_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('空题库后台生成失败时不保存无效题面', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await loadNextLevelInBackground(db, 1), isNull);
    expect(await db.getLevelState(1), isNull);
  });

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
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final loader = container.read(nextLevelLoaderProvider);
    final loading = loader(2);
    expect(loader(2), same(loading));
    final level = await loading;
    expect(level, isNotNull);
    expect(level!.levelId, 2);
    expect(level.initialCandidates, isNotEmpty);
    expect(await db.isLevelCompleted(2), isFalse);
    final prepared = await db.getLevelState(2);
    expect(prepared, isNotNull);
    expect(prepared!.stateJson, isEmpty);
    // 其他入口、新的 Provider 容器都复用未作答题面。
    final reopened = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(reopened.dispose);
    expect(
      encodeLevel((await reopened.read(nextLevelLoaderProvider)(2))!),
      encodeLevel(level),
    );
    expect(
      encodeLevel((await loadOrGenerateLevel(db, 2))!),
      encodeLevel(level),
    );
    expect((await db.getPlayerProgress())?.points, before?.points);
    expect((await db.getPlayerProgress())?.totalXp, before?.totalXp);
    expect(await MainlineExposure.read(db), exposureBefore);

    await db.saveLevelState(
      levelNumber: 2,
      levelJson: encodeLevel(level),
      stateJson: encodeGameState(
        SavedGameState(
          answers: {(1, 1): '十'},
          usedCandidateSlots: {(0, 0)},
          fillHistory: [],
          cellToCandidateSlot: {(1, 1): (0, 0)},
          candidateBoard: level.initialCandidates!,
          hintUsesThisLevel: 0,
          errorsMade: 0,
          correctStreak: 1,
          totalFills: 1,
        ),
      ),
    );
    final restored = await loadNextLevelInBackground(db, 2);
    expect(encodeLevel(restored!), encodeLevel(level));
    expect(decodeGameState((await db.getLevelState(2))!.stateJson)!.answers, {
      (1, 1): '十',
    });
  });
}

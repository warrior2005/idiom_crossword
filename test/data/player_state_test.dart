import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/growth_manager.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/state/player_state.dart';

/// 玩家成长流程集成测试：通关/升级/奖励/持久化
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('通关获得经验并持久化', () async {
    final notifier = container.read(playerProvider.notifier);
    expect(container.read(playerProvider).level, 1);

    final result = await notifier.completeLevel(1, [5, 5, 5, 5, 5]); // 教学关 10xp
    expect(result.xpGained, 10);
    expect(result.leveledUp, isFalse);

    final state = container.read(playerProvider);
    expect(state.totalXp, 10);
    expect(state.completedLevels, 1);

    final progress = await db.getPlayerProgress();
    expect(progress, isNotNull);
    expect(progress!.totalXp, 10);
    expect(progress.completedLevels, 1);
  });

  test('升级发放功能奖励并持久化', () async {
    final notifier = container.read(playerProvider.notifier);
    // 10 个教学关 → 100xp → 升到 2 级（奖励提示卡×2）
    ExperienceResult? last;
    for (var i = 0; i < 10; i++) {
      last = await notifier.completeLevel(1, [5, 5, 5, 5, 5]);
    }
    expect(last!.leveledUp, isTrue);
    expect(last.newLevel, 2);

    final state = container.read(playerProvider);
    expect(state.level, 2);
    expect(state.title, '生员');
    expect(state.functionalItems['hint_card'], 2);

    final progress = await db.getPlayerProgress();
    expect(progress!.level, 2);
    expect(progress.hintCards, 2);
  });

  test('装饰奖励写入数据库', () async {
    final notifier = container.read(playerProvider.notifier);
    // 26 个教学关 → 260xp → 3 级（奖励网格皮肤·竹简）
    for (var i = 0; i < 26; i++) {
      await notifier.completeLevel(1, [5, 5, 5, 5, 5]);
    }
    final state = container.read(playerProvider);
    expect(state.level, 3);
    expect(state.ownedDecorations, contains('grid_skin_bamboo'));
    expect(await db.getOwnedDecorationIds(), contains('grid_skin_bamboo'));
  });

  test('用提示卡扣减并持久化，不会扣成负数', () async {
    final notifier = container.read(playerProvider.notifier);
    for (var i = 0; i < 10; i++) {
      await notifier.completeLevel(1, [5, 5, 5, 5, 5]);
    }
    expect(container.read(playerProvider).functionalItems['hint_card'], 2);

    await notifier.useHintCard();
    expect(container.read(playerProvider).functionalItems['hint_card'], 1);
    expect((await db.getPlayerProgress())!.hintCards, 1);

    await notifier.useHintCard();
    await notifier.useHintCard();
    await notifier.useHintCard(); // 已用完，不应变负
    expect(container.read(playerProvider).functionalItems['hint_card'], 0);
    expect((await db.getPlayerProgress())!.hintCards, 0);
  });
}

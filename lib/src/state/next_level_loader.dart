import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../engine/grid_engine.dart';
import 'database_provider.dart';
import 'level_generation.dart';
import 'level_state_codec.dart';
import 'player_state.dart';

/// 所有页面共享生成中的请求，避免首页与游戏页重复生成同一关。
final nextLevelLoaderProvider = Provider<Future<CrosswordLevel?> Function(int)>(
  (ref) {
    final db = ref.watch(databaseProvider);
    final pending = <int, Future<CrosswordLevel?>>{};
    return (number) => pending.putIfAbsent(number, () async {
      try {
        return await loadNextLevelInBackground(db, number);
      } finally {
        pending.remove(number);
      }
    });
  },
);

/// 首页常驻于各个 Tab 下，进度变化后自动预备尚未完成的主线关卡。
final preparedMainLevelProvider = FutureProvider<CrosswordLevel?>((ref) async {
  final number = ref.watch(
    nextMainLevelProvider.select((value) => value.value),
  );
  if (number == null) return null;
  return ref.watch(nextLevelLoaderProvider)(number);
});

/// 存档可直接读取；只有缺少题面时才启动后台 isolate。
Future<CrosswordLevel?> loadNextLevelInBackground(
  AppDatabase db,
  int number,
) async {
  final saved = await loadExistingLevel(db, number);
  if (saved != null) return saved;
  final level = await db.computeWithDatabase(
    connect: AppDatabase.new,
    computation: _backgroundGeneration(number),
  );
  if (level == null) return null;
  return db.transaction(() async {
    // 生成期间可能恢复了云存档或已有玩家作答，绝不覆盖已有进度。
    final existing = await loadExistingLevel(db, number);
    if (existing != null) return existing;
    await db.saveLevelState(
      levelNumber: number,
      levelJson: encodeLevel(level),
      // 空状态表示仅有预生成题面，尚未开始作答，不显示“继续”。
      stateJson: '',
    );
    return level;
  });
}

// 独立作用域只捕获编号，避免把持有数据库的事务闭包一并发送到 isolate。
Future<CrosswordLevel?> Function(AppDatabase) _backgroundGeneration(
  int number,
) =>
    (db) => loadOrGenerateLevel(db, number);

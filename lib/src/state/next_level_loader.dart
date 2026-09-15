import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../engine/grid_engine.dart';
import 'database_provider.dart';
import 'level_generation.dart';

final nextLevelLoaderProvider = Provider<Future<CrosswordLevel?> Function(int)>(
  (ref) {
    final db = ref.watch(databaseProvider);
    return (number) => loadNextLevelInBackground(db, number);
  },
);

/// 复用数据库连接，在独立 isolate 中生成题面和候选盘，避免阻塞游戏绘制。
Future<CrosswordLevel?> loadNextLevelInBackground(AppDatabase db, int number) =>
    db.computeWithDatabase(
      connect: AppDatabase.new,
      computation: (backgroundDb) => loadOrGenerateLevel(backgroundDb, number),
    );

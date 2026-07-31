import 'dart:math';

import '../data/database.dart';
import '../engine/crossing_graph.dart';
import '../engine/grid_engine.dart' as engine;
import '../engine/integrated_generator.dart';
import '../engine/spiral_difficulty.dart';
import 'level_state_codec.dart';

/// 每日挑战专用关卡号段起点（1000000+epochDay，与普通关卡区分）
const int dailyLevelOffset = 1000000;

/// 今日每日挑战关卡号
int dailyLevelNumber([DateTime? now]) {
  final day = (now ?? DateTime.now())
      .toUtc()
      .difference(DateTime.utc(1970))
      .inDays;
  return dailyLevelOffset + day;
}

/// 距 1970 的天数（每日挑战种子）
int epochDay([DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().difference(DateTime.utc(1970)).inDays;

/// 按关卡编号生成一关（首页/关卡选择共用）
///
/// 难度区间在螺旋基准上放宽 ±2，先取 300 条候选成语再交给
/// IntegratedGenerator 生成，失败返回 null。
Future<engine.CrosswordLevel?> generateLevel(
  AppDatabase db,
  int levelNumber, {
  int maxAttempts = 50,
  int? seed,
  int? targetSize,
  (int, int)? difficultyRange,
  String? title,
}) async {
  final (minD, maxD) = difficultyRange ?? _spiralRange(levelNumber);

  final dbIdioms = await db.findIdiomsByDifficulty(
    minD,
    maxD,
    300,
    randomOrder: seed == null,
  );
  if (dbIdioms.length < 5) return null;

  final engineIdioms = dbIdioms
      .map(
        (i) => engine.Idiom(
          text: i.word,
          pinyin: i.pinyin,
          meaning: i.explanation,
          difficulty: i.difficulty,
          source: i.derivation ?? '',
        ),
      )
      .toList();

  final graph = CrossingGraph(idioms: engineIdioms);
  final generator = IntegratedGenerator(
    graph: graph,
    random: seed == null ? null : Random(seed),
  );
  if (targetSize != null) {
    final level = generator.generate(
      targetSize: targetSize,
      minDifficulty: minD,
      maxDifficulty: maxD,
      maxAttempts: maxAttempts,
      levelNumber: levelNumber,
    );
    return level == null || title == null
        ? level
        : engine.CrosswordLevel(
            levelId: level.levelId,
            grid: level.grid,
            placements: level.placements,
            givenCharacters: level.givenCharacters,
            title: title,
            storyHint: level.storyHint,
          );
  }
  return generator.generateSpiral(
    levelNumber: levelNumber,
    maxAttempts: maxAttempts,
  );
}

/// 螺旋基准难度放宽 ±2，并覆盖长尾/预览区间的取数范围
(int, int) _spiralRange(int levelNumber) {
  final spiral = SpiralDifficulty.calculate(levelNumber);
  final tailMin = spiral.tailMin <= 0 ? spiral.mainMin : spiral.tailMin;
  final previewMax = spiral.previewMax <= 0
      ? spiral.mainMax
      : spiral.previewMax;
  return ((tailMin - 2).clamp(1, 50), (previewMax + 2).clamp(1, 50));
}

/// 进入关卡：优先恢复未完成存档，没有存档才新生成
Future<engine.CrosswordLevel?> loadOrGenerateLevel(
  AppDatabase db,
  int levelNumber,
) async {
  final saved = await db.getLevelState(levelNumber);
  if (saved != null) {
    final restored = decodeLevel(saved.levelJson);
    if (restored != null) return restored;
  }
  return generateLevel(db, levelNumber);
}

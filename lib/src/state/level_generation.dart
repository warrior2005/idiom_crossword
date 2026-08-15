import 'dart:math';

import '../data/database.dart';
import '../engine/crossing_graph.dart';
import '../engine/grid_engine.dart' as engine;
import '../engine/integrated_generator.dart';
import '../engine/spiral_difficulty.dart';
import '../engine/global_difficulty.dart';
import 'level_state_codec.dart';

/// 每日挑战专用关卡号段起点（1000000+epochDay，与普通关卡区分）
const int dailyLevelOffset = 1000000;

/// 普通关卡不重复使用最近这些关卡出现过的成语。
const int recentLevelExclusionCount = 3;

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
  bool globalRange = false,
  int playerLevel = 1,
}) async {
  final (minD, maxD) = globalRange
      ? (1, 50)
      : difficultyRange ?? _spiralRange(levelNumber);
  final excludedIds =
      seed == null && levelNumber > 0 && levelNumber < dailyLevelOffset
      ? await db.getRecentlyUsedMainIdiomIds(recentLevelExclusionCount)
      : const <int>{};

  if (globalRange && targetSize == null) {
    return _generateGlobalLevel(
      db,
      levelNumber,
      maxAttempts: maxAttempts,
      seed: seed,
      title: title,
      excludedIds: excludedIds,
    );
  }

  final needsLargeCandidatePool = targetSize != null
      ? targetSize >= 10
      : levelNumber > 5 && playerLevel >= 10;
  final candidateLimit = needsLargeCandidatePool ? 600 : 300;
  final dbIdioms = await db.findIdiomsByDifficulty(
    minD,
    maxD,
    candidateLimit,
    randomOrder: seed == null,
  );
  if (dbIdioms.length < 5) return null;

  final engineIdioms = dbIdioms
      .where((i) => !excludedIds.contains(i.id))
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
    playerLevel: playerLevel,
    maxAttempts: maxAttempts,
  );
}

/// Lv.20 后：按“波浪中心 + 三区混排”从各难度区取词生成
Future<engine.CrosswordLevel?> _generateGlobalLevel(
  AppDatabase db,
  int levelNumber, {
  required int maxAttempts,
  int? seed,
  String? title,
  required Set<int> excludedIds,
}) async {
  final global = GlobalDifficulty.calculate(
    levelNumber,
    random: seed == null ? null : Random(seed),
  );
  final zones = [
    (global.mainMin, global.mainMax, global.mainCount * 20),
    (global.reviewMin, global.reviewMax, global.reviewCount * 20),
    (global.sprintMin, global.sprintMax, global.sprintCount * 20),
    (global.surpriseMin, global.surpriseMax, global.surpriseCount * 25),
  ];

  final byWord = <String, Idiom>{};
  for (final (minD, maxD, limit) in zones) {
    if (minD <= 0 || maxD < minD) continue;
    final rows = await db.findIdiomsByDifficulty(
      minD,
      maxD,
      limit,
      randomOrder: seed == null,
    );
    for (final row in rows) {
      if (excludedIds.contains(row.id)) continue;
      byWord.putIfAbsent(row.word, () => row);
    }
  }
  if (byWord.length < 5) return null;

  final engineIdioms = byWord.values
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
  final level = generator.generate(
    targetSize: global.targetSize,
    minDifficulty: 1,
    maxDifficulty: 50,
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
  int levelNumber, {
  bool globalRange = false,
  int playerLevel = 1,
}) async {
  // 1) 未完成存档优先（断点续玩）
  final saved = await db.getLevelState(levelNumber);
  if (saved != null) {
    final restored = decodeLevel(saved.levelJson);
    if (restored != null) return restored;
  }
  // 2) 已通关关卡使用冻结定义（保证每次进入同一题）
  final frozen = await db.getLevelDefinition(levelNumber);
  if (frozen != null) {
    final restored = decodeLevel(frozen);
    if (restored != null) return restored;
  }
  // 3) 否则新生成
  return generateLevel(
    db,
    levelNumber,
    globalRange: globalRange,
    playerLevel: playerLevel,
  );
}

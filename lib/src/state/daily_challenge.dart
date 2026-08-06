import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../engine/spiral_difficulty.dart';
import 'database_provider.dart';
import 'level_generation.dart';
import 'player_state.dart';

/// 今日每日挑战展示信息（确定性生成）
class DailyInfo {
  final String word;
  final int idiomCount;
  final int avgDifficulty;
  final int durationSeconds;
  final String meaning;

  const DailyInfo({
    required this.word,
    required this.idiomCount,
    required this.avgDifficulty,
    required this.durationSeconds,
    required this.meaning,
  });
}

final dailyInfoProvider = FutureProvider<DailyInfo?>((ref) async {
  final db = ref.watch(databaseProvider);
  final player = ref.watch(playerProvider);
  final spiral = SpiralDifficulty.calculate(player.completedLevels + 1);
  final minD = (spiral.mainMin + 2).clamp(1, 50);
  final maxD = (spiral.mainMax + 6).clamp(1, 50);
  final level = await generateLevel(
    db,
    dailyLevelNumber(),
    seed: epochDay(),
    targetSize: 6,
    difficultyRange: (minD, maxD),
    title: '每日挑战',
  );
  if (level == null || level.placements.isEmpty) return null;
  final idioms = level.placements.map((p) => p.idiom).toList();
  final avg =
      (idioms.map((i) => i.difficulty).reduce((a, b) => a + b) / idioms.length)
          .round();
  return DailyInfo(
    word: idioms.first.text,
    idiomCount: idioms.length,
    avgDifficulty: avg,
    durationSeconds: idioms.length * 45,
    meaning: idioms.first.meaning,
  );
});

final dailyDoneProvider = FutureProvider<bool>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  return db.isLevelCompleted(dailyLevelNumber());
});

/// 当前每日挑战期数：按本机已完成的不同日期顺延；
/// 已完成的今天仍显示本期，未完成时显示下一期。
final dailyIssueProvider = FutureProvider<int>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  final history = await db.getLevelHistory();
  final doneDays = history
      .where((h) => h.levelNumber >= dailyLevelOffset)
      .map((h) => h.levelNumber)
      .toSet();
  final today = dailyLevelNumber();
  final completedToday = doneDays.contains(today);
  return doneDays.length + (completedToday ? 0 : 1);
});

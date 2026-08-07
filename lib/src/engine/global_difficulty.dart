import 'dart:math';

/// Lv.20 后的全局难度三区混排参数
class GlobalDifficultyResult {
  final int center;
  final int mainMin;
  final int mainMax;
  final int reviewMin;
  final int reviewMax;
  final int sprintMin;
  final int sprintMax;
  final int surpriseMin;
  final int surpriseMax;
  final int mainCount;
  final int reviewCount;
  final int sprintCount;
  final int surpriseCount;
  final int targetSize;

  const GlobalDifficultyResult({
    required this.center,
    required this.mainMin,
    required this.mainMax,
    required this.reviewMin,
    required this.reviewMax,
    required this.sprintMin,
    required this.sprintMax,
    required this.surpriseMin,
    required this.surpriseMax,
    required this.mainCount,
    required this.reviewCount,
    required this.sprintCount,
    required this.surpriseCount,
    required this.targetSize,
  });
}

/// Lv.20 后主线难度：难度中心在 20～40 之间缓慢波浪，三区混排。
class GlobalDifficulty {
  static GlobalDifficultyResult calculate(int levelNumber, {Random? random}) {
    final rng = random ?? Random();
    final center = (30 + 10 * sin(levelNumber / 150)).round().clamp(20, 40);

    final mainCount = 6 + rng.nextInt(3); // 6-8
    final reviewCount = 1 + rng.nextInt(2); // 1-2
    final sprintCount = 1 + rng.nextInt(2); // 1-2
    var surpriseCount = rng.nextInt(2); // 0-1

    // 总数控制在 8-12；若超出则优先去掉惊喜
    var total = mainCount + reviewCount + sprintCount + surpriseCount;
    while (total > 12 && surpriseCount > 0) {
      surpriseCount--;
      total--;
    }

    final sprintMin = min(center + 12, 46);
    final reviewMax = max(center - 12, 1);
    final mainMin = max(center - 8, reviewMax + 4);
    final mainMax = min(center + 8, sprintMin - 1);

    final surpriseIsEasy = rng.nextBool();
    return GlobalDifficultyResult(
      center: center,
      mainMin: mainMin,
      mainMax: mainMax,
      reviewMin: 1,
      reviewMax: reviewMax,
      sprintMin: sprintMin,
      sprintMax: 50,
      surpriseMin: surpriseIsEasy ? 1 : 46,
      surpriseMax: surpriseIsEasy ? 5 : 50,
      mainCount: mainCount,
      reviewCount: reviewCount,
      sprintCount: sprintCount,
      surpriseCount: surpriseCount,
      targetSize: total,
    );
  }
}

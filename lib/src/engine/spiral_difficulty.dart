import 'dart:math';

/// 螺旋难度计算器
///
/// 根据关卡编号计算该关的难度分布：
/// - baseDifficulty: 基准难度 (1-50)
/// - mainRange: 主体难度范围 (base ± 3)
/// - tailRange: 长尾难度范围 (base - 10 to base - 5)
/// - previewRange: 预览难度范围 (base + 3 to base + 5)

class SpiralDifficultyResult {
  final int baseDifficulty;
  final int mainMin;
  final int mainMax;
  final int tailMin;
  final int tailMax;
  final int previewMin;
  final int previewMax;

  const SpiralDifficultyResult({
    required this.baseDifficulty,
    required this.mainMin,
    required this.mainMax,
    required this.tailMin,
    required this.tailMax,
    required this.previewMin,
    required this.previewMax,
  });
}

class SpiralDifficulty {
  static final Random _random = Random();

  /// 近似正态分布取 [min, max] 区间内的整数（Box-Muller，中心概率更高）
  static int normalIntInRange(Random rng, int min, int max) {
    if (min >= max) return min;
    final mean = (min + max) / 2;
    final sd = (max - min + 1) / 6;
    double u1;
    do {
      u1 = rng.nextDouble();
    } while (u1 <= 1e-12);
    final u2 = rng.nextDouble();
    final z = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
    return (mean + sd * z).round().clamp(min, max);
  }

  /// 计算关卡的螺旋难度分布
  ///
  /// [levelNumber] 关卡编号 (1-based)
  static SpiralDifficultyResult calculate(int levelNumber) {
    // 基准难度 = ceil(关卡编号 / 200)，映射到 1-50
    final baseDifficulty = ((levelNumber - 1) ~/ 200 + 1).clamp(1, 50);

    // 主体范围：base ± 3
    final mainMin = (baseDifficulty - 3).clamp(1, 50);
    final mainMax = (baseDifficulty + 3).clamp(1, 50);

    // 教学关 (1-5)：无长尾/预览
    final isTeachingLevel = levelNumber <= 5;

    // 长尾范围：base - 10 to base - 5（如果 base > 5 且非教学关）
    final tailMin = (!isTeachingLevel && baseDifficulty > 5)
        ? (baseDifficulty - 10).clamp(1, 50)
        : 0;
    final tailMax = (!isTeachingLevel && baseDifficulty > 5)
        ? (baseDifficulty - 5).clamp(1, 50)
        : 0;

    // 预览范围：base + 3 to base + 5（如果 base < 45 且非教学关）
    final previewMin = (!isTeachingLevel && baseDifficulty < 45)
        ? (baseDifficulty + 3).clamp(1, 50)
        : 0;
    final previewMax = (!isTeachingLevel && baseDifficulty < 45)
        ? (baseDifficulty + 5).clamp(1, 50)
        : 0;

    return SpiralDifficultyResult(
      baseDifficulty: baseDifficulty,
      mainMin: mainMin,
      mainMax: mainMax,
      tailMin: tailMin,
      tailMax: tailMax,
      previewMin: previewMin,
      previewMax: previewMax,
    );
  }

  /// 根据螺旋难度选择成语数量
  ///
  /// [levelNumber] 关卡编号
  /// [playerLevel] 玩家科举等级
  /// 返回：(主体数量, 长尾数量, 预览数量)
  static (int mainCount, int tailCount, int previewCount) selectIdiomCounts(
    int levelNumber, {
    required int playerLevel,
    Random? random,
  }) {
    final rng = random ?? _random;
    if (levelNumber <= 5) {
      // 教学关：1-5 关主体数量递增
      return switch (levelNumber) {
        1 => (5, 0, 0),
        2 => (6, 0, 0),
        3 || 4 => (7, 0, 0),
        _ => (8, 0, 0),
      };
    }
    final level = playerLevel.clamp(1, 19);
    if (level < 5) {
      // 6 关起、Lv.5 前：8 + 0-1 + 0-1
      return (8, normalIntInRange(rng, 0, 1), normalIntInRange(rng, 0, 1));
    }
    if (level < 10) {
      // Lv.5 起、Lv.10 前：8 + 0-1 + 1-2
      return (8, normalIntInRange(rng, 0, 1), normalIntInRange(rng, 1, 2));
    }
    // Lv.10 起、Lv.20 前：7 + 1-2 + 3
    return (7, normalIntInRange(rng, 1, 2), 3);
  }
}

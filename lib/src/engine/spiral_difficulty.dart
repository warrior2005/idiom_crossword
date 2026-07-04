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
  /// 计算关卡的螺旋难度分布
  /// 
  /// [levelNumber] 关卡编号 (1-based)
  /// [totalLevels] 总关卡数 (默认 10000)
  static SpiralDifficultyResult calculate(
    int levelNumber, {
    int totalLevels = 10000,
  }) {
    // 基准难度 = ceil(关卡编号 / 200)，映射到 1-50
    final baseDifficulty = ((levelNumber - 1) ~/ 200 + 1).clamp(1, 50);
    
    // 主体范围：base ± 3
    final mainMin = (baseDifficulty - 3).clamp(1, 50);
    final mainMax = (baseDifficulty + 3).clamp(1, 50);
    
    // 教学关 (1-5)：无长尾/预览
    final isTeachingLevel = levelNumber <= 5;

    // 长尾范围：base - 10 to base - 5（如果 base > 5 且非教学关）
    final tailMin = (!isTeachingLevel && baseDifficulty > 5) ? (baseDifficulty - 10).clamp(1, 50) : 0;
    final tailMax = (!isTeachingLevel && baseDifficulty > 5) ? (baseDifficulty - 5).clamp(1, 50) : 0;
    
    // 预览范围：base + 3 to base + 5（如果 base < 45 且非教学关）
    final previewMin = (!isTeachingLevel && baseDifficulty < 45) ? (baseDifficulty + 3).clamp(1, 50) : 0;
    final previewMax = (!isTeachingLevel && baseDifficulty < 45) ? (baseDifficulty + 5).clamp(1, 50) : 0;
    
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
  /// 返回：(主体数量, 长尾数量, 预览数量)
  static (int mainCount, int tailCount, int previewCount) selectIdiomCounts(
    int levelNumber,
  ) {
    if (levelNumber <= 5) {
      // 教学关：固定 5 条
      return (5, 0, 0);
    } else if (levelNumber <= 200) {
      // 过渡关：6 条
      return (5, 1, 0);
    } else {
      // 正式关：8-12 条（7-9 主体 + 1-2 长尾 + 0-1 预览）
      final random = DateTime.now().microsecondsSinceEpoch;
      final mainCount = 7 + (random % 3); // 7-9
      final tailCount = 1 + (random % 2); // 1-2
      final previewCount = random % 2; // 0-1
      return (mainCount, tailCount, previewCount);
    }
  }
}

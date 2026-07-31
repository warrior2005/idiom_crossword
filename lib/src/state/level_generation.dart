import '../data/database.dart';
import '../engine/crossing_graph.dart';
import '../engine/grid_engine.dart' as engine;
import '../engine/integrated_generator.dart';
import '../engine/spiral_difficulty.dart';
import 'level_state_codec.dart';

/// 按关卡编号生成一关（首页/关卡选择共用）
///
/// 难度区间在螺旋基准上放宽 ±2，先取 300 条候选成语再交给
/// IntegratedGenerator 生成，失败返回 null。
Future<engine.CrosswordLevel?> generateLevel(
  AppDatabase db,
  int levelNumber, {
  int maxAttempts = 50,
}) async {
  final spiral = SpiralDifficulty.calculate(levelNumber);
  final minD = (spiral.mainMin - 2).clamp(1, 50);
  final maxD = (spiral.mainMax + 2).clamp(1, 50);

  final dbIdioms = await db.findIdiomsByDifficulty(minD, maxD, 300);
  if (dbIdioms.length < 5) return null;

  final engineIdioms = dbIdioms.map((i) => engine.Idiom(
        text: i.word,
        pinyin: i.pinyin,
        meaning: i.explanation,
        difficulty: i.difficulty,
        source: i.derivation ?? '',
      )).toList();

  final graph = CrossingGraph(idioms: engineIdioms);
  return IntegratedGenerator(graph: graph)
      .generateSpiral(levelNumber: levelNumber, maxAttempts: maxAttempts);
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

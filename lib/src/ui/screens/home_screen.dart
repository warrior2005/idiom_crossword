import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';
import '../../state/database_provider.dart';
import 'game_screen.dart';
import 'collection_screen.dart';
import 'shop_screen.dart';
import '../../engine/integrated_generator.dart';
import '../../engine/crossing_graph.dart';
import '../../engine/spiral_difficulty.dart';
import '../../engine/grid_engine.dart' as engine;

/// 首页
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 标题
              Text(
                '成语填字',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '交叉推理，智慧填字',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.brown.shade600,
                ),
              ),
              const SizedBox(height: 40),

              // 等级显示
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.brown.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Lv.${player.level} ${player.title}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.brown.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '经验: ${player.totalXp}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.brown.shade500,
                ),
              ),
              const SizedBox(height: 40),

              // 开始游戏按钮
              _MenuButton(
                icon: Icons.play_arrow_rounded,
                label: '开始游戏',
                onTap: () => _startGame(context, ref),
              ),
              const SizedBox(height: 16),

              // 收藏按钮
              _MenuButton(
                icon: Icons.collections_bookmark,
                label: '成语收藏',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CollectionScreen()),
                ),
              ),
              const SizedBox(height: 16),

              // 商城按钮
              _MenuButton(
                icon: Icons.store,
                label: '商城',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShopScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startGame(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在生成关卡...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final db = ref.read(databaseProvider);
      final player = ref.read(playerProvider);
      final nextLevel = player.completedLevels + 1;

      final spiral = SpiralDifficulty.calculate(nextLevel);
      final minD = (spiral.mainMin - 2).clamp(1, 50);
      final maxD = (spiral.mainMax + 2).clamp(1, 50);

      final dbIdioms = await db.findIdiomsByDifficulty(minD, maxD, 300);
      if (dbIdioms.length < 5) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('数据库中没有足够的成语')),
          );
        }
        return;
      }

      final engineIdioms = dbIdioms.map((i) => engine.Idiom(
        text: i.word,
        pinyin: i.pinyin,
        meaning: i.explanation,
        difficulty: i.difficulty,
        source: i.derivation ?? '',
      )).toList();

      final graph = CrossingGraph(idioms: engineIdioms);
      final generator = IntegratedGenerator(graph: graph);
      final level = generator.generateSpiral(levelNumber: nextLevel);

      if (context.mounted) {
        Navigator.pop(context);

        if (level != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GameScreen(level: level),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('关卡生成失败，请重试')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('错误: $e')),
        );
      }
    }
  }
}

/// 菜单按钮
class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.brown.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}

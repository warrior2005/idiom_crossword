import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';
import 'game_screen.dart';
import 'collection_screen.dart';
import 'shop_screen.dart';
import '../../engine/integrated_generator.dart';
import '../../engine/crossing_graph.dart';
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
    // 显示加载对话框
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
      // 使用示例成语数据（Web 测试用）
      final sampleIdioms = const [
        engine.Idiom(text: '一鸣惊人', meaning: '比喻平时默默无闻，突然做出惊人的成绩', difficulty: 5),
        engine.Idiom(text: '人山人海', meaning: '形容聚集的人非常多', difficulty: 3),
        engine.Idiom(text: '海阔天空', meaning: '形容大自然的广阔，也比喻想象或说话毫无拘束', difficulty: 4),
        engine.Idiom(text: '空前绝后', meaning: '从前没有过，今后也不会再有', difficulty: 6),
        engine.Idiom(text: '后发制人', meaning: '等对方先动手，再抓住有利时机反击', difficulty: 7),
        engine.Idiom(text: '画蛇添足', meaning: '比喻做了多余的事，反而把事情弄坏了', difficulty: 2),
        engine.Idiom(text: '足智多谋', meaning: '形容善于料事和用计', difficulty: 5),
        engine.Idiom(text: '谋事在人', meaning: '按自己的意愿去谋划', difficulty: 8),
        engine.Idiom(text: '天长地久', meaning: '形容时间长久', difficulty: 3),
        engine.Idiom(text: '九牛一毛', meaning: '比喻极大数量中微不足道的一部分', difficulty: 4),
        engine.Idiom(text: '马到成功', meaning: '形容工作刚开始就取得成功', difficulty: 2),
        engine.Idiom(text: '功成名就', meaning: '功业建立了，名声也有了', difficulty: 6),
        engine.Idiom(text: '名落孙山', meaning: '指考试或选拔没有被录取', difficulty: 5),
        engine.Idiom(text: '山穷水尽', meaning: '比喻无路可走陷入绝境', difficulty: 4),
        engine.Idiom(text: '尽心尽力', meaning: '用尽全部心思和力量', difficulty: 3),
      ];

      // 构建交叉图
      final graph = CrossingGraph(idioms: sampleIdioms);

      // 生成关卡
      final generator = IntegratedGenerator(graph: graph);
      final level = generator.generate(
        targetSize: 5,
        minDifficulty: 1,
        maxDifficulty: 10,
      );

      if (context.mounted) {
        Navigator.pop(context); // 关闭加载对话框

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

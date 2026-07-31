import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';
import '../../state/database_provider.dart';
import '../../state/level_generation.dart';
import 'game_screen.dart';
import 'collection_screen.dart';
import 'shop_screen.dart';
import 'level_select_screen.dart';
import 'stats_screen.dart';
import '../widgets/level_loading_dialog.dart';

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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

              // 每日挑战按钮
              _MenuButton(
                icon: Icons.calendar_today,
                label: '每日挑战',
                onTap: () => _startDaily(context, ref),
              ),
              const SizedBox(height: 16),

              // 开始游戏按钮
              _MenuButton(
                icon: Icons.play_arrow_rounded,
                label: '开始游戏',
                onTap: () => _startGame(context, ref),
              ),
              const SizedBox(height: 16),

              // 关卡选择按钮
              _MenuButton(
                icon: Icons.grid_view_rounded,
                label: '选择关卡',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
                ),
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
              const SizedBox(height: 16),

              // 统计按钮
              _MenuButton(
                icon: Icons.insert_chart_outlined,
                label: '统计',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatsScreen()),
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startGame(BuildContext context, WidgetRef ref) async {
    showLevelLoadingDialog(context);

    try {
      final db = ref.read(databaseProvider);
      final player = ref.read(playerProvider);
      final nextLevel = player.completedLevels + 1;
      final level = await loadOrGenerateLevel(db, nextLevel);

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

  /// 每日挑战：全服同题（按日期种子确定性生成），完成后次日刷新
  Future<void> _startDaily(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final levelNumber = dailyLevelNumber();

    if (await db.isLevelCompleted(levelNumber)) {
      if (context.mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('今日挑战已完成'),
            content: const Text('明天再来挑战新的关卡吧！'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('好的'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    showLevelLoadingDialog(context);
    try {
      final level = await generateLevel(
        db,
        levelNumber,
        seed: epochDay(),
        targetSize: 6,
        difficultyRange: (10, 40),
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      if (level == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('每日挑战生成失败，请重试')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameScreen(level: level)),
      );
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

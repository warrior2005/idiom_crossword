import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/database_provider.dart';
import '../../state/level_generation.dart';
import '../../state/player_state.dart';
import '../widgets/level_loading_dialog.dart';
import 'game_screen.dart';

/// 已通关关卡集合（通关记录变化时自动刷新）
final completedLevelsProvider = FutureProvider<Set<int>>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  return db.getCompletedLevelNumbers();
});

/// 当前正在进行的关卡（下一个主关卡）
final nextMainLevelProvider = FutureProvider<int>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  return db.getNextMainLevel();
});

/// 关卡选择：分页展示完成状态，点击进入对应关卡
class LevelSelectScreen extends ConsumerStatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  ConsumerState<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends ConsumerState<LevelSelectScreen> {
  @override
  Widget build(BuildContext context) {
    final completedAsync = ref.watch(completedLevelsProvider);
    final nextLevelAsync = ref.watch(nextMainLevelProvider);
    final completed = completedAsync.value ?? const <int>{};
    final nextLevel = nextLevelAsync.value ?? 1;
    // 只展示已完成关卡与当前正在进行的关卡（后续未开启关卡不展示）
    final levels = ({...completed, nextLevel}).toList()..sort();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('选择关卡'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: completedAsync.isLoading || nextLevelAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 10,
                            mainAxisSpacing: 6,
                            crossAxisSpacing: 6,
                          ),
                      itemCount: levels.length,
                      itemBuilder: (context, index) {
                        final level = levels[index];
                        return _LevelCell(
                          levelNumber: level,
                          isCompleted: completed.contains(level),
                          isNext: level == nextLevel,
                          onTap: () => _startLevel(level),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startLevel(int levelNumber) async {
    showLevelLoadingDialog(context);
    try {
      final db = ref.read(databaseProvider);
      final level = await loadOrGenerateLevel(db, levelNumber);
      if (!mounted) return;
      Navigator.pop(context); // 关闭加载框
      if (level == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('关卡生成失败，请重试')));
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameScreen(level: level)),
      );
      ref.invalidate(completedLevelsProvider);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('错误: $e')));
      }
    }
  }
}

/// 单个关卡格子
class _LevelCell extends StatelessWidget {
  final int levelNumber;
  final bool isCompleted;
  final bool isNext;
  final VoidCallback? onTap;

  const _LevelCell({
    required this.levelNumber,
    required this.isCompleted,
    required this.isNext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;

    if (isCompleted) {
      bg = const Color(0xFFC8E6C9);
      fg = Colors.green.shade800;
    } else if (isNext) {
      bg = Colors.brown.shade200;
      fg = Colors.brown.shade900;
    } else {
      bg = const Color(0xFFFFF8F0);
      fg = Colors.brown.shade700;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Center(
          child: Text(
            '$levelNumber',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}

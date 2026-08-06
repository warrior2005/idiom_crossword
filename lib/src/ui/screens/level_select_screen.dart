import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/database_provider.dart';
import '../../state/level_generation.dart';
import '../../state/player_state.dart';
import 'game_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/app_seal.dart';
import '../widgets/badge_soft.dart';
import '../widgets/level_loading_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// 已通关关卡集合
final completedLevelsProvider = FutureProvider<Set<int>>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  return db.getCompletedLevelNumbers();
});

/// 下一个主关卡
final nextMainLevelProvider = FutureProvider<int>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  return db.getNextMainLevel();
});

class LevelSelectScreen extends ConsumerStatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  ConsumerState<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends ConsumerState<LevelSelectScreen> {
  static const _pageSize = 24;
  int _page = 0;
  bool _pageInitialized = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(nextMainLevelProvider, (prev, next) {
      if (next.hasValue && !_pageInitialized) {
        _pageInitialized = true;
        _page = (next.value! - 1) ~/ _pageSize;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final completedAsync = ref.watch(completedLevelsProvider);
    final nextLevelAsync = ref.watch(nextMainLevelProvider);
    final completed = completedAsync.value ?? const <int>{};
    final nextLevel = nextLevelAsync.value ?? 1;
    final allLevels = ({...completed, nextLevel}).toList()..sort();
    // 只展示到当前关卡所在页
    final currentPage = ((nextLevel - 1) ~/ _pageSize).clamp(0, 100000);
    final totalPages = currentPage + 1;
    final page = _page.clamp(0, currentPage);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('选择关卡', style: displayStyle(size: 30, weight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('由浅入深 · 每关约 8–12 条成语', style: kickerStyle()),
                  const SizedBox(height: 12),
                  _DailyPin(onTap: () => _startDaily()),
                ],
              ),
            ),
            Expanded(
              child: completedAsync.isLoading || nextLevelAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '第 ${page * _pageSize + 1}-${((page + 1) * _pageSize).clamp(0, allLevels.length)} 关 · '
                            '${page + 1}/$totalPages',
                            style: bodyStyle(size: 12, color: AppColors.muted),
                          ),
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: PageController(initialPage: page),
                            onPageChanged: (p) => setState(() => _page = p),
                            itemCount: totalPages,
                            itemBuilder: (context, pageIndex) {
                              final start = pageIndex * _pageSize;
                              final pageLevels = allLevels.sublist(
                                start,
                                (start + _pageSize).clamp(0, allLevels.length),
                              );
                              return GridView.count(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                                crossAxisCount: 4,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                children: [
                                  for (final level in pageLevels)
                                    _LevelNode(
                                      levelNumber: level,
                                      isCompleted: completed.contains(level),
                                      isNext: level == nextLevel,
                                      onTap: () => _startLevel(level),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
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
      Navigator.pop(context);
      if (level == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('关卡生成失败，请重试')));
        return;
      }
      await Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(level: level)));
      ref.invalidate(completedLevelsProvider);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('错误: $e')));
      }
    }
  }

  void _startDaily() {
    // 跳到每日挑战：简化——返回上一页（首页可开始每日挑战）
    Navigator.of(context).pop();
  }
}

/// 每日挑战置顶卡
class _DailyPin extends StatelessWidget {
  final VoidCallback onTap;
  const _DailyPin({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const AppSeal('日', size: 52, fontSize: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('每日挑战 · 今日一题', style: displayStyle(size: 18, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('全服同题 · 明日刷新', style: bodyStyle(size: 12, color: AppColors.muted)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: BadgeSoft('挑战'),
          ),
        ],
      ),
    );
  }
}

/// 关卡节点（三态）
class _LevelNode extends StatelessWidget {
  final int levelNumber;
  final bool isCompleted;
  final bool isNext;
  final VoidCallback? onTap;

  const _LevelNode({
    required this.levelNumber,
    required this.isCompleted,
    required this.isNext,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isNext
                  ? AppColors.accent
                  : isCompleted
                  ? AppColors.accentSoft
                  : AppColors.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isNext || isCompleted ? AppColors.accent : AppColors.border,
              ),
              boxShadow: isNext
                  ? const [BoxShadow(color: Color(0x52B33B27), blurRadius: 14, offset: Offset(0, 6))]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$levelNumber',
                  style: displayStyle(
                    size: 20,
                    weight: FontWeight.w700,
                    color: isNext
                        ? const Color(0xFFFFF6EC)
                        : isCompleted
                        ? AppColors.accentDeep
                        : AppColors.faint,
                  ),
                ),
              ],
            ),
          ),
          if (isCompleted)
            Positioned(
              right: -7,
              top: -7,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Transform.rotate(
                  angle: 6 * 3.14159 / 180,
                  child: const Text(
                    '通',
                    style: TextStyle(
                      fontFamily: kSerif,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFF6EC),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

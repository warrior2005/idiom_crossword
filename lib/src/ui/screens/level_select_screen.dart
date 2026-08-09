import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/database_provider.dart';
import '../../state/level_generation.dart';
import '../../state/daily_challenge.dart';
import '../../state/level_progress_providers.dart';
import '../../state/player_state.dart';
import '../../data/growth_manager.dart';
import '../../engine/spiral_difficulty.dart';
import 'game_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/app_seal.dart';
import '../widgets/badge_soft.dart';
import '../widgets/banner_ad_view.dart';
import '../widgets/level_loading_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class LevelSelectScreen extends ConsumerStatefulWidget {
  final bool bannerActive;

  const LevelSelectScreen({super.key, this.bannerActive = true});

  @override
  ConsumerState<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends ConsumerState<LevelSelectScreen> {
  static const _pageSize = 20;
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
    final wordsAsync = ref.watch(levelWordsProvider);
    final dailyDone = ref.watch(dailyDoneProvider).value ?? false;
    final dailyUnlocked = GrowthManager.canAccessDaily(
      ref.watch(playerProvider).level,
    );
    final completed = completedAsync.value ?? const <int>{};
    final nextLevel = nextLevelAsync.value ?? 1;
    final levelWords = wordsAsync.value ?? const <int, String>{};
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
                  Text(
                    '选择关卡',
                    style: displayStyle(size: 30, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text('由浅入深 · 每关 5–12 条成语', style: kickerStyle()),
                  const SizedBox(height: 12),
                  if (!dailyDone)
                    _DailyPin(onTap: _startDaily, locked: !dailyUnlocked),
                ],
              ),
            ),
            Expanded(
              child:
                  completedAsync.isLoading ||
                      nextLevelAsync.isLoading ||
                      wordsAsync.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '第 ${page * _pageSize + 1}-${(page + 1) * _pageSize} 关 · '
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
                              final start = pageIndex * _pageSize + 1;
                              return GridView.builder(
                                clipBehavior: Clip.none,
                                padding: const EdgeInsets.fromLTRB(
                                  28,
                                  12,
                                  28,
                                  12,
                                ),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                      childAspectRatio: 1,
                                    ),
                                itemCount: _pageSize,
                                itemBuilder: (context, index) {
                                  final level = start + index;
                                  return _LevelNode(
                                    levelNumber: level,
                                    word: levelWords[level],
                                    isCompleted: completed.contains(level),
                                    isNext: level == nextLevel,
                                    onTap: level > nextLevel
                                        ? null
                                        : () => _startLevel(level),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        BannerAdView(active: widget.bannerActive),
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
      final level = await loadOrGenerateLevel(
        db,
        levelNumber,
        globalRange: ref.read(playerProvider).level >= 20,
        playerLevel: ref.read(playerProvider).level,
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (level == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('关卡生成失败，请重试')));
        return;
      }
      final isReplay = await db.isLevelCompleted(levelNumber);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(level: level, noReward: isReplay),
        ),
      );
      ref.invalidate(completedLevelsProvider);
      ref.invalidate(levelWordsProvider);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('错误: $e')));
      }
    }
  }

  Future<void> _startDaily() async {
    if (!GrowthManager.canAccessDaily(ref.read(playerProvider).level)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('到达Lv.3·廪生后开启每日挑战')));
      }
      return;
    }
    final db = ref.read(databaseProvider);
    final levelNumber = dailyLevelNumber();

    if (await db.isLevelCompleted(levelNumber)) {
      ref.invalidate(dailyDoneProvider);
      return;
    }

    if (!mounted) return;
    showLevelLoadingDialog(context);
    try {
      final spiral = SpiralDifficulty.calculate(
        ref.read(playerProvider).completedLevels + 1,
      );
      final minD = (spiral.mainMin + 5).clamp(10, 50);
      final maxD = (spiral.mainMax + 5).clamp(10, 50);
      final level = await generateLevel(
        db,
        levelNumber,
        seed: epochDay(),
        targetSize: 12,
        difficultyRange: (minD, maxD),
        title: '每日挑战',
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (level == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('每日挑战生成失败，请重试')));
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameScreen(level: level)),
      );
      ref.invalidate(dailyDoneProvider);
      ref.invalidate(dailyIssueProvider);
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

/// 每日挑战置顶卡
class _DailyPin extends StatelessWidget {
  final VoidCallback onTap;
  final bool locked;
  const _DailyPin({required this.onTap, this.locked = false});

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
                Text(
                  '每日挑战 · 今日一题',
                  style: displayStyle(size: 18, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '全服同题 · 明日刷新',
                  style: bodyStyle(size: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: BadgeSoft(locked ? 'Lv.3 开启' : '挑战'),
          ),
        ],
      ),
    );
  }
}

/// 关卡节点（三态）
class _LevelNode extends StatelessWidget {
  final int levelNumber;
  final String? word;
  final bool isCompleted;
  final bool isNext;
  final VoidCallback? onTap;

  const _LevelNode({
    required this.levelNumber,
    this.word,
    required this.isCompleted,
    required this.isNext,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Container(
            key: ValueKey('level-node-$levelNumber'),
            decoration: BoxDecoration(
              color: isNext
                  ? AppColors.accent
                  : isCompleted
                  ? AppColors.accentSoft
                  : AppColors.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isNext || isCompleted
                    ? AppColors.accent
                    : AppColors.border,
              ),
              boxShadow: isNext
                  ? const [
                      BoxShadow(
                        color: Color(0x52B33B27),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$levelNumber',
                  style: displayStyle(
                    size: 24,
                    weight: FontWeight.w700,
                    color: isNext
                        ? const Color(0xFFFFF6EC)
                        : isCompleted
                        ? AppColors.accentDeep
                        : AppColors.faint,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  word ?? '??',
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isNext
                        ? const Color(0xFFFFF6EC).withValues(alpha: 0.82)
                        : isCompleted
                        ? AppColors.muted
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

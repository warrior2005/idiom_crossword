import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/database_provider.dart';
import '../../state/level_generation.dart';
import '../../state/level_state_codec.dart';
import '../../state/daily_challenge.dart';
import '../../state/player_state.dart';
import '../../engine/spiral_difficulty.dart';
import 'game_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/app_seal.dart';
import '../widgets/section_title.dart';
import '../widgets/sub_page_header.dart';
import '../widgets/vertical_word.dart';
import '../widgets/primary_button.dart';
import '../widgets/level_loading_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// 历期每日挑战（解码 levelJson 取成语；期数按本机完成顺序编号）
class PastDaily {
  final int issue;
  final List<String> idioms;
  const PastDaily({required this.issue, required this.idioms});
}

final pastDailyProvider = FutureProvider<List<PastDaily>>((ref) async {
  final db = ref.watch(databaseProvider);
  final history = await db.getLevelHistory();
  final past = history.where((h) => h.levelNumber >= dailyLevelOffset).toList()
    ..sort((a, b) => a.levelNumber.compareTo(b.levelNumber));
  final result = <PastDaily>[];
  for (var i = 0; i < past.length; i++) {
    final h = past[i];
    List<String> idioms = const [];
    if (h.levelJson != null) {
      final level = decodeLevel(h.levelJson!);
      if (level != null) {
        idioms = level.placements.map((p) => p.idiom.text).toList();
      }
    }
    result.add(PastDaily(issue: i + 1, idioms: idioms));
  }
  return result.reversed.toList();
});

/// 每日挑战
class DailyReviewScreen extends ConsumerStatefulWidget {
  const DailyReviewScreen({super.key});

  @override
  ConsumerState<DailyReviewScreen> createState() => _DailyReviewScreenState();
}

class _DailyReviewScreenState extends ConsumerState<DailyReviewScreen> {
  static const _pageSize = 10;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final daily = ref.watch(dailyInfoProvider).value;
    final dailyDone = ref.watch(dailyDoneProvider).value ?? false;
    final dailyIssue = ref.watch(dailyIssueProvider).value ?? 1;
    final pastAsync = ref.watch(pastDailyProvider);
    final past = pastAsync.value ?? const [];

    final pageCount = past.isEmpty
        ? 1
        : (past.length + _pageSize - 1) ~/ _pageSize;
    final page = _page.clamp(0, pageCount - 1);
    final pagePast = past.skip(page * _pageSize).take(_pageSize).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: SubPageHeader(title: '每日挑战'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  _buildHero(daily, dailyDone, dailyIssue),
                  if (daily != null)
                    AppCard(
                      padding: const EdgeInsets.all(18),
                      margin: const EdgeInsets.only(top: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          VerticalWord(word: daily.word),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              daily.meaning,
                              style: bodyStyle(
                                size: 12.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SectionTitle(title: '历期回顾'),
                  if (past.isEmpty)
                    AppCard(
                      child: Text(
                        '还没有历史每日挑战',
                        style: bodyStyle(color: AppColors.muted),
                      ),
                    )
                  else ...[
                    for (final p in pagePast)
                      AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 96,
                              child: Text(
                                p.idioms.isNotEmpty
                                    ? p.idioms.first
                                    : '第 ${p.issue} 期',
                                style: displayStyle(
                                  size: 24,
                                  weight: FontWeight.w900,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                p.idioms.join(' · '),
                                style: bodyStyle(
                                  size: 13,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                            Text(
                              '· 第 ${p.issue} 期',
                              style: bodyStyle(
                                size: 11,
                                color: AppColors.faint,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (pageCount > 1) _buildPagination(page, pageCount),
            _buildBottomBar(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(DailyInfo? daily, bool dailyDone, int dailyIssue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF6E9DA), Color(0xFFEDD6BF)],
        ),
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const AppSeal('日', size: 56, fontSize: 16),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第 $dailyIssue 期 · ${daily?.word ?? '——'}',
                  style: displayStyle(
                    size: 19,
                    weight: FontWeight.w900,
                    color: AppColors.accentDeep,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  daily == null
                      ? '今日谜面生成中…'
                      : dailyDone
                      ? '全服同题 · 已完成 · 明日刷新'
                      : '全服同题 · 明日刷新',
                  style: bodyStyle(size: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination(int page, int pageCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
            child: const Text('上一页'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '第 ${page + 1}/$pageCount 页',
              style: bodyStyle(size: 12, color: AppColors.muted),
            ),
          ),
          TextButton(
            onPressed: page < pageCount - 1
                ? () => setState(() => _page = page + 1)
                : null,
            child: const Text('下一页'),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryButton(
            label: '重玩今日挑战',
            small: true,
            ghost: true,
            onTap: () => _startDaily(ref),
          ),
          const SizedBox(height: 6),
          const Text(
            '次日 0 点刷新',
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.faint,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startDaily(WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final levelNumber = dailyLevelNumber();
    final isReplay = await db.isLevelCompleted(levelNumber);
    if (!mounted) return;
    showLevelLoadingDialog(context);
    try {
      final spiral = SpiralDifficulty.calculate(
        ref.read(playerProvider).completedLevels + 1,
      );
      final minD = (spiral.mainMin + 2).clamp(1, 50);
      final maxD = (spiral.mainMax + 6).clamp(1, 50);
      final level = await generateLevel(
        db,
        levelNumber,
        seed: epochDay(),
        targetSize: 6,
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
        MaterialPageRoute(
          builder: (_) => GameScreen(level: level, noReward: isReplay),
        ),
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

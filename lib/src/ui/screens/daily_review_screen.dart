import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/database_provider.dart';
import '../../state/level_generation.dart';
import '../../state/level_state_codec.dart';
import '../../state/daily_challenge.dart';
import '../widgets/app_card.dart';
import '../widgets/app_seal.dart';
import '../widgets/section_title.dart';
import '../widgets/sub_page_header.dart';
import '../widgets/vertical_word.dart';
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

/// 每日回顾
class DailyReviewScreen extends ConsumerWidget {
  const DailyReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daily = ref.watch(dailyInfoProvider).value;
    final dailyIssue = ref.watch(dailyIssueProvider).value ?? 1;
    final pastAsync = ref.watch(pastDailyProvider);
    final past = pastAsync.value ?? const [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: SubPageHeader(title: '每日回顾'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(20),
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
                                daily == null ? '今日谜面生成中…' : '全服同题 · 明日刷新',
                                style: bodyStyle(
                                  size: 11.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
                  else
                    for (final p in past)
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
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      '次日 0 点刷新',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.faint,
                        letterSpacing: 0.6,
                      ),
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
}

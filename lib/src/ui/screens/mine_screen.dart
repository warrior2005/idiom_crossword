import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';
import '../../data/growth_manager.dart';
import '../../data/achievement_manager.dart';
import 'achievements_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/section_title.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class MineScreen extends ConsumerWidget {
  const MineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final statsAsync = ref.watch(statsProvider);
    final unlockedAsync = ref.watch(achievementsProvider);
    final titles = GrowthManager.titleSequence;
    final nextTitle = player.level < titles.length
        ? titles[player.level] // index = level（0 起），即下一级
        : titles.last;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            Text('我的', style: displayStyle(size: 30, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            // 头像卡
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF2E2A20), Color(0xFF191610)],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x284050A0),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '士',
                      style: TextStyle(
                        fontFamily: kSerif,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE8C87A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lv.${player.level} · ${player.title}',
                          style: displayStyle(
                            size: 21,
                            weight: FontWeight.w900,
                            color: AppColors.accentDeep,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '已获 ${player.completedLevels} 关 · ${player.totalXp} 经验',
                          style: bodyStyle(size: 12.5, color: AppColors.muted),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '再通关一关，晋升「$nextTitle」',
                          style: bodyStyle(size: 11.5, color: AppColors.faint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _RankStrip(player: player, titles: titles),
            const SizedBox(height: 4),
            const SectionTitle(title: '学问一览'),
            _buildStats(context, ref),
            const SectionTitle(title: '更多'),
            _MenuRow(
              iconName: 'trophy',
              title: '成就',
              hint:
                  '已获 ${unlockedAsync.value?.length ?? 0} / ${achievementDefs.length}',
              onTap: () => _push(context, const AchievementsScreen()),
            ),
            _MenuRow(
              iconName: 'chart',
              title: '统计',
              hint: _accuracyHint(statsAsync.value),
              onTap: () => _push(context, const StatsScreen()),
            ),
            _MenuRow(
              iconName: 'gear',
              title: '设置',
              onTap: () => _push(context, const SettingsScreen()),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '科举仕途 · 20 级 · 位极人臣',
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
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Widget _buildStats(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final stats = statsAsync.value;
    final items = [
      (icon: 'list', value: '${stats?.totalCompleted ?? 0}', label: '累计通关'),
      (icon: 'book', value: '${stats?.collectionCount ?? 0}', label: '成语收藏'),
      (icon: 'bolt', value: '${stats?.longestStreak ?? 0}', label: '最长连胜'),
      (icon: 'clock', value: _fmt(stats?.avgTimeMs ?? 0), label: '平均用时'),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 88,
      ),
      itemBuilder: (context, index) {
        final it = items[index];
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _IconBox(
                iconName: it.icon,
                bg: AppColors.accentPale,
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    it.value,
                    style: displayStyle(size: 22, weight: FontWeight.w900),
                  ),
                  Text(
                    it.label,
                    style: bodyStyle(size: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmt(int ms) {
    if (ms <= 0) return '—';
    final seconds = (ms / 1000).round();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '$m′$s″' : '$s″';
  }

  String _accuracyHint(PlayerStats? stats) {
    final accuracy = stats?.accuracy;
    return accuracy == null ? '正确率 —' : '正确率 ${(accuracy * 100).round()}%';
  }
}

/// 科举等级条：已完成 + 当前 + 下一级
class _RankStrip extends StatelessWidget {
  final PlayerState player;
  final List<String> titles;

  const _RankStrip({required this.player, required this.titles});

  @override
  Widget build(BuildContext context) {
    // 展示：1..level 已完成，level 当前，level+1 下一级（≤20）
    final end = (player.level + 1).clamp(1, titles.length);
    return SizedBox(
      height: 78,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: end,
        itemBuilder: (context, i) {
          final lv = i + 1;
          final isCurrent = lv == player.level;
          final isDone = lv < player.level;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 74,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppColors.accent
                        : isDone
                        ? AppColors.accentSoft
                        : AppColors.surface,
                    border: Border.all(
                      color: isCurrent || isDone
                          ? AppColors.accent
                          : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Lv$lv',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isCurrent
                              ? const Color(0xFFBFD0D0).withValues(alpha: 0.85)
                              : AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        titles[i],
                        style: displayStyle(
                          size: 13.5,
                          weight: FontWeight.w700,
                          color: isCurrent
                              ? const Color(0xFFFFF6EC)
                              : AppColors.fg,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Positioned(
                    top: -8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.accent),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          '当前',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final String iconName;
  final Color bg;
  final Color color;

  const _IconBox({
    required this.iconName,
    required this.bg,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Center(child: AppIcon(iconName, size: 20, color: color)),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final String iconName;
  final String title;
  final String? hint;
  final VoidCallback onTap;

  const _MenuRow({
    required this.iconName,
    required this.title,
    this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            _IconBox(
              iconName: iconName,
              bg: AppColors.surface2,
              color: AppColors.fg,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: bodyStyle(size: 15, weight: FontWeight.w600),
              ),
            ),
            if (hint != null)
              Text(hint!, style: bodyStyle(size: 11, color: AppColors.muted)),
            const SizedBox(width: 6),
            Transform.rotate(
              angle: 3.14159,
              child: AppIcon('back', size: 14, color: AppColors.faint),
            ),
          ],
        ),
      ),
    );
  }
}

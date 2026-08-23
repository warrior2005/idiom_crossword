import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../app_page_route.dart';
import '../../state/player_state.dart';
import '../../data/growth_manager.dart';
import '../../data/achievement_manager.dart';
import 'achievements_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/section_title.dart';
import '../widgets/decorated_seal.dart';
import '../widgets/user_avatar.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/decoration_catalog.dart';

class MineScreen extends ConsumerWidget {
  const MineScreen({super.key});

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    final current = ref.read(playerProvider);
    final hasCustom =
        current.customAvatarPath != null &&
        current.customAvatarPath!.isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.accent,
              ),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(sheetContext, 'pick'),
            ),
            if (hasCustom)
              ListTile(
                leading: const Icon(Icons.restart_alt, color: AppColors.accent),
                title: const Text('取消自定义头像'),
                onTap: () => Navigator.pop(sheetContext, 'clear'),
              ),
            ListTile(
              leading: const Icon(Icons.close, color: AppColors.muted),
              title: const Text('关闭'),
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'clear') {
      await ref.read(playerProvider.notifier).clearCustomAvatar();
      return;
    }
    if (action != 'pick') return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
    if (picked == null || !context.mounted) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final ext = p.extension(picked.path).isEmpty
          ? '.jpg'
          : p.extension(picked.path);
      final target = p.join(
        dir.path,
        'custom_avatar_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
      await File(picked.path).copy(target);
      if (!context.mounted) return;
      await ref.read(playerProvider.notifier).setCustomAvatar(target);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('头像设置失败，请重试')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final avatarSeal = GrowthManager.avatarSeal(player.level);
    final nextMainLevel =
        ref.watch(nextMainLevelProvider).value ?? player.completedLevels + 1;
    final statsAsync = ref.watch(statsProvider);
    final unlockedAsync = ref.watch(achievementsProvider);
    final titles = GrowthManager.titleSequence;
    final nextTitle = player.level < titles.length
        ? titles[player.level] // index = level（0 起），即下一级
        : titles.last;
    final levelsToNextTitle = GrowthManager.levelsToNextTitle(
      xpRemaining: player.xpRemaining,
      nextMainLevel: nextMainLevel,
    );

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            Text('我的', style: displayStyle(size: 30, weight: FontWeight.w700)),
            const SizedBox(height: 30),
            // 头像卡
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // 背景水印：当前印章（士/官/卿/相/公/龙）
                  Positioned(
                    right: -6,
                    top: 4,
                    child: Text(
                      avatarSeal,
                      style: displayStyle(
                        size: 76,
                        weight: FontWeight.w900,
                        color: AppColors.accent.withValues(alpha: 0.10),
                        height: 1.0,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => _pickAvatar(context, ref),
                        child: DecoratedSeal(
                          frameId: player.activeAvatarFrame,
                          child: UserAvatar(
                            seal: avatarSeal,
                            customAvatarPath: player.customAvatarPath,
                            size: 76,
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 36),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${GrowthManager.levelLabel(player.level)} · ${player.title}',
                              style: applyTitleEffect(
                                player.activeTitleEffect,
                                displayStyle(
                                  size: 21,
                                  weight: FontWeight.w900,
                                  color: AppColors.accentDeep,
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '已通 ${player.completedLevels} 关 · ${player.totalXp} 经验',
                              style: bodyStyle(
                                size: 12.5,
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              player.level >= titles.length
                                  ? '已达最高等级「$nextTitle」'
                                  : '差 $levelsToNextTitle 关，晋升「$nextTitle」',
                              style: bodyStyle(
                                size: 11.5,
                                color: AppColors.faint,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
              hint: unlockedAsync.when(
                data: (unlocked) =>
                    '已获 ${unlocked.length} / ${achievementDefs.length}',
                loading: () => '读取本地成就…',
                error: (_, _) => '本地成就暂不可用',
              ),
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
                '科举仕途·步步高升·正位宸极',
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
    Navigator.of(context).push(AppPageRoute<void>(builder: (_) => page));
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
    // 展示：已达成节点 + 下一节点；若下一节点不是 Lv20，则在 Lv∞ 前补“···”
    final normalEnd = player.level >= 20 ? 20 : player.level + 1;
    final children = <Widget>[];
    for (var lv = 1; lv <= normalEnd; lv++) {
      children.add(_rankNode(lv: lv, title: titles[lv - 1]));
    }
    if (player.level < 20) {
      children.add(_ellipsisNode());
    }
    children.add(_rankNode(lv: 21, title: titles[20], infinity: true));

    return SizedBox(
      height: 78,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: children,
      ),
    );
  }

  Widget _rankNode({
    required int lv,
    required String title,
    bool infinity = false,
  }) {
    final isCurrent = lv == player.level;
    final isDone = lv < player.level;
    final label = infinity ? 'Lv∞' : 'Lv$lv';
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 74,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
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
                  label,
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
                  title,
                  style: displayStyle(
                    size: 13.5,
                    weight: FontWeight.w700,
                    color: isCurrent ? const Color(0xFFFFF6EC) : AppColors.fg,
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
  }

  Widget _ellipsisNode() {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        width: 48,
        alignment: Alignment.center,
        child: Text(
          '···',
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: bodyStyle(size: 16, color: AppColors.faint),
        ),
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

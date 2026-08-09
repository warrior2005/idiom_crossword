import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';
import '../../state/database_provider.dart';
import '../../state/level_generation.dart';
import '../../state/daily_challenge.dart';
import '../../data/growth_manager.dart';
import '../../data/database.dart';
import '../../engine/spiral_difficulty.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'collection_screen.dart';
import 'mine_screen.dart';
import 'daily_review_screen.dart';
import 'settings_screen.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/badge_soft.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_title.dart';
import '../widgets/xp_track.dart';
import '../widgets/level_loading_dialog.dart';
import '../widgets/lunar_date_label.dart';
import '../widgets/vertical_word.dart';
import '../widgets/decorated_seal.dart';
import '../widgets/user_avatar.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/decoration_catalog.dart';

/// 今日一读：按日期确定性取一条成语
final todayIdiomProvider = FutureProvider<Idiom?>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getIdiomAtOffset(epochDay());
});

class HomeScreen extends ConsumerWidget {
  /// 跨 Tab 切换回调（RootScreen 注入）；为空时退回 push（单屏测试用）
  final ValueChanged<int>? onSwitchTab;

  const HomeScreen({super.key, this.onSwitchTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final avatarSeal = GrowthManager.avatarSeal(player.level);
    final daily = ref.watch(dailyInfoProvider).value;
    final dailyDone = ref.watch(dailyDoneProvider).value ?? false;
    final dailyIssue = ref.watch(dailyIssueProvider).value ?? 1;
    final nextMainLevel = ref.watch(nextMainLevelProvider).value;
    final nextTitle = player.level >= GrowthManager.maxLevel
        ? ''
        : GrowthManager.titleForLevel(player.level + 1);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            // 头部
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LunarDateLabel(),
                      const SizedBox(height: 6),
                      Text(
                        '成语填字',
                        style: displayStyle(size: 30, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsetsGeometry.only(right: 20),
                  child: GestureDetector(
                    onTap: () => _switchToMineTab(context),
                    child: DecoratedSeal(
                      frameId: player.activeAvatarFrame,
                      child: UserAvatar(
                        seal: avatarSeal,
                        customAvatarPath: player.customAvatarPath,
                        size: 46,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 科举仕途卡
            _RankCard(player: player, nextTitle: nextTitle),
            const SizedBox(height: 16),
            // 每日挑战卡
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '每日挑战 · 全服同题',
                              style: kickerStyle(color: AppColors.gold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              daily?.word ?? '——',
                              style: displayStyle(
                                size: 30,
                                weight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      BadgeSoft('第 $dailyIssue 期', color: BadgeSoftColor.gold),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text.rich(_dailyMeta(daily)),
                  const SizedBox(height: 10),
                  if (!GrowthManager.canAccessDaily(player.level))
                    PrimaryButton(
                      label: '到达Lv.4·贡生后开启',
                      small: true,
                      onTap: null,
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: dailyDone ? '已完成' : '开始挑战',
                            small: true,
                            onTap: dailyDone
                                ? null
                                : () => _startDaily(context, ref),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 110,
                          child: PrimaryButton(
                            label: '往期回顾',
                            small: true,
                            ghost: true,
                            onTap: () => _openDailyReview(context),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 继续第 N 关
            PrimaryButton(
              label: '继续第 ${nextMainLevel ?? '…'} 关',
              onTap: () => _startGame(context, ref),
            ),
            const SizedBox(height: 8),
            // 书卷小径
            const SectionTitle(title: '书卷小径'),
            Row(
              children: [
                Expanded(
                  child: _Tile(
                    iconName: 'levels',
                    label: '选择关卡',
                    desc: '由浅入深 · 循序渐进',
                    onTap: () => _switchTab(context, 1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Tile(
                    iconName: 'book',
                    label: '成语收藏',
                    desc: '温故知新 · 日积月累',
                    onTap: () => _switchTab(context, 2),
                  ),
                ),
              ],
            ),
            // 今日一读
            const SectionTitle(title: '今日一读'),
            const _TodayIdiom(),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                '交叉推理 · 一字双关',
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

  InlineSpan _dailyMeta(DailyInfo? daily) {
    if (daily == null) {
      return TextSpan(
        text: '今日挑战生成中…',
        style: bodyStyle(size: 12.5, color: AppColors.muted),
      );
    }
    final diffLabel = switch (daily.avgDifficulty) {
      <= 10 => '入门',
      <= 25 => '进阶',
      <= 40 => '高手',
      _ => '大师',
    };
    return TextSpan(
      children: [
        TextSpan(
          text: '难度 ',
          style: bodyStyle(size: 12.5, color: AppColors.muted),
        ),
        TextSpan(
          text: diffLabel,
          style: bodyStyle(
            size: 12.5,
            color: AppColors.fg,
            weight: FontWeight.w700,
          ),
        ),
        TextSpan(
          text:
              ' · ${daily.idiomCount} 条成语 · ${(daily.durationSeconds / 60).ceil()} 分钟'
              ' · ${GrowthManager.dailyChallengeXp} 经验',
          style: bodyStyle(size: 12.5, color: AppColors.muted),
        ),
      ],
    );
  }

  void _switchToMineTab(BuildContext context) {
    if (onSwitchTab != null) {
      onSwitchTab!(4);
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const MineScreen()));
    }
  }

  void _switchTab(BuildContext context, int tabIndex) {
    if (onSwitchTab != null) {
      onSwitchTab!(tabIndex);
    } else if (tabIndex == 1) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const LevelSelectScreen()));
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const CollectionScreen()));
    }
  }

  void _openDailyReview(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DailyReviewScreen()));
  }

  void _startGame(BuildContext context, WidgetRef ref) async {
    showLevelLoadingDialog(context);

    try {
      final db = ref.read(databaseProvider);
      final player = ref.read(playerProvider);
      final nextLevel = await db.getNextMainLevel();
      final level = await loadOrGenerateLevel(
        db,
        nextLevel,
        globalRange: player.level >= 20,
        playerLevel: player.level,
      );

      if (!context.mounted) return;
      Navigator.pop(context);

      if (level == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('关卡生成失败，请重试')));
        return;
      }

      // 首局展示一次新手引导
      final firstGame =
          player.completedLevels == 0 &&
          await db.getSetting(tutorialShownKey) != 'true';
      if (firstGame) {
        await db.setSetting(tutorialShownKey, 'true');
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('欢迎来到成语填字'),
            content: const Text(
              '1. 点击下方候选字，填入选中空格\n'
              '2. 一个字可能同时属于横、纵两个成语\n'
              '3. 交叉点同时满足两条线索才是正确解\n\n'
              '填满所有空格即可过关！',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('开始'),
              ),
            ],
          ),
        );
      }
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameScreen(level: level)),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('错误: $e')));
      }
    }
  }

  /// 每日挑战：全服同题（按日期种子确定性生成），完成后次日刷新
  Future<void> _startDaily(BuildContext context, WidgetRef ref) async {
    if (!GrowthManager.canAccessDaily(ref.read(playerProvider).level)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('到达Lv.4·贡生后开启每日挑战')));
      }
      return;
    }
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
      // 难度跟随当前关卡，并整体上移一档（+2/+6）保持"略难"
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
      if (!context.mounted) return;
      Navigator.pop(context);
      if (level == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('每日挑战生成失败，请重试')));
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameScreen(level: level)),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('错误: $e')));
      }
    }
  }
}

/// 科举仕途卡
class _RankCard extends StatelessWidget {
  final PlayerState player;
  final String nextTitle;

  const _RankCard({required this.player, required this.nextTitle});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: ClipRRect(
        child: Stack(
          children: [
            // 背景水印 Lv.X（accent 10%）
            Positioned(
              right: -6,
              top: 4,
              child: Text(
                GrowthManager.levelLabel(player.level),
                style: displayStyle(
                  size: 52,
                  weight: FontWeight.w900,
                  color: AppColors.accent.withValues(alpha: 0.10),
                  height: 1.0,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('科举仕途', style: kickerStyle()),
                const SizedBox(height: 6),
                Text(
                  '${GrowthManager.levelLabel(player.level)} · ${player.title}',
                  style: applyTitleEffect(
                    player.activeTitleEffect,
                    displayStyle(
                      size: 24,
                      weight: FontWeight.w900,
                      color: AppColors.accentDeep,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                XpTrack(progress: player.xpProgress, height: 8),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '经验 ',
                              style: bodyStyle(
                                size: 11,
                                color: AppColors.muted,
                              ),
                            ),
                            TextSpan(
                              text: _group(player.totalXp),
                              style: bodyStyle(
                                size: 11,
                                color: AppColors.fg,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (nextTitle.isEmpty)
                      Text(
                        '经验持续累计',
                        style: bodyStyle(size: 11, color: AppColors.muted),
                      )
                    else
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '离「$nextTitle」还差 ',
                              style: bodyStyle(
                                size: 11,
                                color: AppColors.muted,
                              ),
                            ),
                            TextSpan(
                              text: _group(player.xpRemaining),
                              style: bodyStyle(
                                size: 11,
                                color: AppColors.fg,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 千分位分组：1240 -> 1,240
  String _group(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }
}

/// 书卷小径 tile
class _Tile extends StatelessWidget {
  final String iconName;
  final String label;
  final String desc;
  final VoidCallback onTap;

  const _Tile({
    required this.iconName,
    required this.label,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.accentPale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: AppIcon(iconName, size: 20, color: AppColors.accent),
              ),
            ),
            const SizedBox(height: 8),
            Text(label, style: bodyStyle(size: 14.5, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(desc, style: bodyStyle(size: 11.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

/// 今日一读：竖排成语卡
class _TodayIdiom extends ConsumerWidget {
  const _TodayIdiom();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idiom = ref.watch(todayIdiomProvider).value;
    if (idiom == null) {
      return AppCard(
        child: Text('今日一读待收录…', style: bodyStyle(color: AppColors.muted)),
      );
    }
    final derivation = idiom.derivation?.trim();
    final hasDerivation =
        derivation != null &&
        derivation.isNotEmpty &&
        derivation != '无' &&
        derivation != '无。';
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          VerticalWord(word: idiom.word),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDerivation) ...[
                  Text(
                    '· $derivation',
                    style: bodyStyle(size: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  idiom.explanation,
                  style: bodyStyle(size: 12.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

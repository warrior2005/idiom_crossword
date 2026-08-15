import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/growth_manager.dart';
import '../../state/database_provider.dart';
import '../../state/leaderboard_service.dart';
import '../../state/player_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/app_card.dart';
import '../widgets/app_seal.dart';
import '../widgets/sub_page_header.dart';

final leaderboardProvider = FutureProvider.autoDispose
    .family<LeaderboardSnapshot, LeaderboardKind>((ref, kind) async {
      final db = ref.watch(databaseProvider);
      final player = ref.watch(playerProvider);
      final weeklyXp = await LeaderboardService.currentWeekXp(db);
      await LeaderboardService.submitScores(db, player.totalXp);
      return LeaderboardService.load(
        kind: kind,
        localTotalXp: player.totalXp,
        localWeeklyXp: weeklyXp,
      );
    });

/// 使用 Game Center 数据绘制的双榜页面。
class LeaderboardScreen extends ConsumerWidget {
  final int initialIndex;

  const LeaderboardScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: LeaderboardKind.values.length,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: SubPageHeader(title: '英雄榜'),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: AppCard(
                  padding: const EdgeInsets.all(4),
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.muted,
                    labelStyle: bodyStyle(size: 13, weight: FontWeight.w700),
                    tabs: [
                      for (final kind in LeaderboardKind.values)
                        Tab(text: kind.title),
                    ],
                  ),
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    _LeaderboardTab(kind: LeaderboardKind.allTime),
                    _LeaderboardTab(kind: LeaderboardKind.weekly),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardTab extends ConsumerWidget {
  final LeaderboardKind kind;

  const _LeaderboardTab({required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(leaderboardProvider(kind));
    return snapshot.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => _Failure(kind: kind),
      data: (data) {
        final containsCurrent = data.leaders.any(
          (item) => item.isCurrentPlayer,
        );
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(leaderboardProvider(kind));
            await ref.read(leaderboardProvider(kind).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              if (!data.connected)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '登录 Game Center 后查看完整排名，当前先展示本机成绩。',
                    style: bodyStyle(size: 11.5, color: AppColors.muted),
                  ),
                ),
              if (data.leaders.isEmpty)
                _LeaderboardRow(entry: data.currentPlayer, kind: kind)
              else ...[
                for (final entry in data.leaders)
                  _LeaderboardRow(entry: entry, kind: kind),
                if (!containsCurrent) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(height: 1, color: AppColors.border),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            '我的排名',
                            style: bodyStyle(size: 11, color: AppColors.muted),
                          ),
                        ),
                        Expanded(
                          child: Container(height: 1, color: AppColors.border),
                        ),
                      ],
                    ),
                  ),
                  _LeaderboardRow(entry: data.currentPlayer, kind: kind),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final LeaderboardKind kind;

  const _LeaderboardRow({required this.entry, required this.kind});

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank;
    final medal = switch (rank) {
      1 => '壹',
      2 => '贰',
      3 => '叁',
      _ => null,
    };
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: entry.isCurrentPlayer
          ? AppColors.accent.withValues(alpha: 0.1)
          : AppColors.surface,
      borderColor: entry.isCurrentPlayer
          ? AppColors.accent.withValues(alpha: 0.35)
          : AppColors.border,
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: medal == null
                ? Text(
                    rank == null ? '—' : '$rank',
                    textAlign: TextAlign.center,
                    style: bodyStyle(
                      size: 13,
                      weight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  )
                : AppSeal(medal, size: 30, fontSize: 11, vertical: false),
          ),
          const SizedBox(width: 10),
          AppSeal(
            kind == LeaderboardKind.allTime
                ? GrowthManager.avatarSeal(entry.level)
                : '周',
            size: 38,
            fontSize: 15,
            vertical: false,
            style: entry.isCurrentPlayer
                ? AppSealStyle.solid
                : AppSealStyle.hollow,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bodyStyle(size: 14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  kind == LeaderboardKind.allTime ? entry.levelLabel : '本周累计',
                  style: bodyStyle(size: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            '${_group(entry.xp)} ${kind == LeaderboardKind.allTime ? '经验' : '周经验'}',
            style: bodyStyle(
              size: 12,
              weight: FontWeight.w700,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  String _group(int value) {
    final source = value.toString();
    final result = StringBuffer();
    for (var index = 0; index < source.length; index++) {
      if (index > 0 && (source.length - index) % 3 == 0) result.write(',');
      result.write(source[index]);
    }
    return result.toString();
  }
}

class _Failure extends ConsumerWidget {
  final LeaderboardKind kind;

  const _Failure({required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: TextButton(
        onPressed: () => ref.invalidate(leaderboardProvider(kind)),
        child: const Text('加载失败，点击重试'),
      ),
    );
  }
}

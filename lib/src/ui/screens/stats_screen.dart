import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../state/database_provider.dart';
import '../../state/player_state.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/sub_page_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// 玩家统计
class PlayerStats {
  final int totalCompleted; // 主线累计通关数（不含每日挑战）
  final int totalXp; // 累计经验
  final int avgTimeMs; // 平均通关用时
  final int longestStreak; // 最长连续通关
  final int collectionCount; // 收藏成语数
  final int dailyCount; // 每日挑战完成数
  final int totalErrors; // 失误次数
  final int totalFills; // 填字尝试次数
  final int totalHints; // 使用提示次数

  const PlayerStats({
    required this.totalCompleted,
    required this.totalXp,
    required this.avgTimeMs,
    required this.longestStreak,
    required this.collectionCount,
    required this.dailyCount,
    required this.totalErrors,
    required this.totalFills,
    required this.totalHints,
  });

  /// 正确率；无填字数据返回 null
  double? get accuracy {
    if (totalFills <= 0) return null;
    return ((totalFills - totalErrors) / totalFills).clamp(0.0, 1.0);
  }
}

/// 统计面板数据（通关记录变化时自动刷新）
final statsProvider = FutureProvider<PlayerStats>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  final history = await db.getLevelHistory();

  final mainLevels =
      history
          .where((h) => h.levelNumber < 1000000) // 排除每日挑战关卡号段
          .map((h) => h.levelNumber)
          .toList()
        ..sort();

  var streak = 0;
  var bestStreak = 0;
  var prev = 0;
  for (final level in mainLevels) {
    streak = (level == prev + 1) ? streak + 1 : 1;
    if (streak > bestStreak) bestStreak = streak;
    prev = level;
  }

  final times = history
      .where((h) => h.timeSpentMs != null)
      .map((h) => h.timeSpentMs!)
      .toList();
  final totalXp = history.fold(0, (sum, h) => sum + h.xpGained);
  final dailyCount = history.where((h) => h.levelNumber >= 1000000).length;
  final totalErrors = history.fold(0, (sum, h) => sum + h.errorsMade);
  final totalHints = history.fold(0, (sum, h) => sum + h.hintsUsed);
  var totalFills = 0;
  for (final h in history) {
    if (h.totalFills != null) totalFills += h.totalFills!;
  }

  return PlayerStats(
    totalCompleted: mainLevels.length,
    totalXp: totalXp,
    avgTimeMs: times.isEmpty
        ? 0
        : times.reduce((a, b) => a + b) ~/ times.length,
    longestStreak: bestStreak,
    collectionCount: await db.getCollectionCount(),
    dailyCount: dailyCount,
    totalErrors: totalErrors,
    totalFills: totalFills,
    totalHints: totalHints,
  );
});

/// 统计面板
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: SubPageHeader(title: '统计'),
            ),
            Expanded(
              child: statsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    '加载失败: $e',
                    style: bodyStyle(color: AppColors.accent),
                  ),
                ),
                data: (stats) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    _AccuracyCard(accuracy: stats.accuracy),
                    const SizedBox(height: 14),
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          _IconBox(
                            iconName: 'bolt',
                            bg: AppColors.goldSoft,
                            color: const Color(0xFF7A5D14),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${stats.longestStreak} 关',
                                style: displayStyle(
                                  size: 22,
                                  weight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '最长连胜 · 连续通关',
                                style: bodyStyle(
                                  size: 11.5,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          _StatLine('累计通关', '${stats.totalCompleted} 关'),
                          _StatLine('累计经验', '${stats.totalXp}'),
                          _StatLine('平均用时', _formatDuration(stats.avgTimeMs)),
                          _StatLine('失误次数', '${stats.totalErrors}'),
                          _StatLine('使用提示', '${stats.totalHints} 次'),
                          _StatLine('成语收藏', '${stats.collectionCount} 则'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        '数据仅存储于本机',
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
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '—';
    final seconds = (ms / 1000).round();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '$m 分 $s 秒' : '$s 秒';
  }
}

/// 最近通关记录（升序 → 展示时倒序）
final historyProvider = FutureProvider<List<LevelHistoryData>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (await db.getLevelHistory()).reversed.toList();
});

class _AccuracyCard extends StatelessWidget {
  final double? accuracy;
  const _AccuracyCard({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: _AccuracyRingPainter(progress: accuracy ?? 0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      accuracy == null ? '—' : '${(accuracy! * 100).round()}%',
                      style: displayStyle(
                        size: 38,
                        weight: FontWeight.w900,
                        color: AppColors.accent,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      '填字正确率',
                      style: bodyStyle(size: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            accuracy == null ? '通关后生成正确率' : '含每日挑战 · 提示填入不计',
            style: bodyStyle(size: 11.5, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _AccuracyRingPainter extends CustomPainter {
  final double progress;
  _AccuracyRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 6;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..color = AppColors.surface2;
    canvas.drawCircle(center, radius, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accent;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _AccuracyRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  const _StatLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: bodyStyle(size: 13.5, color: AppColors.muted)),
          Text(value, style: bodyStyle(size: 14, weight: FontWeight.w600)),
        ],
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

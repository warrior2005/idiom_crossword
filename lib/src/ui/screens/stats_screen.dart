import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../state/database_provider.dart';
import '../../state/player_state.dart';

/// 玩家统计
class PlayerStats {
  final int totalCompleted; // 总通关数（含每日挑战）
  final int totalXp; // 累计经验
  final int avgTimeMs; // 平均通关用时
  final int totalHints; // 累计提示次数
  final int totalErrors; // 累计错误填写
  final int longestStreak; // 最长连续通关
  final int collectionCount; // 收藏成语数

  const PlayerStats({
    required this.totalCompleted,
    required this.totalXp,
    required this.avgTimeMs,
    required this.totalHints,
    required this.totalErrors,
    required this.longestStreak,
    required this.collectionCount,
  });
}

/// 统计面板数据（通关记录变化时自动刷新）
final statsProvider = FutureProvider<PlayerStats>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  final history = await db.getLevelHistory();

  final mainLevels = history
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
  final totalHints = history.fold(0, (sum, h) => sum + h.hintsUsed);
  final totalErrors = history.fold(0, (sum, h) => sum + h.errorsMade);

  return PlayerStats(
    totalCompleted: history.length,
    totalXp: totalXp,
    avgTimeMs: times.isEmpty ? 0 : times.reduce((a, b) => a + b) ~/ times.length,
    totalHints: totalHints,
    totalErrors: totalErrors,
    longestStreak: bestStreak,
    collectionCount: await db.getCollectionCount(),
  );
});

/// 统计面板
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('统计'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('加载失败: $e', style: const TextStyle(color: Colors.brown)),
        ),
        data: (stats) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(icon: Icons.emoji_events, label: '通关数', value: '${stats.totalCompleted}'),
                _StatCard(icon: Icons.stars, label: '累计经验', value: '${stats.totalXp}'),
                _StatCard(
                  icon: Icons.timer_outlined,
                  label: '平均用时',
                  value: _formatDuration(stats.avgTimeMs),
                ),
                _StatCard(icon: Icons.lightbulb_outline, label: '提示次数', value: '${stats.totalHints}'),
                _StatCard(icon: Icons.close, label: '填错次数', value: '${stats.totalErrors}'),
                _StatCard(icon: Icons.local_fire_department, label: '最长连胜', value: '${stats.longestStreak}'),
                _StatCard(icon: Icons.bookmark, label: '收藏成语', value: '${stats.collectionCount}'),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '最近通关',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.brown.shade800,
              ),
            ),
            const SizedBox(height: 8),
            historyAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (history) => Column(
                children: history
                    .take(10)
                    .map((h) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '第 ${h.levelNumber} 关',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '用时 ${_formatDuration(h.timeSpentMs ?? 0)} · '
                            '提示 ${h.hintsUsed} · 填错 ${h.errorsMade} · '
                            '+${h.xpGained} 经验',
                          ),
                        ))
                    .toList(),
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
    return m > 0 ? '$m分$s秒' : '$s秒';
  }
}

/// 最近通关记录（升序 → 展示时倒序）
final historyProvider = FutureProvider<List<LevelHistoryData>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (await db.getLevelHistory()).reversed.toList();
});

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.brown.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.brown.shade700, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.brown.shade900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.brown.shade500),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/achievement_manager.dart';
import '../../state/database_provider.dart';

/// 已解锁成就集合
final achievementsProvider = FutureProvider<Set<AchievementId>>((ref) async {
  final db = ref.watch(databaseProvider);
  final unlocked = <AchievementId>{};
  for (final s in await db.getUnlockedAchievementIds()) {
    for (final id in AchievementId.values) {
      if (id.name == s) unlocked.add(id);
    }
  }
  return unlocked;
});

/// 成就界面
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedAsync = ref.watch(achievementsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('成就'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: unlockedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('加载失败: $e', style: const TextStyle(color: Colors.brown)),
        ),
        data: (unlocked) {
          final total = achievementDefs.length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '已解锁 ${unlocked.length}/$total',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.brown.shade700,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: achievementDefs.length,
                  itemBuilder: (context, index) {
                    final def = achievementDefs[index];
                    final isUnlocked = unlocked.contains(def.id);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isUnlocked
                              ? Colors.orange.shade100
                              : Colors.brown.shade100,
                          child: Icon(
                            _iconFor(def.id),
                            color: isUnlocked
                                ? Colors.orange.shade800
                                : Colors.brown.shade300,
                          ),
                        ),
                        title: Text(
                          def.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isUnlocked
                                ? Colors.brown.shade900
                                : Colors.brown.shade400,
                          ),
                        ),
                        subtitle: Text(
                          def.description,
                          style: TextStyle(
                            color: isUnlocked
                                ? Colors.brown.shade600
                                : Colors.brown.shade300,
                          ),
                        ),
                        trailing: isUnlocked
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : const Icon(
                                Icons.lock_outline,
                                color: Colors.brown,
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _iconFor(AchievementId id) {
    return switch (id) {
      AchievementId.firstLevel => Icons.flag,
      AchievementId.level10 => Icons.looks_one_outlined,
      AchievementId.level50 => Icons.looks_two_outlined,
      AchievementId.level100 => Icons.workspace_premium,
      AchievementId.level500 => Icons.military_tech,
      AchievementId.level1000 => Icons.emoji_events,
      AchievementId.collector50 => Icons.bookmark,
      AchievementId.collector100 => Icons.collections_bookmark,
      AchievementId.collector200 => Icons.bookmarks,
      AchievementId.streak10 => Icons.flash_on,
      AchievementId.streak20 => Icons.bolt,
      AchievementId.streak30 => Icons.electric_bolt,
      AchievementId.noHint => Icons.lightbulb_outline,
      AchievementId.noHint10 => Icons.visibility_off,
      AchievementId.flawless => Icons.verified,
      AchievementId.flawless10 => Icons.verified_user,
      AchievementId.speedrun => Icons.timer,
      AchievementId.speedrun10 => Icons.timer_off_outlined,
      AchievementId.dailyChallenge => Icons.calendar_today,
      AchievementId.daily7 => Icons.event_repeat,
      AchievementId.xp100000 => Icons.auto_graph,
    };
  }
}

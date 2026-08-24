import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/achievement_manager.dart';
import '../../data/database.dart';
import '../../state/database_provider.dart';
import '../../state/game_center_service.dart';
import '../widgets/achievement_badge.dart';
import '../widgets/app_card.dart';
import '../widgets/sub_page_header.dart';
import '../widgets/xp_track.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

typedef AchievementSync = Future<void> Function(AppDatabase db);

final achievementSyncProvider = Provider<AchievementSync>(
  (ref) => GameCenterService.syncAchievements,
);

final achievementsProvider = StreamProvider<Set<AchievementId>>((ref) async* {
  final db = ref.watch(databaseProvider);
  final syncAchievements = ref.watch(achievementSyncProvider);

  yield await _loadLocalAchievements(db);
  try {
    await syncAchievements(db);
  } catch (_) {
    return;
  }
  yield await _loadLocalAchievements(db);
});

Future<Set<AchievementId>> _loadLocalAchievements(AppDatabase db) async {
  final unlocked = <AchievementId>{};
  for (final s in await db.getUnlockedAchievementIds()) {
    for (final id in AchievementId.values) {
      if (id.name == s) unlocked.add(id);
    }
  }
  return unlocked;
}

const Map<AchievementCategory, String> _groupTitles = {
  AchievementCategory.level: '通关',
  AchievementCategory.collection: '收藏',
  AchievementCategory.streak: '连击',
  AchievementCategory.skill: '技艺',
  AchievementCategory.daily: '每日',
  AchievementCategory.xp: '经验',
};

/// 成就界面
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedAsync = ref.watch(achievementsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: SubPageHeader(title: '成就'),
            ),
            Expanded(
              child: unlockedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    '加载失败: $e',
                    style: bodyStyle(color: AppColors.accent),
                  ),
                ),
                data: (unlocked) {
                  final total = achievementDefs.length;
                  final groups = <AchievementCategory, List<AchievementDef>>{};
                  for (final def in achievementDefs) {
                    groups.putIfAbsent(def.category, () => []).add(def);
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      AppCard(
                        child: Row(
                          children: [
                            Text(
                              '${unlocked.length}',
                              style: displayStyle(
                                size: 44,
                                weight: FontWeight.w900,
                                color: AppColors.accent,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '已解锁 / $total 项',
                                    style: bodyStyle(
                                      size: 12.5,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  XpTrack(
                                    progress: total == 0
                                        ? 0
                                        : unlocked.length / total,
                                    height: 10,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final entry in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 18, bottom: 10),
                          child: Row(
                            children: [
                              Text(
                                _groupTitles[entry.key]!,
                                style: displayStyle(
                                  size: 15,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: AppColors.border,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (final def in entry.value)
                          _AchRow(
                            def: def,
                            unlocked: unlocked.contains(def.id),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchRow extends StatelessWidget {
  final AchievementDef def;
  final bool unlocked;
  const _AchRow({required this.def, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          AchievementBadge(
            key: ValueKey(
              unlocked
                  ? 'achievement-image-${def.id.name}'
                  : 'achievement-locked-${def.id.name}',
            ),
            assetPath: def.assetPath,
            unlocked: unlocked,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.title,
                  style: bodyStyle(size: 14.5, weight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  def.description,
                  style: bodyStyle(size: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            unlocked ? '已获 ${def.points} 积分' : '${def.points} 积分',
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
}

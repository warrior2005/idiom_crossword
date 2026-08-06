import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/achievement_manager.dart';
import '../../state/database_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/app_seal.dart';
import '../widgets/sub_page_header.dart';
import '../widgets/xp_track.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

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

/// 成就分组（按枚举名前缀）
const Map<String, String> _groupTitles = {
  'level': '通关',
  'collector': '收藏',
  'streak': '连击',
  'noHint': '无提示',
  'flawless': '零失误',
  'speedrun': '速通',
  'daily': '每日',
  'xp': '经验',
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
                error: (e, _) => Center(child: Text('加载失败: $e', style: bodyStyle(color: AppColors.accent))),
                data: (unlocked) {
                  final total = achievementDefs.length;
                  final groups = <String, List<AchievementDef>>{};
                  for (final def in achievementDefs) {
                    final prefix = _groupFor(def.id);
                    groups.putIfAbsent(prefix, () => []).add(def);
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    children: [
                      AppCard(
                        child: Row(
                          children: [
                            Text(
                              '${unlocked.length}',
                              style: displayStyle(size: 44, weight: FontWeight.w900, color: AppColors.accent, height: 1.1),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('已解锁 / $total 项', style: bodyStyle(size: 12.5, color: AppColors.muted)),
                                  const SizedBox(height: 10),
                                  XpTrack(progress: total == 0 ? 0 : unlocked.length / total, height: 10),
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
                              Text(_groupTitles[entry.key] ?? entry.key,
                                  style: displayStyle(size: 15, weight: FontWeight.w700)),
                              const SizedBox(width: 10),
                              Expanded(child: Container(height: 1, color: AppColors.border)),
                            ],
                          ),
                        ),
                        for (final def in entry.value)
                          _AchRow(def: def, unlocked: unlocked.contains(def.id)),
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

  String _groupFor(AchievementId id) {
    final name = id.name;
    for (final key in _groupTitles.keys) {
      if (name.startsWith(key)) return key;
    }
    return '其他';
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
          AppSeal(
            unlocked ? '通' : '?',
            size: 46,
            fontSize: 15,
            style: unlocked ? AppSealStyle.solid : AppSealStyle.gray,
            vertical: false,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(def.title, style: bodyStyle(size: 14.5, weight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(def.description, style: bodyStyle(size: 11.5, color: AppColors.muted)),
              ],
            ),
          ),
          Text(
            unlocked ? '已获' : '—',
            style: bodyStyle(size: 12, weight: FontWeight.w700, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}

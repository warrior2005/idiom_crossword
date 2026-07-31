import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import '../data/database.dart';
import '../data/growth_manager.dart';

class PlayerState {
  final int level;
  final int totalXp;
  final int xpToNextLevel;
  final String title;
  final int completedLevels;
  final Map<String, int> functionalItems;
  final Set<String> ownedDecorations;

  const PlayerState({
    required this.level,
    required this.totalXp,
    required this.xpToNextLevel,
    required this.title,
    required this.completedLevels,
    required this.functionalItems,
    required this.ownedDecorations,
  });

  double get xpProgress {
    if (xpToNextLevel == 0) return 1.0;
    final currentLevelXp = totalXp - _xpForPreviousLevels();
    return currentLevelXp / xpToNextLevel;
  }

  PlayerState copyWith({
    int? level,
    int? totalXp,
    int? xpToNextLevel,
    String? title,
    int? completedLevels,
    Map<String, int>? functionalItems,
    Set<String>? ownedDecorations,
  }) {
    return PlayerState(
      level: level ?? this.level,
      totalXp: totalXp ?? this.totalXp,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
      title: title ?? this.title,
      completedLevels: completedLevels ?? this.completedLevels,
      functionalItems: functionalItems ?? this.functionalItems,
      ownedDecorations: ownedDecorations ?? this.ownedDecorations,
    );
  }

  int _xpForPreviousLevels() {
    int total = 0;
    for (int i = 1; i < level; i++) {
      total += GrowthManager.xpForLevel(i);
    }
    return total;
  }
}

class PlayerNotifier extends Notifier<PlayerState> {
  @override
  PlayerState build() {
    return const PlayerState(
      level: 1,
      totalXp: 0,
      xpToNextLevel: 100,
      title: '童生',
      completedLevels: 0,
      functionalItems: {},
      ownedDecorations: {},
    );
  }

  /// 从数据库加载已保存的进度（应用启动时调用一次）
  Future<void> loadFromDatabase(AppDatabase db) async {
    final progress = await db.getPlayerProgress();
    if (progress == null) return;
    state = PlayerState(
      level: progress.level,
      totalXp: progress.totalXp,
      xpToNextLevel: GrowthManager.xpForLevel(progress.level + 1),
      title: GrowthManager.titleForLevel(progress.level),
      completedLevels: progress.completedLevels,
      functionalItems: {
        'hint_card': progress.hintCards,
        'revive_card': progress.reviveCards,
      },
      ownedDecorations: await db.getOwnedDecorationIds(),
    );
  }

  Future<ExperienceResult> completeLevel(
    int levelNumber,
    List<int> idiomDifficulties,
  ) async {
    final xp = GrowthManager.calculateXp(levelNumber, idiomDifficulties);
    final oldLevel = state.level;
    final newTotalXp = state.totalXp + xp;
    final newLevel = GrowthManager.levelFromXp(newTotalXp);
    final leveledUp = newLevel > oldLevel;
    final reward = leveledUp ? GrowthManager.rewardForLevel(newLevel) : null;

    state = state.copyWith(
      level: newLevel,
      totalXp: newTotalXp,
      xpToNextLevel: GrowthManager.xpForLevel(newLevel + 1),
      title: GrowthManager.titleForLevel(newLevel),
      completedLevels: state.completedLevels + 1,
      functionalItems: _applyReward(state.functionalItems, reward),
      ownedDecorations: _applyDecorationReward(state.ownedDecorations, reward),
    );

    final db = ref.read(databaseProvider);
    await _persist(db);
    if (reward != null && reward.type == RewardType.decoration) {
      final (type, id) = _splitDecorationId(reward.item);
      await db.addDecoration(type, id);
    }

    return ExperienceResult(
      xpGained: xp,
      leveledUp: leveledUp,
      newLevel: newLevel,
      reward: reward,
    );
  }

  /// 把当前状态写回数据库
  Future<void> _persist(AppDatabase db) {
    return db.updatePlayerProgress(
      level: state.level,
      totalXp: state.totalXp,
      completedLevels: state.completedLevels,
      hintCards: state.functionalItems['hint_card'] ?? 0,
      reviveCards: state.functionalItems['revive_card'] ?? 0,
    );
  }

  /// 'grid_skin_bamboo' -> ('grid_skin', 'bamboo')
  (String, String) _splitDecorationId(String item) {
    final sep = item.lastIndexOf('_');
    if (sep <= 0) return (item, '');
    return (item.substring(0, sep), item.substring(sep + 1));
  }

  Map<String, int> _applyReward(Map<String, int> items, LevelReward? reward) {
    if (reward == null || reward.type != RewardType.functional) return items;
    final updated = Map<String, int>.from(items);
    updated[reward.item] = (updated[reward.item] ?? 0) + reward.quantity;
    return updated;
  }

  Set<String> _applyDecorationReward(Set<String> owned, LevelReward? reward) {
    if (reward == null || reward.type != RewardType.decoration) return owned;
    return {...owned, reward.item};
  }

  Future<void> useHintCard() async {
    final current = state.functionalItems['hint_card'] ?? 0;
    if (current > 0) {
      state = state.copyWith(
        functionalItems: {...state.functionalItems, 'hint_card': current - 1},
      );
      await _persist(ref.read(databaseProvider));
    }
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

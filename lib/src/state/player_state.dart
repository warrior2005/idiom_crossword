import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  int _xpForPreviousLevels() {
    int total = 0;
    for (int i = 1; i < level; i++) {
      total += GrowthManager.xpForLevel(i);
    }
    return total;
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  PlayerNotifier() : super(const PlayerState(
    level: 1,
    totalXp: 0,
    xpToNextLevel: 100,
    title: '童生',
    completedLevels: 0,
    functionalItems: {},
    ownedDecorations: {},
  ));

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

    state = PlayerState(
      level: newLevel,
      totalXp: newTotalXp,
      xpToNextLevel: GrowthManager.xpForLevel(newLevel + 1),
      title: GrowthManager.titleForLevel(newLevel),
      completedLevels: state.completedLevels + 1,
      functionalItems: _applyReward(state.functionalItems, reward),
      ownedDecorations: state.ownedDecorations,
    );

    return ExperienceResult(
      xpGained: xp,
      leveledUp: leveledUp,
      newLevel: newLevel,
      reward: reward,
    );
  }

  Map<String, int> _applyReward(Map<String, int> items, LevelReward? reward) {
    if (reward == null || reward.type != RewardType.functional) return items;
    final updated = Map<String, int>.from(items);
    updated[reward.item] = (updated[reward.item] ?? 0) + reward.quantity;
    return updated;
  }

  Future<void> useHintCard() async {
    final current = state.functionalItems['hint_card'] ?? 0;
    if (current > 0) {
      state = PlayerState(
        level: state.level,
        totalXp: state.totalXp,
        xpToNextLevel: state.xpToNextLevel,
        title: state.title,
        completedLevels: state.completedLevels,
        functionalItems: {...state.functionalItems, 'hint_card': current - 1},
        ownedDecorations: state.ownedDecorations,
      );
    }
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>(
  (ref) => PlayerNotifier(),
);

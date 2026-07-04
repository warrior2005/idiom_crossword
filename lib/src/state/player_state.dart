import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/growth_manager.dart';
import '../data/database.dart';

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
  final AppDatabase _db;

  PlayerNotifier(this._db)
      : super(const PlayerState(
          level: 1,
          totalXp: 0,
          xpToNextLevel: 100,
          title: '童生',
          completedLevels: 0,
          functionalItems: {},
          ownedDecorations: {},
        )) {
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final progress = await _db.getPlayerProgress();
    if (progress != null) {
      final decorations = await (_db.select(_db.decorationTable)).get();
      state = PlayerState(
        level: progress.level,
        totalXp: progress.totalXp,
        xpToNextLevel: GrowthManager.xpForLevel(progress.level),
        title: GrowthManager.titleForLevel(progress.level),
        completedLevels: progress.completedLevels,
        functionalItems: {
          'hint_card': progress.hintCards,
          'revive_card': progress.reviveCards,
        },
        ownedDecorations: decorations.map((d) => d.decorationId).toSet(),
      );
    }
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

    state = PlayerState(
      level: newLevel,
      totalXp: newTotalXp,
      xpToNextLevel: GrowthManager.xpForLevel(newLevel),
      title: GrowthManager.titleForLevel(newLevel),
      completedLevels: state.completedLevels + 1,
      functionalItems: _applyReward(state.functionalItems, reward),
      ownedDecorations: state.ownedDecorations,
    );

    await _db.updatePlayerProgress(
      level: newLevel,
      totalXp: newTotalXp,
      completedLevels: state.completedLevels,
      hintCards: state.functionalItems['hint_card'] ?? 0,
      reviveCards: state.functionalItems['revive_card'] ?? 0,
    );

    await _db.addLevelHistory(
      levelNumber: levelNumber,
      xpGained: xp,
      idiomsUsed: idiomDifficulties,
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
      final updatedItems = {
        ...state.functionalItems,
        'hint_card': current - 1,
      };
      state = PlayerState(
        level: state.level,
        totalXp: state.totalXp,
        xpToNextLevel: state.xpToNextLevel,
        title: state.title,
        completedLevels: state.completedLevels,
        functionalItems: updatedItems,
        ownedDecorations: state.ownedDecorations,
      );
      await _db.updatePlayerProgress(
        level: state.level,
        totalXp: state.totalXp,
        completedLevels: state.completedLevels,
        hintCards: current - 1,
        reviveCards: state.functionalItems['revive_card'] ?? 0,
      );
    }
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>(
  (ref) => PlayerNotifier(AppDatabase()),
);

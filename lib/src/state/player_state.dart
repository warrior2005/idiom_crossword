import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database_provider.dart';
import '../data/database.dart';
import '../data/growth_manager.dart';
import 'level_generation.dart';

class PlayerState {
  final int level;
  final int totalXp;
  final int xpToNextLevel;
  final String title;
  final int completedLevels;
  final int currentCorrectStreak;
  final int bestCorrectStreak;
  final Map<String, int> functionalItems;
  final Set<String> ownedDecorations;

  const PlayerState({
    required this.level,
    required this.totalXp,
    required this.xpToNextLevel,
    required this.title,
    required this.completedLevels,
    required this.currentCorrectStreak,
    required this.bestCorrectStreak,
    required this.functionalItems,
    required this.ownedDecorations,
  });

  double get xpProgress {
    if (xpToNextLevel == 0) return 1.0;
    final currentLevelXp = totalXp - _xpForPreviousLevels();
    return currentLevelXp / xpToNextLevel;
  }

  /// 距离升级还差多少经验
  int get xpRemaining {
    final currentLevelXp = totalXp - _xpForPreviousLevels();
    final remaining = xpToNextLevel - currentLevelXp;
    return remaining < 0 ? 0 : remaining;
  }

  PlayerState copyWith({
    int? level,
    int? totalXp,
    int? xpToNextLevel,
    String? title,
    int? completedLevels,
    int? currentCorrectStreak,
    int? bestCorrectStreak,
    Map<String, int>? functionalItems,
    Set<String>? ownedDecorations,
  }) {
    return PlayerState(
      level: level ?? this.level,
      totalXp: totalXp ?? this.totalXp,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
      title: title ?? this.title,
      completedLevels: completedLevels ?? this.completedLevels,
      currentCorrectStreak: currentCorrectStreak ?? this.currentCorrectStreak,
      bestCorrectStreak: bestCorrectStreak ?? this.bestCorrectStreak,
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
      currentCorrectStreak: 0,
      bestCorrectStreak: 0,
      functionalItems: {},
      ownedDecorations: {},
    );
  }

  /// 从数据库加载已保存的进度（应用启动时调用一次）
  Future<void> loadFromDatabase(AppDatabase db) async {
    final progress = await db.getPlayerProgress();
    if (progress == null) return;
    // 每日挑战不计入主线已获关卡；旧数据若把每日也累加过，这里按主线历史修正。
    final mainCompleted = await db.getCompletedLevelNumbers();
    if (progress.completedLevels != mainCompleted.length) {
      await db.updatePlayerProgress(
        level: progress.level,
        totalXp: progress.totalXp,
        completedLevels: mainCompleted.length,
        hintCards: progress.hintCards,
        reviveCards: progress.reviveCards,
        currentCorrectStreak: progress.currentCorrectStreak,
        bestCorrectStreak: progress.bestCorrectStreak,
      );
    }
    state = PlayerState(
      level: progress.level,
      totalXp: progress.totalXp,
      xpToNextLevel: progress.level >= 20
          ? 0
          : GrowthManager.xpForLevel(progress.level),
      title: GrowthManager.titleForLevel(progress.level),
      completedLevels: mainCompleted.length,
      currentCorrectStreak: progress.currentCorrectStreak,
      bestCorrectStreak: progress.bestCorrectStreak,
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
    final isDaily = levelNumber >= dailyLevelOffset;

    state = state.copyWith(
      level: newLevel,
      totalXp: newTotalXp,
      xpToNextLevel: newLevel >= 20 ? 0 : GrowthManager.xpForLevel(newLevel),
      title: GrowthManager.titleForLevel(newLevel),
      completedLevels: isDaily
          ? state.completedLevels
          : state.completedLevels + 1,
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

  /// 记录一次答对：跨关卡连续连胜 +1，并刷新历史最佳
  Future<void> recordCorrectFill() async {
    final current = state.currentCorrectStreak + 1;
    final best = state.bestCorrectStreak < current
        ? current
        : state.bestCorrectStreak;
    state = state.copyWith(
      currentCorrectStreak: current,
      bestCorrectStreak: best,
    );
    await ref
        .read(databaseProvider)
        .updatePlayerStreak(
          currentCorrectStreak: current,
          bestCorrectStreak: best,
        );
  }

  /// 记录一次答错：连续连胜归零
  Future<void> recordWrongFill() async {
    if (state.currentCorrectStreak == 0) return;
    state = state.copyWith(currentCorrectStreak: 0);
    await ref
        .read(databaseProvider)
        .updatePlayerStreak(
          currentCorrectStreak: 0,
          bestCorrectStreak: state.bestCorrectStreak,
        );
  }

  /// 恢复存档时同步连续答对字数
  Future<void> setCorrectStreak(int value) async {
    final best = value > state.bestCorrectStreak
        ? value
        : state.bestCorrectStreak;
    state = state.copyWith(
      currentCorrectStreak: value,
      bestCorrectStreak: best,
    );
    await ref
        .read(databaseProvider)
        .updatePlayerStreak(
          currentCorrectStreak: value,
          bestCorrectStreak: best,
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
      currentCorrectStreak: state.currentCorrectStreak,
      bestCorrectStreak: state.bestCorrectStreak,
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

  Future<void> useReviveCard() async {
    final current = state.functionalItems['revive_card'] ?? 0;
    if (current > 0) {
      state = state.copyWith(
        functionalItems: {...state.functionalItems, 'revive_card': current - 1},
      );
      await _persist(ref.read(databaseProvider));
    }
  }
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(
  PlayerNotifier.new,
);

/// 下一个主线关卡（排除每日挑战号段）
final nextMainLevelProvider = FutureProvider<int>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  return db.getNextMainLevel();
});

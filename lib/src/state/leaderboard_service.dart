import 'package:games_services/games_services.dart';

import '../data/database.dart';
import '../data/growth_manager.dart';
import 'game_center_service.dart';

enum LeaderboardKind {
  allTime('high_score', '天下英雄榜'),
  weekly('weekly_score', '每周英雄榜');

  final String gameCenterId;
  final String title;

  const LeaderboardKind(this.gameCenterId, this.title);
}

class LeaderboardEntry {
  final int? rank;
  final String playerId;
  final String displayName;
  final int xp;
  final bool isCurrentPlayer;

  const LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.displayName,
    required this.xp,
    required this.isCurrentPlayer,
  });

  int get level => GrowthManager.levelFromXp(xp);
  String get levelLabel => GrowthManager.levelLabel(level);
}

class LeaderboardSnapshot {
  final List<LeaderboardEntry> leaders;
  final LeaderboardEntry currentPlayer;
  final bool connected;

  const LeaderboardSnapshot({
    required this.leaders,
    required this.currentPlayer,
    required this.connected,
  });
}

class LeaderboardService {
  static const int maxResults = 50;

  static DateTime startOfWeek(DateTime date) {
    const chinaOffset = Duration(hours: 8);
    final chinaTime = date.toUtc().add(chinaOffset);
    final chinaDate = DateTime.utc(
      chinaTime.year,
      chinaTime.month,
      chinaTime.day,
    );
    final chinaMonday = chinaDate.subtract(
      Duration(days: chinaDate.weekday - 1),
    );
    return chinaMonday.subtract(chinaOffset);
  }

  static Future<int> currentWeekXp(AppDatabase db) async {
    final history = await db.getLevelHistorySince(startOfWeek(DateTime.now()));
    return history.fold(0, (sum, item) => sum + item.xpGained);
  }

  /// 总榜提交总经验；周榜提交本周累计经验。
  static Future<void> submitScores(AppDatabase db, int totalXp) async {
    if (!await GameCenterService.ensureSignedIn()) return;
    try {
      final weeklyXp = await currentWeekXp(db);
      await Future.wait([
        Leaderboards.submitScore(
          score: Score(
            iOSLeaderboardID: LeaderboardKind.allTime.gameCenterId,
            value: totalXp,
          ),
        ),
        Leaderboards.submitScore(
          score: Score(
            iOSLeaderboardID: LeaderboardKind.weekly.gameCenterId,
            value: weeklyXp,
          ),
        ),
      ]);
    } catch (_) {
      // 排行榜不可用时不影响游戏，下一次启动或通关会再次提交。
    }
  }

  static Future<LeaderboardSnapshot> load({
    required LeaderboardKind kind,
    required int localTotalXp,
    required int localWeeklyXp,
  }) async {
    final localXp = kind == LeaderboardKind.allTime
        ? localTotalXp
        : localWeeklyXp;
    final fallback = LeaderboardEntry(
      rank: null,
      playerId: 'local-player',
      displayName: '我',
      xp: localXp,
      isCurrentPlayer: true,
    );
    if (!await GameCenterService.ensureSignedIn()) {
      return LeaderboardSnapshot(
        leaders: const [],
        currentPlayer: fallback,
        connected: false,
      );
    }

    try {
      final scores =
          await Leaderboards.loadLeaderboardScores(
            iOSLeaderboardID: kind.gameCenterId,
            playerCentered: false,
            scope: PlayerScope.global,
            timeScope: TimeScope.allTime,
            forceRefresh: true,
            maxResults: maxResults,
          ) ??
          const <LeaderboardScoreData>[];
      LeaderboardScoreData? playerScore;
      try {
        playerScore = await Leaderboards.getPlayerScoreObject(
          iOSLeaderboardID: kind.gameCenterId,
          scope: PlayerScope.global,
          timeScope: TimeScope.allTime,
        );
      } catch (_) {
        // 尚未上榜的玩家没有 score object，仍展示全服榜单。
      }
      final currentPlayerId = playerScore?.scoreHolder.playerID;
      final leaders = scores
          .map((score) => _entry(score, currentPlayerId))
          .toList();
      final current = playerScore == null
          ? fallback
          : _entry(playerScore, currentPlayerId, forceCurrent: true);
      return LeaderboardSnapshot(
        leaders: leaders,
        currentPlayer: current,
        connected: true,
      );
    } catch (_) {
      return LeaderboardSnapshot(
        leaders: const [],
        currentPlayer: fallback,
        connected: false,
      );
    }
  }

  static LeaderboardEntry _entry(
    LeaderboardScoreData score,
    String? currentPlayerId, {
    bool forceCurrent = false,
  }) => LeaderboardEntry(
    rank: score.rank,
    playerId: score.scoreHolder.playerID ?? score.scoreHolder.displayName,
    displayName: score.scoreHolder.displayName,
    xp: score.rawScore,
    isCurrentPlayer:
        forceCurrent ||
        (currentPlayerId != null &&
            score.scoreHolder.playerID == currentPlayerId),
  );
}

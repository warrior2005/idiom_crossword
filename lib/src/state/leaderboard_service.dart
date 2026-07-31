import 'package:games_services/games_services.dart';

/// Game Center 排行榜（每日挑战用时，秒，数值越小越好）
class LeaderboardService {
  /// 每日挑战排行榜 ID（需在 App Store Connect 中配置同名排行榜）
  static const String dailyLeaderboardId = 'idiom_daily_challenge';

  /// 提交每日挑战用时；未登录/未配置/不可用时静默降级
  static Future<void> submitDailyTime(Duration time) async {
    try {
      await GamesServices.submitScore(
        score: Score(
          iOSLeaderboardID: dailyLeaderboardId,
          value: time.inSeconds,
        ),
      );
    } catch (_) {
      // 排行榜不可用时不影响游戏
    }
  }

  /// 打开 Game Center 排行榜界面
  static Future<void> show() async {
    try {
      await GamesServices.signIn();
      await GamesServices.showLeaderboards(
        iOSLeaderboardID: dailyLeaderboardId,
      );
    } catch (_) {
      // 未登录或不可用时静默
    }
  }
}

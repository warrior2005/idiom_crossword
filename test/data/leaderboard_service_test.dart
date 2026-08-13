import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/growth_manager.dart';
import 'package:idiom_crossword/src/state/leaderboard_service.dart';

void main() {
  test('自然周固定从中国标准时间周一零点开始', () {
    expect(
      LeaderboardService.startOfWeek(DateTime.utc(2026, 8, 13, 11, 30)),
      DateTime.utc(2026, 8, 9, 16),
    );
  });

  test('排行榜满级显示 Lv.∞', () {
    var maxLevelXp = 0;
    for (var level = 1; level < GrowthManager.maxLevel; level++) {
      maxLevelXp += GrowthManager.xpForLevel(level);
    }
    final entry = LeaderboardEntry(
      rank: 1,
      playerId: 'player',
      displayName: '玩家',
      xp: maxLevelXp,
      isCurrentPlayer: true,
    );
    expect(entry.level, 21);
    expect(entry.levelLabel, 'Lv.∞');
  });
}

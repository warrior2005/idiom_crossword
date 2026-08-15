import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/state/level_state_codec.dart';

void main() {
  test('SavedGameState 编解码保留 totalFills，旧数据缺省 0', () {
    final s = SavedGameState(
      answers: const {},
      usedCandidateSlots: const {},
      fillHistory: const [],
      cellToCandidateSlot: const {},
      candidateBoard: const [
        ['一'],
        ['二'],
      ],
      hintUsesThisLevel: 0,
      errorsMade: 0,
      correctStreak: 0,
      totalFills: 7,
      wrongIdiomWords: const {'画蛇添足'},
      reviveUsesThisLevel: 2,
    );
    final decoded = decodeGameState(encodeGameState(s));
    expect(decoded, isNotNull);
    expect(decoded!.totalFills, 7);
    expect(decoded.wrongIdiomWords, {'画蛇添足'});
    expect(decoded.remainingSeconds, 180);
    expect(decoded.reviveUsesThisLevel, 2);

    // 旧存档（无 fills 键）→ 0
    final legacy = decodeGameState(
      '{"answers":[],"used":[],"history":[],"slots":[],"board":[[]],"hints":0,"errors":0,"streak":0}',
    );
    expect(legacy!.totalFills, 0);
  });
}

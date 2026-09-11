import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/adaptive_policy.dart';

void main() {
  test('校准末段平滑到六词，普通关卡词数有硬边界', () {
    for (var n = 1; n <= 11; n++) {
      final p = AdaptivePolicy(n, 0);
      expect(p.size, lessThanOrEqualTo(6));
      if (n > 1) {
        expect(
          (p.size - AdaptivePolicy(n - 1, 0).size).abs(),
          lessThanOrEqualTo(1),
        );
      }
    }
    for (var step = -5; step <= 40; step++) {
      final p = AdaptivePolicy(10000, step);
      expect(p.size, inInclusiveRange(6, 12));
      expect(p.quotas.values.reduce((a, b) => a + b), p.size);
      expect(
        p.candidateCount(p.answerTarget) - p.answerTarget,
        greaterThanOrEqualTo(4),
      );
    }
  });
  test('相邻策略小步变化，词数、待填和比例不骤变', () {
    for (var step = 1; step <= 30; step++) {
      final a = AdaptivePolicy(51, step - 1), b = AdaptivePolicy(51, step);
      expect(b.size - a.size, inInclusiveRange(0, 1));
      expect(b.answerTarget - a.answerTarget, inInclusiveRange(0, 1));
      expect(b.distractorRatio - a.distractorRatio, inInclusiveRange(0, 0.051));
      expect(
        b.candidateCount(b.answerTarget) - a.candidateCount(a.answerTarget),
        inInclusiveRange(0, 2),
      );
    }
  });
}

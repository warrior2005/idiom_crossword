import 'dart:math';
import 'grid_engine.dart';

/// 词汇/题面变化交错安排；一步只改变一个主要预算，五次有效观察才移动一步。
class AdaptivePolicy {
  final int level;
  final int step;
  AdaptivePolicy(this.level, int step) : step = step.clamp(-5, 30);
  int get size => level <= 10
      ? [2, 2, 3, 3, 4, 4, 5, 5, 6, 6][(level - 1).clamp(0, 9)]
      : 6 + max<int>(0, step) ~/ 5;
  int get answerTarget => level <= 10
      ? max<int>(size, size + max<int>(0, (level - 4) ~/ 2) + min<int>(0, step))
      : step < 0
      ? size + max<int>(0, 3 - (-step + 1) ~/ 2)
      : size + 3 + (step + 2) ~/ 5;
  double get distractorRatio => 0.5 + ((max<int>(0, step) + 1) ~/ 5) * 0.05;
  int candidateCount(int answers) =>
      answers + max<int>(4, (answers * distractorRatio).ceil());
  Map<int, int> get quotas {
    if (level <= 10) {
      final initialBasic = level <= 4
          ? 0
          : level <= 8
          ? 1
          : 2;
      final basic = max<int>(0, initialBasic + min<int>(0, step) ~/ 2);
      return {1: size - basic, 2: basic, 3: 0, 4: 0};
    }
    final expansion = step < 7 ? 0 : 1 + (step - 7) ~/ 10;
    final rare = step < 22 ? 0 : 1;
    final intro = step < 0
        ? min<int>(6, 4 + (-step) ~/ 2)
        : (4 - (step + 3) ~/ 5).clamp(2, 4);
    return {
      1: intro,
      2: size - intro - expansion - rare,
      3: expansion,
      4: rare,
    };
  }

  bool accepts(Iterable<Idiom> words, Map<String, int> tiers) {
    final counts = <int, int>{};
    for (final word in words) {
      final tier = tiers[word.text] ?? 4;
      counts[tier] = (counts[tier] ?? 0) + 1;
      if (counts[tier]! > (quotas[tier] ?? 0)) return false;
    }
    return true;
  }

  /// 先给个人陌生词和生僻词支持，再把实际待填量约束到固定预算。
  bool support(
    CrosswordLevel puzzle,
    Map<String, int> tiers,
    Set<String> familiar, {
    Set<int> weakTiers = const {},
  }) {
    bool canGive((int, int) pos) => puzzle.placements
        .where((p) => p.cells.contains(pos))
        .every(
          (p) =>
              p.cells
                  .where((c) => !puzzle.grid.cellAt(c.$1, c.$2).isGiven)
                  .length >
              1,
        );
    void give((int, int) pos) {
      final cell = puzzle.grid.cellAt(pos.$1, pos.$2);
      cell.isGiven = true;
      puzzle.givenCharacters.add(cell.character);
    }

    // 陌生高档词最多留两空；其余预填随全局待填预算调节。
    for (final p in puzzle.placements) {
      final goal =
          (tiers[p.idiom.text] ?? 4) >= 3 && !familiar.contains(p.idiom.text)
          ? 2
          : 1;
      for (final pos in p.cells) {
        if (p.cells
                .where((c) => puzzle.grid.cellAt(c.$1, c.$2).isGiven)
                .length >=
            goal) {
          break;
        }
        if (!puzzle.grid.cellAt(pos.$1, pos.$2).isGiven && canGive(pos)) {
          give(pos);
        }
      }
    }
    final cells = puzzle.placements.expand((p) => p.cells).toSet().toList();
    // 不预填交叉格优先保留自然线索；优先帮助未熟悉词。
    cells.sort((a, b) {
      int priority((int, int) c) {
        final cell = puzzle.grid.cellAt(c.$1, c.$2);
        final known = puzzle.placements
            .where((p) => p.cells.contains(c))
            .every((p) => familiar.contains(p.idiom.text));
        final weak = puzzle.placements
            .where((p) => p.cells.contains(c))
            .any((p) => weakTiers.contains(tiers[p.idiom.text]));
        return (cell.isIntersection ? 4 : 0) + (known ? 2 : 0) + (weak ? 0 : 1);
      }

      return priority(a).compareTo(priority(b));
    });
    for (final pos in cells) {
      if (puzzle.fillableCells <= answerTarget) break;
      if (!puzzle.grid.cellAt(pos.$1, pos.$2).isGiven && canGive(pos)) {
        give(pos);
      }
    }
    return puzzle.fillableCells <= answerTarget &&
        puzzle.fillableCells >= max<int>(1, answerTarget - 2) &&
        puzzle.placements.every(
          (p) => p.cells.any((c) => !puzzle.grid.cellAt(c.$1, c.$2).isGiven),
        );
  }
}

import 'dart:math';
import 'grid_engine.dart';

/// 与科举经验和旧词汇分数无关的题面配置，写入题目后保持稳定。
class MainlinePolicy {
  final int size;
  final int expansionLimit;
  final int support;
  const MainlinePolicy(this.size, this.expansionLimit, this.support);

  static MainlinePolicy forLevel(int level, {int ability = 0}) {
    if (level <= 5 && ability <= 0) {
      final teachingSize = level <= 2
          ? 2
          : level <= 4
          ? 3
          : 4;
      return MainlinePolicy(
        (teachingSize + (ability < 0 ? -1 : 0)).clamp(2, 4),
        0,
        3,
      );
    }
    final size = level <= 20
        ? 4
        : level <= 50
        ? 5
        : 6;
    // 每五关复习一次；放松题面而不降低成长奖励或进度。
    final review = level % 5 == 0;
    return MainlinePolicy(
      (size + ability).clamp(3, 8),
      level <= 20 || review || ability < 0 ? 0 : 1,
      ability < 0
          ? 3
          : review || ability == 0
          ? 2
          : 1,
    );
  }

  static int candidateCount(int answers, int words, int support) =>
      answers +
      max(
        2,
        words *
            (support >= 3
                ? 1
                : support == 2
                ? 2
                : 3),
      );
}

/// 基础词子图连通，新词连接基础部分；先推进基础词再获得新词线索。
bool hasMainlineRoute(CrosswordLevel level, Set<String> foundation, int limit) {
  final basic = level.placements
      .where((p) => foundation.contains(p.idiom.text))
      .toList();
  final novel = level.placements
      .where((p) => !foundation.contains(p.idiom.text))
      .toList();
  if (basic.isEmpty || novel.length > limit) return false;
  final reached = <Placement>{basic.first};
  var changed = true;
  while (changed) {
    changed = false;
    for (final p in basic) {
      if (!reached.contains(p) &&
          reached.any(
            (other) => level.grid.findIntersection(p, other) != null,
          )) {
        reached.add(p);
        changed = true;
      }
    }
  }
  if (reached.length != basic.length) return false;
  return novel.every(
    (p) => basic.any((b) => level.grid.findIntersection(p, b) != null),
  );
}

void addMainlineGivens(
  CrosswordLevel level,
  Set<String> foundation,
  int support,
) {
  final first = level.placements.firstWhere(
    (p) => foundation.contains(p.idiom.text),
  );
  for (final p in level.placements) {
    final target = p == first
        ? 3
        : !foundation.contains(p.idiom.text)
        ? 2
        : support;
    var count = p.cells
        .where((c) => level.grid.cellAt(c.$1, c.$2).isGiven)
        .length;
    // 非交叉字优先，避免把相邻成语全部自动填完。
    final cells = p.cells.toList()
      ..sort(
        (a, b) => (level.grid.cellAt(a.$1, a.$2).isIntersection ? 1 : 0)
            .compareTo(level.grid.cellAt(b.$1, b.$2).isIntersection ? 1 : 0),
      );
    for (final c in cells) {
      if (count >= target) break;
      final cell = level.grid.cellAt(c.$1, c.$2);
      if (!cell.isGiven) {
        cell.isGiven = true;
        level.givenCharacters.add(cell.character);
        count++;
      }
    }
  }
}

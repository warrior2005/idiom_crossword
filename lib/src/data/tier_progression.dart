import '../engine/grid_engine.dart';

/// 词汇阶段与题面step独立；一次观察最多交接一个词的配额。
class TierProgression {
  static Map<String, dynamic> state(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(
        data['progression'] as Map? ?? {'tier': 1, 'next': 0, 'sinceChange': 0},
      );

  /// 升级时只承接有词级熟悉记录且有稳定分档表现的旧证据。
  static void restoreLegacy(
    Map<String, dynamic> data,
    Map<String, int> wordTiers,
  ) {
    if (data['progression'] != null) return;
    final words = data['words'] as Map? ?? {};
    final performance = data['tierPerformance'] as Map? ?? {};
    final evidence = <String, dynamic>{};
    var mastered = 0;
    for (var t = 1; t <= 4; t++) {
      final known = words.entries
          .where(
            (e) =>
                wordTiers[e.key] == t &&
                ((e.value['independent'] as int? ?? 0) > 0 ||
                    (e.value['supported'] as int? ?? 0) >= 3),
          )
          .map((e) => e.key as String)
          .toList();
      final old = performance['$t'] as Map? ?? {};
      final neededWords = t == 1
          ? 6
          : t == 2
          ? 24
          : 36;
      final neededObservations = t == 1
          ? 3
          : t == 2
          ? 8
          : 12;
      if (known.length < neededWords ||
          (old['observations'] as int? ?? 0) < neededObservations ||
          (old['trend'] as num? ?? 0) < 0.78) {
        break;
      }
      mastered = t;
      evidence['$t'] = {...old, 'words': known};
    }
    data['progression'] = {
      'tier': mastered < 1 ? 1 : mastered,
      'next': mastered == 1 ? 1 : 0,
      'sinceChange': 0,
      'evidence': evidence,
      'origin': 'legacy_evidence',
    };
  }

  static bool observe(
    Map<String, dynamic> data,
    CrosswordLevel level,
    Set<String> solved,
    Set<String> wrong,
    int hints,
  ) {
    final state = TierProgression.state(data);
    final tier = (state['tier'] as int).clamp(1, 4);
    var next = state['next'] as int;
    final evidence = Map<String, dynamic>.from(state['evidence'] as Map? ?? {});
    final tiers = level.strategy['wordTiers'] as Map? ?? {};
    for (var t = 1; t <= 4; t++) {
      final subset = level.placements.where((p) => tiers[p.idiom.text] == t);
      if (subset.isEmpty) continue;
      final old = evidence['$t'] as Map? ?? {};
      final clean = Set<String>.from(old['words'] as List? ?? []);
      var total = 0.0;
      for (final p in subset) {
        final given = p.cells
            .where((c) => level.grid.cellAt(c.$1, c.$2).isGiven)
            .length;
        final ok =
            solved.contains(p.idiom.text) &&
            !wrong.contains(p.idiom.text) &&
            hints == 0;
        // 辅助较多的正确作答不增加掌握证据，也不抹掉已有证据。
        total += ok
            ? (given <= 2 ? 0.95 : (old['trend'] as num? ?? 0.7))
            : 0.25;
        if (ok && given <= 2) clean.add(p.idiom.text);
      }
      evidence['$t'] = {
        'observations': (old['observations'] as int? ?? 0) + 1,
        'trend':
            (old['trend'] as num? ?? 0.7) * 0.7 + total / subset.length * 0.3,
        'words': clean.toList(),
      };
    }
    bool ready(int t, {bool exploring = false}) {
      final e = evidence['$t'] as Map? ?? {};
      final intro = t == 1;
      final minObservations = intro
          ? 3
          : exploring
          ? 4
          : t == 2
          ? 8
          : 12;
      final minWords = intro
          ? 6
          : exploring
          ? 8
          : t == 2
          ? 24
          : 36;
      return (e['observations'] as int? ?? 0) >= minObservations &&
          (e['trend'] as num? ?? 0) >= 0.78 &&
          (e['words'] as List? ?? []).length >= minWords;
    }

    final elapsed = (state['sinceChange'] as int? ?? 0) + 1;
    var changed = false;
    var newTier = tier;
    if (tier < 4 && elapsed >= (tier == 1 ? 3 : 8)) {
      final nextTrend =
          (evidence['${tier + 1}'] as Map?)?['trend'] as num? ?? 0.7;
      if (next > 0 && nextTrend < 0.5) {
        next--;
        changed = true;
      } else if (ready(tier) &&
          (next == 0 || ready(tier + 1, exploring: true))) {
        final size = level.idioms.length < 6 ? 6 : level.idioms.length;
        final lower = tier > 1 ? 1 : 0;
        if (next >= size - lower - 1) {
          newTier++;
          next = 0;
        } else {
          next++;
        }
        changed = true;
      }
    }
    if (!changed &&
        tier > 1 &&
        next == 0 &&
        elapsed >= 8 &&
        ((evidence['$tier'] as Map?)?['observations'] as int? ?? 0) >= 5 &&
        ((evidence['$tier'] as Map?)?['trend'] as num? ?? 1) < 0.5) {
      newTier--;
      final size = level.idioms.length < 6 ? 6 : level.idioms.length;
      next = size - (newTier > 1 ? 1 : 0) - 1;
      changed = true;
    }
    state.addAll({
      'tier': newTier,
      'next': next,
      'sinceChange': changed ? 0 : elapsed,
      'evidence': evidence,
    });
    data['progression'] = state;
    return changed;
  }
}

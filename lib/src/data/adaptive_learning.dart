import 'dart:math';
import '../engine/adaptive_policy.dart';
import '../engine/grid_engine.dart';

/// 策略4：累计覆盖控制准入，近期表现控制实际配额；持久化于学习记录中。
class AdaptiveLearning {
  static const version = 4;
  static const mixes = <List<double>>[
    [1, 0, 0, 0],
    [.2, .8, 0, 0],
    [.1, .3, .6, 0],
    [.1, .2, .3, .4],
  ];

  static Map<String, dynamic> state(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(data['adaptiveV4'] as Map);

  static void initialize(
    Map<String, dynamic> data,
    Map<String, int> catalog,
    int contentVersion,
  ) {
    final old = data['progression'] as Map? ?? {};
    final tier = (old['tier'] as int? ?? 1).clamp(1, 4);
    final step = (data['adaptive'] as Map?)?['step'] as int? ?? 0;
    final legacy =
        data['adaptiveV4'] == null &&
        (data['progression'] != null || (data['sessions'] as List).isNotEmpty);
    final policy = AdaptivePolicy(
      11,
      step,
      tier: tier,
      nextCount: old['next'] as int? ?? 0,
    );
    final s = data['adaptiveV4'] == null
        ? <String, dynamic>{
            'tier': tier,
            'mix': legacy
                ? [for (var t = 1; t <= 4; t++) policy.quotas[t]! / policy.size]
                : List<double>.from(mixes[tier - 1]),
            'coverage': <String, dynamic>{},
            'recent': <dynamic>[],
            'timings': <dynamic>[],
            'elapsed': 0,
            'normalizing': legacy,
            'migrationRemaining': legacy ? 10 : 0,
          }
        : state(data);
    // 只承接旧词汇证据中的逐词成功名单，不将supported次数当作新覆盖证据。
    final covered = <String>{
      for (final words in (s['coverage'] as Map).values)
        ...List<String>.from(words as List),
      if (data['adaptiveV4'] == null)
        for (final e in (old['evidence'] as Map? ?? {}).values)
          ...List<String>.from((e as Map)['words'] as List? ?? []),
    };
    s['coverage'] = {
      for (var t = 1; t <= 4; t++)
        '$t': covered.where((w) => catalog[w] == t).toList(),
    };
    s['totals'] = {
      for (var t = 1; t <= 4; t++)
        '$t': catalog.values.where((v) => v == t).length,
    };
    s['contentVersion'] = contentVersion;
    data['adaptiveV4'] = s;
  }

  static double coverage(Map<String, dynamic> s, int tier) {
    final total = (s['totals'] as Map)['$tier'] as int? ?? 0;
    return total == 0
        ? 0
        : ((s['coverage'] as Map)['$tier'] as List).length / total;
  }

  static double explorationCap(double coverage) => coverage < .2
      ? 0
      : coverage < .3
      ? .2
      : coverage < .4
      ? .35
      : coverage < .5
      ? .5
      : 1;

  /// 系统抽样将比例分摊到连续10次曝光，既保证总词数，也避免小题永远取整为0。
  static Map<int, int> quotas(List<double> mix, int size, int sequence) {
    final result = {1: 0, 2: 0, 3: 0, 4: 0};
    for (var i = 0; i < size; i++) {
      final point = (i + ((sequence % 10) + .5) / 10) / size;
      var cumulative = 0.0;
      for (var t = 0; t < 4; t++) {
        cumulative += mix[t];
        if (point < cumulative + 1e-9 || t == 3) {
          result[t + 1] = result[t + 1]! + 1;
          break;
        }
      }
    }
    return result;
  }

  static bool _move(List<double> mix, List<double> target, int size) {
    final donors = [0, 1, 2, 3]
      ..sort((a, b) => (mix[b] - target[b]).compareTo(mix[a] - target[a]));
    final receivers = [0, 1, 2, 3]
      ..sort((a, b) => (target[b] - mix[b]).compareTo(target[a] - mix[a]));
    final from = donors.first, to = receivers.first;
    final amount = min(
      1 / size,
      min(mix[from] - target[from], target[to] - mix[to]),
    );
    if (amount < 1e-8) return false;
    mix[from] -= amount;
    mix[to] += amount;
    return true;
  }

  static bool _at(List<double> a, List<double> b) =>
      [0, 1, 2, 3].every((i) => (a[i] - b[i]).abs() < 1e-8);

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final n = sorted.length;
    return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
  }

  static double? _timeRatio(Map<String, dynamic> s, int tier, double? time) {
    if (time == null) return null;
    final timings = List<Map<String, dynamic>>.from(
      (s['timings'] as List).map((v) => Map<String, dynamic>.from(v as Map)),
    );
    timings.add({'tier': tier, 'time': time});
    while (timings.length > 100) {
      timings.removeAt(0);
    }
    s['timings'] = timings;
    final values = timings
        .where((v) => v['tier'] == tier)
        .map((v) => (v['time'] as num).toDouble())
        .toList();
    if (values.length < 15) return null;
    final recent = values.sublist(values.length - 5)..sort();
    final previous = values.sublist(
      max(0, values.length - 25),
      values.length - 5,
    );
    final baseline = s['timeBaseline'] as num? ?? _median(previous);
    s['timeBaseline'] = baseline;
    return recent.take(4).reduce((a, b) => a + b) / 4 / baseline;
  }

  static void observe(
    Map<String, dynamic> data,
    CrosswordLevel level, {
    required bool successful,
    required Set<String> solved,
    required Set<String> wrong,
    required Set<String>? hinted,
    required int hints,
    required int errors,
    required int activeTimeMs,
    Map<String, int>? currentWordTiers,
  }) {
    final s = state(data);
    var tier = s['tier'] as int;
    final mix = (s['mix'] as List).map((v) => (v as num).toDouble()).toList();
    final wordTiers =
        currentWordTiers ?? level.strategy['wordTiers'] as Map? ?? {};
    final counts = <String, dynamic>{};
    final covered = Map<String, dynamic>.from(s['coverage'] as Map);
    for (var t = 1; t <= 4; t++) {
      final words = Set<String>.from(covered['$t'] as List? ?? []);
      var total = 0, clean = 0;
      for (final p in level.placements.where(
        (p) => wordTiers[p.idiom.text] == t,
      )) {
        total++;
        final given = p.cells
            .where((c) => level.grid.cellAt(c.$1, c.$2).isGiven)
            .length;
        if (solved.contains(p.idiom.text) &&
            !wrong.contains(p.idiom.text) &&
            (hinted == null ? hints == 0 : !hinted.contains(p.idiom.text)) &&
            given <= 2) {
          clean++;
          words.add(p.idiom.text);
        }
      }
      covered['$t'] = words.toList();
      if (total > 0) counts['$t'] = {'clean': clean, 'total': total};
    }
    s['coverage'] = covered;
    final recent =
        List<Map<String, dynamic>>.from(
          (s['recent'] as List).map((v) => Map<String, dynamic>.from(v as Map)),
        )..add({
          'success': successful,
          'smooth': successful && hints == 0 && errors <= 1,
          'struggle': hints > 0 || errors >= 2,
          'tiers': counts,
        });
    if (recent.length > 10) recent.removeAt(0);
    s['recent'] = recent;
    final elapsed = (s['elapsed'] as int) + 1;
    s['elapsed'] = elapsed;
    final size = max(6, level.idioms.length);
    final ratio = _timeRatio(
      s,
      tier,
      successful &&
              (level.strategy['tier'] as int? ?? tier) == tier &&
              activeTimeMs > 0 &&
              level.fillableCells > 0
          ? activeTimeMs / level.fillableCells
          : null,
    );
    if (ratio != null) {
      s['timeRatio'] = ratio;
      final fresh = (s['freshTimings'] as int? ?? 0) + 1;
      s['freshTimings'] = fresh;
      s['slowCount'] = ratio > 1.5 && fresh >= 5
          ? (s['slowCount'] as int? ?? 0) + 1
          : 0;
    }
    double? rate(int t, int window) {
      final observations = recent
          .where((r) => (r['tiers'] as Map).containsKey('$t'))
          .toList()
          .reversed
          .take(window)
          .toList();
      if (observations.length < window) return null;
      var clean = 0, total = 0;
      for (final r in observations) {
        final c = (r['tiers'] as Map)['$t'] as Map;
        clean += c['clean'] as int;
        total += c['total'] as int;
      }
      return clean / total;
    }

    final failures = recent.reversed
        .take(3)
        .where((r) => r['success'] != true)
        .length;
    final struggles = recent.reversed
        .take(5)
        .where((r) => r['struggle'] == true)
        .length;
    final nextRate = tier < 4 ? rate(tier + 1, 5) : null;
    final burden =
        failures >= 2 ||
        struggles >= 3 ||
        (s['slowCount'] as int? ?? 0) >= 2 ||
        (nextRate != null && nextRate < .7);
    final adaptive = Map<String, dynamic>.from(data['adaptive'] as Map? ?? {});
    var step = (adaptive['step'] as int? ?? 0).clamp(-5, 30);
    var changed = false;
    var reason = 'observe';
    final migration = s['migrationRemaining'] as int? ?? 0;
    if (migration > 0) s['migrationRemaining'] = migration - 1;
    if (burden && elapsed >= 3) {
      final highest = [3, 2, 1].where((i) => mix[i] > 1e-8).firstOrNull;
      final weakVocabulary =
          highest != null &&
          (highest + 1 > tier || (rate(highest + 1, 3) ?? 1) < .7);
      if (weakVocabulary) {
        final amount = min(1 / size, mix[highest]);
        mix[highest] -= amount;
        mix[highest - 1] += amount;
        if (mix[tier - 1] < 1e-8 && tier > 1) tier--;
        changed = true;
        reason = 'vocabulary_relief';
      } else {
        final before = AdaptivePolicy(
          level.levelId,
          step,
          tier: tier,
          quotaOverride: quotas(mix, size, 0),
        );
        for (var candidate = step - 1; candidate >= -5; candidate--) {
          final candidateSize = AdaptivePolicy(level.levelId, candidate).size;
          final p = AdaptivePolicy(
            level.levelId,
            candidate,
            tier: tier,
            quotaOverride: quotas(mix, candidateSize, 0),
          );
          if (p.answerTarget < before.answerTarget ||
              p.candidateCount(p.answerTarget) <
                  before.candidateCount(before.answerTarget)) {
            step = candidate;
            changed = true;
            reason = 'board_relief';
            break;
          }
        }
      }
      s['normalizing'] = false;
    } else if (migration == 0 && s['normalizing'] == true && elapsed >= 3) {
      changed = _move(mix, mixes[tier - 1], size);
      s['normalizing'] = !_at(mix, mixes[tier - 1]);
      reason = 'migration_mix';
    } else if (migration == 0 &&
        elapsed >= 10 &&
        recent.length == 10 &&
        recent.where((r) => r['smooth'] == true).length >= 8 &&
        (s['timeRatio'] as num? ?? 1) <= 1.2 &&
        !burden) {
      final base = mixes[tier - 1];
      final recovering =
          mix[tier - 1] < base[tier - 1] - 1e-8 &&
          (tier == 4 || mix[tier] < 1e-8);
      if (recovering) {
        if ((rate(tier, 5) ?? 0) >= .85) changed = _move(mix, base, size);
      } else if (tier < 4) {
        final coveredRatio = coverage(s, tier);
        final cap = min(explorationCap(coveredRatio), mixes[tier][tier]);
        final target = [...mixes[tier]];
        target[tier - 1] += target[tier] - cap;
        target[tier] = cap;
        final exploring = mix[tier] > 1e-8;
        if (cap > 0 && (!exploring || (nextRate ?? 0) >= .85)) {
          // 首次只转移一个词到相邻高档，不先改变低档混合结构。
          if (!exploring) {
            final amount = min(1 / size, min(cap, mix[tier - 1]));
            mix[tier - 1] -= amount;
            mix[tier] += amount;
            changed = amount > 0;
          } else {
            changed = _move(mix, target, size);
          }
          if (coveredRatio >= .5 && _at(mix, mixes[tier])) {
            tier++;
            changed = true;
          }
        }
      }
      if (changed) {
        reason = 'vocabulary_progress';
      } else if (step < 30 &&
          [1, 2, 3, 4].every((t) => (rate(t, 5) ?? 1) >= .85)) {
        step++;
        changed = true;
        reason = 'board_progress';
      }
    }
    if (changed) {
      s['elapsed'] = 0;
      // 消费本轮证据，旧受挫不能重复触发；计时样本保留，比较基准固定。
      s['recent'] = <dynamic>[];
      s['slowCount'] = 0;
      s['freshTimings'] = 0;
    }
    if (!changed &&
        elapsed >= 10 &&
        ratio != null &&
        ratio <= 1.2 &&
        recent.length == 10 &&
        recent.every((r) => r['smooth'] == true) &&
        _at(mix, mixes[tier - 1])) {
      s.remove('timeBaseline');
    }
    if (tier != s['tier']) {
      s.remove('timeBaseline');
      s.remove('timeRatio');
      s['slowCount'] = 0;
    }
    s['tier'] = tier;
    s['mix'] = mix;
    s['lastReason'] = reason;
    adaptive['step'] = step;
    adaptive['lastReason'] = reason;
    data['adaptive'] = adaptive;
    data['adaptiveV4'] = s;
    data['progression'] = {
      ...?data['progression'] as Map?,
      'tier': tier,
      'next': 0,
    };
  }
}

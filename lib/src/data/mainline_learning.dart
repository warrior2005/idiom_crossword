import 'dart:convert';
import '../engine/grid_engine.dart';
import 'database.dart';
import 'tier_progression.dart';
import 'mainline_exposure.dart';

/// 轻量本地观察；题面支持下完成不等同于掌握。保留最近40次题目及词级汇总。
class MainlineLearning {
  static const key = 'mainline_learning_v1';
  static Future<Map<String, dynamic>> read(AppDatabase db) async {
    final raw = await db.getSetting(key);
    return raw == null
        ? {'sessions': <dynamic>[], 'words': <String, dynamic>{}}
        : jsonDecode(raw) as Map<String, dynamic>;
  }

  // 旧偏好和旧分档窗口只作历史记录，不参与新策略。
  static Future<int> ability(AppDatabase db) async {
    final data = await read(db);
    return ((data['adaptive'] as Map?)?['step'] as int? ?? 0).clamp(-5, 30);
  }

  static Future<Set<String>> familiarWords(AppDatabase db) async {
    final data = await read(db);
    return (data['words'] as Map<String, dynamic>).entries
        .where(
          (e) =>
              ((e.value['independent'] as int? ?? 0) > 0) ||
              ((e.value['supported'] as int? ?? 0) >= 3),
        )
        .map((e) => e.key)
        .toSet();
  }

  static Future<Set<int>> weakTiers(AppDatabase db) async {
    final data = await read(db);
    return (data['tierPerformance'] as Map? ?? {}).entries
        .where(
          (e) =>
              (e.value['observations'] as int) >= 5 &&
              (e.value['trend'] as num) < 0.5,
        )
        .map((e) => int.parse(e.key as String))
        .toSet();
  }

  static Future<Set<String>> dueWords(AppDatabase db, {DateTime? now}) async {
    final data = await read(db);
    final time = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final exposure = await MainlineExposure.read(db);
    final sequence = exposure['sequence'] as int;
    final recent = MainlineExposure.recentWords(exposure);
    final words = data['words'] as Map<String, dynamic>;
    return words.entries
        .where((e) {
          final w = e.value as Map;
          if (w['reviewNeeded'] != true || recent.contains(e.key)) return false;
          final gap = (w['reviewSuccesses'] as int? ?? 0) > 0 ? 12 : 6;
          return sequence - (w['seenSequence'] as int? ?? sequence) >= gap ||
              time >= (w['reviewDue'] as int? ?? time + 1);
        })
        .map((e) => e.key)
        .toSet();
  }

  static Future<void> record(
    AppDatabase db,
    CrosswordLevel level, {
    required String status,
    required int hints,
    required int errors,
    Iterable<String> completed = const [],
    Set<String> wrong = const {},
    DateTime? now,
    int activeTimeMs = 0,
  }) async {
    if (level.strategyVersion == 0 || level.instanceId == null) return;
    final time = (now ?? DateTime.now()).millisecondsSinceEpoch;
    await db.transaction(() async {
      await MainlineExposure.show(db, level);
      final exposure = await MainlineExposure.read(db);
      final sequence = exposure['sequence'] as int;
      final data = await read(db);
      final sessions = (data['sessions'] as List).cast<Map<String, dynamic>>();
      final matching = sessions.where((s) => s['id'] == level.instanceId);
      // 明细窗口会滚动，但已结算实例不能再次成为能力证据。
      final observedIds = Set<String>.from(
        data['observedInstances'] as List? ?? [],
      );
      if (matching.isEmpty && observedIds.contains(level.instanceId)) return;
      final session = matching.isEmpty
          ? <String, dynamic>{
              'id': level.instanceId,
              'number': level.levelId,
              'content': level.contentVersion,
              'strategy': level.strategyVersion,
              'support': level.support,
              'policy': level.strategy,
              'words': level.idioms.map((i) => i.text).toList(),
              'preference':
                  int.tryParse(await db.getSetting('mainline_ability') ?? '') ??
                  0,
              'entered': time,
              'credited': <String>[],
            }
          : matching.first;
      if (['complete', 'replaced'].contains(session['status'])) return;
      if (matching.isEmpty) sessions.add(session);
      session.addAll({
        'status': status,
        'hints': hints,
        'errors': errors,
        'updated': time,
        'activeTimeMs': activeTimeMs,
      });
      if (level.strategyVersion >= 2 &&
          ['complete', 'failed', 'replaced'].contains(status) &&
          session['evaluated'] != true) {
        session['evaluated'] = true;
        observedIds.add(level.instanceId!);
        data['observedInstances'] = observedIds.toList();
        final adaptive = Map<String, dynamic>.from(
          data['adaptive'] as Map? ?? {},
        );
        final successful = status == 'complete';
        final solved = {
          ...(session['credited'] as List).cast<String>(),
          ...completed,
        };
        final wordTiers = level.strategy['wordTiers'] as Map? ?? {};
        final tierPerformance = Map<String, dynamic>.from(
          data['tierPerformance'] as Map? ?? {},
        );
        for (final tier in wordTiers.values.toSet()) {
          final subset = level.idioms
              .where((i) => wordTiers[i.text] == tier)
              .toList();
          if (subset.isEmpty) continue;
          final previous = tierPerformance['$tier'] as Map? ?? {};
          final score =
              subset
                  .map(
                    (i) => (successful || solved.contains(i.text))
                        ? (0.9 -
                              (wrong.contains(i.text) ? 0.3 : 0) -
                              hints.clamp(0, 3) * 0.1)
                        : 0.2,
                  )
                  .reduce((a, b) => a + b) /
              subset.length;
          tierPerformance['$tier'] = {
            'observations': (previous['observations'] as int? ?? 0) + 1,
            'trend': (previous['trend'] as num? ?? 0.7) * 0.8 + score * 0.2,
          };
        }
        data['tierPerformance'] = tierPerformance;
        // 多字预填完成最多提供中等强度证据；用时不作为独立惩罚项。
        final givens = level.grid.rows == 0
            ? 0
            : level.placements.fold<int>(
                0,
                (sum, p) =>
                    sum +
                    p.cells
                        .where((c) => level.grid.cellAt(c.$1, c.$2).isGiven)
                        .length,
              );
        final supports = level.placements.isEmpty
            ? 0
            : givens / level.placements.length;
        final rawObservation = successful
            ? (0.92 -
                      hints.clamp(0, 4) * 0.13 -
                      errors.clamp(0, 4) * 0.10 -
                      (supports > 2 ? 0.08 : 0))
                  .clamp(0.0, 1.0)
            : 0.2 +
                  0.65 *
                      solved.length /
                      (level.idioms.isEmpty ? 1 : level.idioms.length);
        // 新策略中持续未过关必须能减负；部分完成仍保留词级学习证据。
        final observation = level.strategyVersion >= 3 && !successful
            ? rawObservation.clamp(0.0, 0.45)
            : rawObservation;
        final trend =
            (adaptive['trend'] as num? ?? 0.7).toDouble() * 0.8 +
            observation * 0.2;
        final count = (adaptive['sinceChange'] as int? ?? 0) + 1;
        var step = (adaptive['step'] as int? ?? 0).clamp(-5, 30);
        var changed = false;
        final vocabularyChanged =
            level.strategyVersion >= 3 &&
            TierProgression.observe(
              data,
              level,
              successful ? level.idioms.map((i) => i.text).toSet() : solved,
              wrong,
              hints,
            );
        if (count >= 5 && !vocabularyChanged) {
          final tiersReady = tierPerformance.entries
              .where((e) => wordTiers.values.contains(int.parse(e.key)))
              .map((e) => e.value)
              .every(
                (v) =>
                    (v['observations'] as int) < 5 ||
                    (v['trend'] as num) >= 0.6,
              );
          if (trend >= 0.82 && step < 30 && tiersReady) {
            step++;
            changed = true;
          }
          if (trend <= 0.50 && step > -5) {
            step--;
            changed = true;
          }
        }
        adaptive.addAll({
          'step': step,
          'trend': trend,
          'sinceChange': changed || vocabularyChanged ? 0 : count,
          'lastReason': changed
              ? (trend >= 0.82 ? 'consistent_success' : 'consistent_struggle')
              : 'observe',
        });
        data['adaptive'] = adaptive;
        session['observation'] = observation;
        session['abilityAfter'] = step;
      }
      final words = data['words'] as Map<String, dynamic>;
      if (session['exposed'] != true) {
        for (final word in level.idioms.map((i) => i.text)) {
          final previous = words[word] as Map<String, dynamic>? ?? {};
          words[word] = {
            ...previous,
            'exposures': (previous['exposures'] as int? ?? 0) + 1,
            'lastSeen': time,
            'seenSequence': sequence,
            'due':
                previous['due'] ??
                time + const Duration(days: 1).inMilliseconds,
          };
        }
        session['exposed'] = true;
      }
      final reviewSignals = Set<String>.from(
        session['reviewSignals'] as List? ?? [],
      );
      for (final word in wrong) {
        if (!level.idioms.any((i) => i.text == word) ||
            !reviewSignals.add(word)) {
          continue;
        }
        final previous = words[word] as Map<String, dynamic>? ?? {};
        words[word] = {
          ...previous,
          'reviewNeeded': true,
          'reviewSuccesses': 0,
          'reviewSignals': (previous['reviewSignals'] as int? ?? 0) + 1,
          'reviewDue': time + const Duration(days: 1).inMilliseconds,
        };
      }
      session['reviewSignals'] = reviewSignals.toList();
      final credited = Set<String>.from(session['credited'] as List);
      for (final word in completed) {
        if (!credited.add(word)) continue;
        final placements = level.placements.where((p) => p.idiom.text == word);
        if (placements.isEmpty) continue;
        final p = placements.first;
        final givens = p.cells
            .where((c) => level.grid.cellAt(c.$1, c.$2).isGiven)
            .length;
        // 任一提示时保守归为辅助完成，避免交叉提示被误计为独立回忆。
        final crossSupported = p.cells.any((c) {
          final cell = level.grid.cellAt(c.$1, c.$2);
          return cell.isIntersection && !cell.isGiven;
        });
        final independent =
            hints == 0 &&
            !wrong.contains(word) &&
            givens <= 1 &&
            !crossSupported;
        final previous = words[word] as Map<String, dynamic>? ?? {};
        final lastIndependent = previous['lastIndependent'] as int?;
        final delayed =
            independent &&
            lastIndependent != null &&
            time - lastIndependent >= const Duration(days: 1).inMilliseconds;
        final retained =
            (previous['delayedIndependent'] as int? ?? 0) + (delayed ? 1 : 0);
        final count =
            (previous['independent'] as int? ?? 0) + (independent ? 1 : 0);
        final reviewGap =
            sequence - (previous['lastReviewSequence'] as int? ?? -100);
        final reviewClean =
            hints == 0 &&
            !wrong.contains(word) &&
            givens <= 2 &&
            p.cells
                    .where(
                      (c) =>
                          !level.grid.cellAt(c.$1, c.$2).isGiven &&
                          level.grid.cellAt(c.$1, c.$2).isIntersection,
                    )
                    .length <=
                1;
        final reviewSuccesses =
            (previous['reviewSuccesses'] as int? ?? 0) +
            (reviewClean && reviewGap >= 4 ? 1 : 0);
        words[word] = {
          ...previous,
          if (previous['reviewNeeded'] == true &&
              reviewClean &&
              reviewGap >= 4) ...{
            'reviewSuccesses': reviewSuccesses,
            'reviewNeeded': reviewSuccesses < 2,
            'lastReviewSequence': sequence,
            'reviewDue': time + const Duration(days: 3).inMilliseconds,
          },
          'practices': (previous['practices'] as int? ?? 0) + 1,
          'independent': count,
          'delayedIndependent': retained,
          'lastIndependent': independent ? time : lastIndependent,
          'supported':
              (previous['supported'] as int? ?? 0) + (independent ? 0 : 1),
          'lastSeen': time,
          'due':
              time +
              Duration(
                days: independent ? (retained > 0 ? 7 : 3) : 1,
              ).inMilliseconds,
        };
      }
      session['credited'] = credited.toList();
      data['sessions'] = sessions
          .skip(sessions.length > 40 ? sessions.length - 40 : 0)
          .toList();
      await db.setSetting(key, jsonEncode(data));
    });
  }
}

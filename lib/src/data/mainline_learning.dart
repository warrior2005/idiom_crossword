import 'dart:convert';
import '../engine/grid_engine.dart';
import 'database.dart';

/// 轻量本地观察；题面支持下完成不等同于掌握。保留最近40次题目及词级汇总。
class MainlineLearning {
  static const key = 'mainline_learning_v1';
  static Future<Map<String, dynamic>> read(AppDatabase db) async {
    final raw = await db.getSetting(key);
    return raw == null
        ? {'sessions': <dynamic>[], 'words': <String, dynamic>{}}
        : jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> setPreference(AppDatabase db, int value) async {
    if (value < 0 || value > 2) throw ArgumentError.value(value);
    await db.transaction(() async {
      await db.setSetting('mainline_ability', '$value');
      final data = await read(db);
      data.addAll({
        'windowPreference': value,
        'window': <dynamic>[],
        'offset': 0,
      });
      await db.setSetting(key, jsonEncode(data));
    });
  }

  static Future<int> ability(AppDatabase db) async {
    final preference =
        int.tryParse(await db.getSetting('mainline_ability') ?? '') ?? 0;
    final data = await read(db);
    final offset = data['windowPreference'] == preference
        ? data['offset'] as int? ?? 0
        : 0;
    return (preference + offset).clamp(-1, 2);
  }

  static Future<Set<String>> dueWords(AppDatabase db, {DateTime? now}) async {
    final data = await read(db);
    final time = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final words = data['words'] as Map<String, dynamic>;
    return words.entries
        .where((e) => (e.value['due'] as int) <= time)
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
      final data = await read(db);
      final sessions = (data['sessions'] as List).cast<Map<String, dynamic>>();
      final matching = sessions.where((s) => s['id'] == level.instanceId);
      final session = matching.isEmpty
          ? <String, dynamic>{
              'id': level.instanceId,
              'number': level.levelId,
              'content': level.contentVersion,
              'strategy': level.strategyVersion,
              'support': level.support,
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
      final preference = session['preference'] as int;
      final currentPreference =
          int.tryParse(await db.getSetting('mainline_ability') ?? '') ?? 0;
      if (['complete', 'failed', 'replaced'].contains(status) &&
          preference == currentPreference &&
          session['evaluated'] != true) {
        session['evaluated'] = true;
        if (data['windowPreference'] != preference) {
          data['windowPreference'] = preference;
          data['window'] = <dynamic>[];
          data['offset'] = 0;
        }
        final window = data['window'] as List? ?? <dynamic>[];
        window.add({'status': status, 'hints': hints, 'errors': errors});
        if (window.length >= 5) {
          final struggling = window
              .where(
                (s) =>
                    s['status'] != 'complete' ||
                    s['hints'] >= 2 ||
                    s['errors'] >= 2,
              )
              .length;
          final fluent = window.every(
            (s) =>
                s['status'] == 'complete' &&
                s['hints'] == 0 &&
                s['errors'] == 0,
          );
          final previous = data['offset'] as int? ?? 0;
          data['offset'] =
              (previous +
                      (struggling >= 2
                          ? -1
                          : fluent
                          ? 1
                          : 0))
                  .clamp(-1, 1);
          window.clear();
        }
        data['window'] = window;
      }
      final words = data['words'] as Map<String, dynamic>;
      if (session['exposed'] != true) {
        for (final word in level.idioms.map((i) => i.text)) {
          final previous = words[word] as Map<String, dynamic>? ?? {};
          words[word] = {
            ...previous,
            'exposures': (previous['exposures'] as int? ?? 0) + 1,
            'lastSeen': time,
            'due':
                previous['due'] ??
                time + const Duration(days: 1).inMilliseconds,
          };
        }
        session['exposed'] = true;
      }
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
        words[word] = {
          ...previous,
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

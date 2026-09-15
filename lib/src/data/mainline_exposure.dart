import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'database.dart';
import '../engine/grid_engine.dart';

/// 已展示题永久保留集合指纹；近期词冷却按实际展示顺序，不按通关号。
class MainlineExposure {
  static const key = 'mainline_exposure_v3';
  static final _pending = Expando<Map<String, String>>();
  static String fingerprint(Iterable<String> words) {
    final sorted = words.toList()..sort();
    return sha256.convert(utf8.encode(sorted.join('|'))).toString();
  }

  static Future<Map<String, dynamic>> read(AppDatabase db) async {
    final raw = await db.getSetting(key);
    if (raw != null) return jsonDecode(raw) as Map<String, dynamic>;
    return db.transaction(() async {
      final initialized = await db.getSetting(key);
      if (initialized != null) {
        return jsonDecode(initialized) as Map<String, dynamic>;
      }
      final data = <String, dynamic>{
        'hashes': <String>[],
        'ids': <String>[],
        'recent': <dynamic>[],
        'sequence': 0,
      };
      final history = await db.getLevelHistory();
      final rows = await db.select(db.idioms).get();
      final byId = {for (final r in rows) r.id: r.word};
      history.sort((a, b) => a.completedAt.compareTo(b.completedAt));
      for (final h in history) {
        if (h.levelNumber <= 0 || h.levelNumber >= 1000000) continue;
        final words = h.idiomsUsed
            .split(',')
            .map(int.tryParse)
            .map((id) => byId[id])
            .whereType<String>()
            .toList();
        if (words.isEmpty) continue;
        _append(data, 'legacy_${h.id}', words);
      }
      await db.setSetting(key, jsonEncode(data));
      return data;
    });
  }

  static Set<String> recentWords(Map<String, dynamic> data, [int count = 3]) {
    final recent = data['recent'] as List;
    return recent.reversed
        .take(count)
        .expand((r) => (r['words'] as List).cast<String>())
        .toSet();
  }

  static Set<String> blocked(AppDatabase db, Map<String, dynamic> data) => {
    ...List<String>.from(data['hashes'] as List),
    ...?_pending[db]?.keys,
  };

  /// 同进程生成中的候选也不重复；未展示的候选不写入永久曝光历史。
  static Future<bool> reserve(AppDatabase db, CrosswordLevel level) =>
      db.transaction(() async {
        final hash = fingerprint(level.idioms.map((i) => i.text));
        final data = await read(db);
        final pending = _pending[db] ??= {};
        if ((data['hashes'] as List).contains(hash) ||
            pending.containsKey(hash)) {
          return false;
        }
        pending[hash] = level.instanceId!;
        return true;
      });

  static Future<void> show(AppDatabase db, CrosswordLevel level) async {
    if (level.instanceId == null ||
        level.levelId <= 0 ||
        level.levelId >= 1000000) {
      return;
    }
    final data = await read(db);
    final words = level.idioms.map((i) => i.text).toList();
    final hash = fingerprint(words);
    _pending[db]?.remove(hash);
    if ((data['ids'] as List).contains(level.instanceId) ||
        (data['hashes'] as List).contains(hash)) {
      return;
    }
    _append(data, level.instanceId!, words);
    await db.setSetting(key, jsonEncode(data));
    _pending[db]?.remove(fingerprint(words));
  }

  static void _append(
    Map<String, dynamic> data,
    String id,
    List<String> words,
  ) {
    final hashes = Set<String>.from(data['hashes'] as List)
      ..add(fingerprint(words));
    (data['ids'] as List).add(id);
    data['hashes'] = hashes.toList();
    final recent = data['recent'] as List;
    recent.add({'id': id, 'words': words});
    if (recent.length > 40) recent.removeAt(0);
    data['sequence'] = (data['sequence'] as int) + 1;
  }
}

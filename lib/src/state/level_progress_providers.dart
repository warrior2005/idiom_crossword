import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';
import 'level_generation.dart';
import 'level_state_codec.dart';
import 'player_state.dart';

/// 已通关关卡集合
final completedLevelsProvider = FutureProvider<Set<int>>((ref) async {
  ref.watch(playerProvider);
  final db = ref.watch(databaseProvider);
  return db.getCompletedLevelNumbers();
});

/// 主线各关首个成语（从冻结关卡定义读取，用于关卡方块小字）
final levelWordsProvider = FutureProvider<Map<int, String>>((ref) async {
  final db = ref.watch(databaseProvider);
  final history = await db.getLevelHistory();
  final words = <int, String>{};
  final missing = <int, int>{}; // 关卡号 -> 第一个成语 id
  for (final h in history) {
    if (h.levelNumber >= dailyLevelOffset) continue;
    if (h.levelJson != null) {
      final level = decodeLevel(h.levelJson!);
      if (level != null && level.placements.isNotEmpty) {
        words[h.levelNumber] = level.placements.first.idiom.text;
        continue;
      }
    }
    final firstId = _firstIdiomId(h.idiomsUsed);
    if (firstId != null && firstId > 0) {
      missing[h.levelNumber] = firstId;
    }
  }
  if (missing.isNotEmpty) {
    final rows = await db.findIdiomsByIds(missing.values.toList());
    final byId = {for (final row in rows) row.id: row.word};
    for (final entry in missing.entries) {
      final word = byId[entry.value];
      if (word != null) words[entry.key] = word;
    }
  }
  return words;
});

int? _firstIdiomId(String raw) {
  final cleaned = raw.trim().replaceAll(RegExp(r'[\[\]"]'), '');
  if (cleaned.isEmpty) return null;
  return int.tryParse(cleaned.split(',').first.trim());
}

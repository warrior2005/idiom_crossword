// flutter test --no-pub tool/mainline_repeat_audit_test.dart --reporter expanded
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/mainline_learning.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('固定能力连续生成：整组、布局与局部重复抽样', () async {
    final results = <Map<String, dynamic>>[];
    final output = File('build/mainline-repeat-audit.json');
    await output.parent.create(recursive: true);
    for (final step in [-5, 0, 15, 30]) {
      final dir = await Directory.systemTemp.createTemp('repeat_audit_');
      final file = await File(
        'assets/data/idiom_crossword.db',
      ).copy('${dir.path}/db.sqlite');
      final db = AppDatabase(NativeDatabase(file));
      final wordKeys = <String, int>{}, layoutKeys = <String, int>{};
      final previousWords = <Set<String>>[];
      final seenWords = <String>{};
      var setRepeats = 0, layoutRepeats = 0, nearRepeats = 0, halfRepeats = 0;
      var reusedWords = 0, totalWords = 0, failures = 0;
      final levels = <Map<String, dynamic>>[];
      try {
        for (var n = 1; n <= 200; n++) {
          final data = await MainlineLearning.read(db);
          data['adaptive'] = {'step': step}; // 隔离能力推进，其他学习与通关历史照常累积。
          await db.setSetting(MainlineLearning.key, jsonEncode(data));
          final level = await generateLevel(db, 1000 + n);
          if (level == null) {
            failures++;
            continue;
          }
          final words = level.idioms.map((i) => i.text).toSet();
          final sorted = words.toList()..sort();
          final wordKey = sorted.join('|');
          final layouts =
              level.placements
                  .map(
                    (p) =>
                        '${p.idiom.text}:${p.startRow},${p.startCol}:${p.direction.index}',
                  )
                  .toList()
                ..sort();
          final layoutKey = layouts.join('|');
          final earlierSet = wordKeys[wordKey],
              earlierLayout = layoutKeys[layoutKey];
          if (earlierSet != null) setRepeats++;
          if (earlierLayout != null) layoutRepeats++;
          var maxOverlap = 0;
          for (final prior in previousWords) {
            final overlap = words.intersection(prior).length;
            if (overlap > maxOverlap) maxOverlap = overlap;
          }
          if (maxOverlap >= words.length - 1) nearRepeats++;
          if (maxOverlap >= (words.length / 2).ceil()) halfRepeats++;
          reusedWords += words.intersection(seenWords).length;
          totalWords += words.length;
          levels.add({
            'n': n,
            'words': sorted,
            'layout': layouts,
            'previousSameWords': earlierSet,
            'previousSameLayout': earlierLayout,
            'maxOverlap': maxOverlap,
            'newWords': words.difference(seenWords).length,
          });
          wordKeys.putIfAbsent(wordKey, () => n);
          layoutKeys.putIfAbsent(layoutKey, () => n);
          previousWords.add(words);
          seenWords.addAll(words);
          await MainlineLearning.record(
            db,
            level,
            status: 'complete',
            hints: 0,
            errors: 0,
            completed: words,
          );
          final ids = await db.findIdiomIdsByWords(words.toList());
          await db.addLevelHistory(
            levelNumber: level.levelId,
            xpGained: 0,
            idiomsUsed: ids.values.toList(),
          );
          if (n % 50 == 0) {
            // ignore: avoid_print
            print(
              'step=$step n=$n sets=$setRepeats layouts=$layoutRepeats near=$nearRepeats half=$halfRepeats uniqueWords=${seenWords.length}',
            );
          }
        }
        results.add({
          'step': step,
          'attempted': 200,
          'generated': levels.length,
          'failed': failures,
          'sameWordSets': setRepeats,
          'sameLayouts': layoutRepeats,
          'allButOneOverlap': nearRepeats,
          'atLeastHalfOverlap': halfRepeats,
          'uniqueWords': seenWords.length,
          'reusedWords': reusedWords,
          'totalWords': totalWords,
          'levels': levels,
        });
        await output.writeAsString(
          const JsonEncoder.withIndent('  ').convert(results),
        );
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}

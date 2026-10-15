import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/adaptive_learning.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/mainline_learning.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';
import 'package:idiom_crossword/src/state/level_state_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('熟悉记录及旧陌生词预算不改变八词普通选词与题面', () async {
    final dir = await Directory.systemTemp.createTemp('selection_neutral_');
    const seeds = [17, 29, 881];
    final results = {for (final seed in seeds) seed: <Map<String, dynamic>>[]};
    try {
      for (final familiar in [false, true]) {
        final file = await File(
          'assets/data/idiom_crossword.db',
        ).copy('${dir.path}/$familiar.db');
        final db = AppDatabase(NativeDatabase(file));
        try {
          final catalog = await db.select(db.idioms).get();
          for (final seed in seeds) {
            final data = <String, dynamic>{
              'sessions': [],
              'words': {},
              'adaptive': {'step': 10},
            };
            await MainlineLearning.prepareAdaptive(db, data);
            data['adaptiveV4']['tier'] = 3;
            data['adaptiveV4']['mix'] = [...AdaptiveLearning.mixes[2]];
            data['words'] = {
              for (final row in catalog)
                row.word: {
                  'supported': familiar ? 3 : 0,
                  'reviewNeeded': false,
                },
            };
            if (familiar) {
              // A frozen previous policy cannot keep forcing familiar words after upgrade.
              data['sessions'] = [
                {
                  'strategy': 4,
                  'number': 300 + seed - 1,
                  'policy': {'unfamiliar': 0, 'noveltyBudget': 0},
                },
              ];
            }
            await db.setSetting(MainlineLearning.key, jsonEncode(data));
            final level = await generateLevel(db, 300 + seed, seed: seed);
            expect(level, isNotNull, reason: 'familiar=$familiar seed=$seed');
            expect(level!.idioms.length, 8);
            expect(level.strategy.containsKey('noveltyBudget'), isFalse);
            final encoded =
                jsonDecode(encodeLevel(level)) as Map<String, dynamic>;
            encoded.remove('instanceId');
            (encoded['strategy'] as Map).remove('unfamiliar');
            results[seed]!.add(encoded);
          }
        } finally {
          await db.close();
        }
      }
      for (final seed in seeds) {
        expect(results[seed]![1], results[seed]![0], reason: 'seed $seed');
      }
    } finally {
      await dir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}

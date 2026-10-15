// flutter test --no-pub tool/mainline_word_repeat_audit_test.dart --reporter expanded
// Synthetic learning states; never opens or changes a player's installed database.
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/adaptive_learning.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/mainline_exposure.dart';
import 'package:idiom_crossword/src/data/mainline_learning.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';

const reportedWords = [
  '山高月小',
  '名高天下',
  '鱼水深情',
  '不近人情',
  '地老天荒',
  '终其天年',
  '无言可对',
  '积水成渊',
  '话不相投',
  '死灰复燃',
  '万古千秋',
  '不痴不聋',
  '干将莫邪',
  '可有可无',
  '相与为一',
  '言行相顾',
  '不顾大局',
  '五谷丰登',
  '大难临头',
  '起死回生',
  '大地春回',
  '一字一板',
  '闻风而起',
  '统而言之',
  '人仰马翻',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final count = int.parse(Platform.environment['REPEAT_AUDIT_COUNT'] ?? '60');
  final step = int.parse(Platform.environment['REPEAT_AUDIT_STEP'] ?? '10');
  final profiles =
      (Platform.environment['REPEAT_AUDIT_PROFILES'] ??
              'closed_unfamiliar,closed_familiar,open_unfamiliar,open_familiar')
          .split(',');
  final output = Directory(
    Platform.environment['REPEAT_AUDIT_OUTPUT'] ??
        'build/word-repeat-fix-2026-10-15/step$step',
  );
  final summaries = <Map<String, dynamic>>[];
  for (final profile in profiles) {
    test('current word repeat mechanism: $profile', () async {
      await output.create(recursive: true);
      final dir = await Directory.systemTemp.createTemp('word_repeat_');
      final file = await File(
        'assets/data/idiom_crossword.db',
      ).copy('${dir.path}/db');
      final db = AppDatabase(NativeDatabase(file));
      final familiar = profile.endsWith('_familiar');
      final open = profile.startsWith('open_');
      final levels = <Map<String, dynamic>>[];
      final stats = <String, Map<String, dynamic>>{
        for (final w in reportedWords)
          w: {
            'samples': <int>[],
            'ordinary': 0,
            'intentionalReview': 0,
            'givens': <int>[0, 0, 0, 0, 0],
            'queueTransitions': <dynamic>[],
          },
      };
      var failures = 0, allWords = 0, knownUsed = 0, reviewWords = 0;
      final cooldown = <Set<String>>[];
      final fingerprints = <String>{};
      try {
        final initial = await MainlineLearning.read(db);
        await MainlineLearning.prepareAdaptive(db, initial);
        final intro = await (db.select(
          db.idioms,
        )..where((t) => t.difficultyTier.equals(1))).get();
        initial['words'] = {
          for (final w in [
            ...reportedWords,
            ...intro.take(60).map((w) => w.word),
          ])
            w: {
              'supported': familiar ? 3 : 0,
              'independent': 0,
              'reviewNeeded': open && reportedWords.contains(w),
              'reviewSuccesses': open && reportedWords.contains(w) ? 0 : 2,
              'reviewSignals': 1,
              'reviewDue': 0,
              'seenSequence': -100,
            },
        };
        await db.setSetting(MainlineLearning.key, jsonEncode(initial));
        for (var n = 1; n <= count; n++) {
          // Isolate repetition at one current difficulty, while keeping real learning/exposure.
          final before = await MainlineLearning.read(db);
          before['adaptive'] = {'step': step};
          before['adaptiveV4']['tier'] = 3;
          before['adaptiveV4']['mix'] = [...AdaptiveLearning.mixes[2]];
          before['adaptiveV4']['normalizing'] = false;
          before['adaptiveV4']['migrationRemaining'] = 0;
          await db.setSetting(MainlineLearning.key, jsonEncode(before));
          final known = await MainlineLearning.familiarWords(db);
          final now = DateTime(2026, 10, 15, 10).add(Duration(minutes: n * 2));
          final level = await generateLevel(
            db,
            300 + n,
            seed: 151000 + n,
            now: now,
          );
          if (level == null) {
            failures++;
            break;
          }
          final words = level.idioms.map((w) => w.text).toSet();
          expect(fingerprints.add(MainlineExposure.fingerprint(words)), isTrue);
          for (final previous in cooldown.reversed.take(3)) {
            expect(words.intersection(previous), isEmpty);
          }
          cooldown.add(words);
          final intentional = Set<String>.from(
            level.strategy['reviewWords'] as List,
          );
          allWords += words.length;
          knownUsed += words.intersection(known).length;
          reviewWords += intentional.length;
          for (final p in level.placements) {
            if (!stats.containsKey(p.idiom.text)) continue;
            final s = stats[p.idiom.text]!;
            (s['samples'] as List).add(n);
            final given = p.cells
                .where((c) => level.grid.cellAt(c.$1, c.$2).isGiven)
                .length;
            (s['givens'] as List)[given]++;
            final key = intentional.contains(p.idiom.text)
                ? 'intentionalReview'
                : 'ordinary';
            s[key] = (s[key] as int) + 1;
            if (((before['words'] as Map)[p.idiom.text]
                    as Map?)?['reviewNeeded'] !=
                true) {
              s['afterExit'] = (s['afterExit'] as int? ?? 0) + 1;
            }
          }
          await MainlineLearning.record(
            db,
            level,
            status: 'complete',
            hints: 0,
            errors: 0,
            wrong: {},
            hinted: {},
            completed: words,
            now: now,
            activeTimeMs: level.fillableCells * 5000,
          );
          final after = await MainlineLearning.read(db);
          for (final w in words.where(stats.containsKey)) {
            final old = (before['words'] as Map)[w] as Map? ?? {};
            final updated = (after['words'] as Map)[w] as Map;
            if (old['reviewNeeded'] != updated['reviewNeeded'] ||
                old['reviewSuccesses'] != updated['reviewSuccesses']) {
              (stats[w]!['queueTransitions'] as List).add({
                'sample': n,
                'reviewNeeded': updated['reviewNeeded'],
                'successes': updated['reviewSuccesses'],
              });
            }
          }
          levels.add({
            'sample': n,
            'words': words.toList(),
            'policy': level.strategy,
          });
        }
        final after = await MainlineLearning.read(db);
        var reportedAppearances = 0, tripleGiven = 0, stillQueued = 0;
        for (final w in reportedWords) {
          final s = stats[w]!;
          final state = (after['words'] as Map)[w];
          s['finalReviewNeeded'] = state['reviewNeeded'];
          s['finalReviewSuccesses'] = state['reviewSuccesses'];
          reportedAppearances += (s['samples'] as List).length;
          tripleGiven += (s['givens'] as List)[3] as int;
          if (state['reviewNeeded'] == true) stillQueued++;
        }
        final summary = <String, dynamic>{
          'profile': profile,
          'step': step,
          'attempted': levels.length + failures,
          'generated': levels.length,
          'failures': failures,
          'allWords': allWords,
          'knownWordsUsed': knownUsed,
          'intentionalReviews': reviewWords,
          'reportedAppearances': reportedAppearances,
          'reportedTripleGiven': tripleGiven,
          'reportedStillQueued': stillQueued,
          'words': stats,
        };
        summaries.add(summary);
        await File('${output.path}/$profile.json').writeAsString(
          const JsonEncoder.withIndent(
            '  ',
          ).convert({...summary, 'levels': levels}),
        );
        await File(
          '${output.path}/summary.json',
        ).writeAsString(const JsonEncoder.withIndent('  ').convert(summaries));
        // ignore: avoid_print
        print(jsonEncode({...summary}..remove('words')));
        expect(
          failures,
          0,
          reason: 'No retry or skipped failed level in audit',
        );
        expect(levels.length, count);
        if (!open && count >= 60) {
          expect(
            reportedAppearances,
            lessThan(count),
            reason: 'The reported 25 words must not dominate ordinary sampling',
          );
          for (final s in stats.values) {
            expect(
              (s['samples'] as List).length,
              lessThan(6),
              reason:
                  'No reported ordinary word should keep circling in this fixed trajectory',
            );
          }
        }
        for (final w in reportedWords) {
          final cleanCompletions = (stats[w]!['samples'] as List).length;
          if (open && cleanCompletions >= 2) {
            expect(
              stats[w]!['finalReviewNeeded'],
              isFalse,
              reason:
                  'Two spaced correct completions must exit even with three givens: $w',
            );
          }
        }
        final paired = summaries
            .where(
              (s) => (s['profile'] as String).startsWith(
                open ? 'open_' : 'closed_',
              ),
            )
            .toList();
        if (paired.length == 2) {
          expect(
            paired[0]['reportedAppearances'],
            paired[1]['reportedAppearances'],
          );
          for (final w in reportedWords) {
            expect(
              (paired[0]['words'] as Map)[w]['samples'],
              (paired[1]['words'] as Map)[w]['samples'],
              reason: 'Familiarity must not affect $w',
            );
          }
        }
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(minutes: 4)));
  }
}

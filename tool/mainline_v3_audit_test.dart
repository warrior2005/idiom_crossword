// AUDIT_COUNT=1000 AUDIT_PROFILES=intro,basic,expansion,rare,fast,weak flutter test --no-pub tool/mainline_v3_audit_test.dart --reporter expanded
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/mainline_learning.dart';
import 'package:idiom_crossword/src/data/mainline_exposure.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final count = int.parse(Platform.environment['AUDIT_COUNT'] ?? '1000');
  final profiles =
      (Platform.environment['AUDIT_PROFILES'] ??
              'intro,basic,expansion,rare,fast,weak')
          .split(',');
  final output = File(
    Platform.environment['AUDIT_OUTPUT'] ?? 'build/mainline-v3-audit.json',
  );
  final results = <Map<String, dynamic>>[];
  for (final profile in profiles) {
    test('v3连续轨迹 $profile', () async {
      final dir = await Directory.systemTemp.createTemp('v3_audit_');
      final file = await File(
        'assets/data/idiom_crossword.db',
      ).copy('${dir.path}/db');
      final db = AppDatabase(NativeDatabase(file));
      final sets = <Set<String>>[], seen = <String>{}, hashes = <String>{};
      final frequency = <String, int>{},
          durations = <int>[],
          stages = <String, int>{};
      final levels = <Map<String, dynamic>>[];
      var failed = 0,
          stuck = 0,
          halfRecent = 0,
          allOld = 0,
          reviews = 0,
          fallback = 0,
          requests = 0;
      Map<String, dynamic>? prior;
      try {
        for (var n = 1; n <= count; n++) {
          final data = await MainlineLearning.read(db);
          if (['intro', 'basic', 'expansion', 'rare'].contains(profile)) {
            final tier = {
              'intro': 1,
              'basic': 2,
              'expansion': 3,
              'rare': 4,
            }[profile]!;
            data['progression'] = {
              'tier': tier,
              'next': profile == 'expansion' ? 1 : 0,
            };
            data['adaptive'] = {
              'step': tier <= 2
                  ? 0
                  : tier == 3
                  ? 15
                  : 30,
            };
            await db.setSetting(MainlineLearning.key, jsonEncode(data));
          }
          if (profile == 'recovery' && n == 1) {
            data['progression'] = {'tier': 3, 'next': 0};
            data['adaptive'] = {'step': 15};
            await db.setSetting(MainlineLearning.key, jsonEncode(data));
          }
          final number = ['fast', 'weak'].contains(profile) ? n : 1000 + n;
          final now = DateTime(2026, 9, 14).add(Duration(minutes: n * 90));
          dynamic level;
          var lastSeed = 0;
          for (var retry = 0; retry < 3; retry++) {
            final watch = Stopwatch()..start();
            lastSeed = 130000 + n * 11 + retry;
            level = await generateLevel(db, number, seed: lastSeed, now: now);
            durations.add(watch.elapsedMilliseconds);
            requests++;
            if (level != null) break;
            failed++;
          }
          if (level == null) {
            stuck++;
            await File(
              'build/v3-failure-$profile.json',
            ).writeAsString(jsonEncode(await MainlineLearning.read(db)));
            await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
            await file.copy('build/v3-failure-$profile.db');
            break;
          }
          if (Platform.environment['AUDIT_SNAPSHOT_AT'] == '$n') {
            await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
            await file.copy('build/v3-snapshot-$profile-$n.db');
            await File('build/v3-snapshot-$profile-$n.json').writeAsString(
              jsonEncode({
                'number': number,
                'seed': lastSeed,
                'now': now.toIso8601String(),
              }),
            );
          }
          final words = Set<String>.from(
            level.idioms.map((dynamic i) => i.text),
          );
          final strategy = Map<String, dynamic>.from(level.strategy);
          final hash = MainlineExposure.fingerprint(words);
          expect(hashes.add(hash), isTrue, reason: 'same group $profile/$n');
          expect(
            (strategy['reviewWords'] as List).length,
            lessThanOrEqualTo(2),
          );
          for (final earlier in sets.reversed.take(3)) {
            expect(
              words.intersection(earlier),
              isEmpty,
              reason: 'recent cooldown $profile/$n',
            );
          }
          if (number > 10) expect(words.length, inInclusiveRange(6, 12));
          expect(
            (strategy['candidates'] as int) - (strategy['answers'] as int),
            greaterThanOrEqualTo(4),
          );
          final tier = strategy['tier'] as int;
          expect(
            (strategy['wordTiers'] as Map).values.every(
              (dynamic t) => t <= tier + 1,
            ),
            isTrue,
          );
          if (prior != null) {
            expect(
              ((strategy['unfamiliar'] as int) - (prior['unfamiliar'] as int))
                  .abs(),
              lessThanOrEqualTo(2),
            );
            expect(
              ((strategy['answers'] as int) - (prior['answers'] as int)).abs(),
              lessThanOrEqualTo(3),
            );
            expect(
              ((strategy['candidates'] as int) - (prior['candidates'] as int))
                  .abs(),
              lessThanOrEqualTo(5),
            );
          }
          prior = strategy;
          var overlap = 0;
          for (final earlier in sets.reversed.take(20)) {
            final v = words.intersection(earlier).length;
            if (v > overlap) overlap = v;
          }
          if (overlap >= (words.length / 2).ceil()) halfRecent++;
          final newWords = words.difference(seen).length;
          if (newWords == 0) allOld++;
          for (final w in words) {
            frequency.update(w, (v) => v + 1, ifAbsent: () => 1);
          }
          final review = List<String>.from(strategy['reviewWords'] as List);
          reviews += review.length;
          fallback += (strategy['reviewReasons'] as Map).values
              .where((v) => v == 'fallback')
              .length;
          stages.putIfAbsent('$tier', () => n);
          sets.add(words);
          seen.addAll(words);
          final wrong =
              (profile == 'weak' && n % 3 == 0) ||
                  (profile == 'recovery' && n > 40)
              ? words.take(1).toSet()
              : <String>{};
          final failedPlay =
              (profile == 'weak' && n % 4 == 0) ||
              (profile == 'recovery' && n > 40);
          await MainlineLearning.record(
            db,
            level,
            status: failedPlay ? 'failed' : 'complete',
            hints: wrong.isEmpty ? 0 : 1,
            errors: wrong.length,
            wrong: wrong,
            completed: failedPlay ? words.take(words.length ~/ 2) : words,
            now: now,
          );
          final ids = await db.findIdiomIdsByWords(words.toList());
          if (!failedPlay) {
            await db.addLevelHistory(
              levelNumber: number,
              xpGained: 0,
              idiomsUsed: ids.values.toList(),
            );
          }
          levels.add({
            'n': n,
            'words': words.toList(),
            'new': newWords,
            'overlap20': overlap,
            'policy': strategy,
            'milliseconds': durations.last,
          });
          if (n % 50 == 0) {
            // ignore: avoid_print
            print(
              '$profile n=$n failed=$failed half20=$halfRecent unique=${seen.length} tier=$tier reviews=$reviews fallback=$fallback',
            );
          }
        }
        durations.sort();
        final tops = frequency.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final result = <String, dynamic>{
          'profile': profile,
          'target': count,
          'generated': levels.length,
          'requests': requests,
          'failedRequests': failed,
          'stuck': stuck,
          'sameSets': 0,
          'halfRecent20': halfRecent,
          'uniqueWords': seen.length,
          'allOld': allOld,
          'reviewWords': reviews,
          'fallbackWords': fallback,
          'firstTier': stages,
          'p50ms': durations[durations.length ~/ 2],
          'p95ms':
              durations[(durations.length * .95).floor().clamp(
                0,
                durations.length - 1,
              )],
          'maxms': durations.last,
          'topWords': {for (final e in tops.take(10)) e.key: e.value},
          'levels': levels,
        };
        results.add(result);
        await output.parent.create(recursive: true);
        await output.writeAsString(
          const JsonEncoder.withIndent('  ').convert(results),
        );
        if (profile == 'recovery' && count >= 300) {
          expect(levels.last['policy']['tier'], 1);
          expect(levels.last['policy']['size'], 6);
          expect(levels.last['policy']['step'], -5);
        }
        expect(stuck, 0);
        expect(levels.length, count);
        expect(
          failed / requests,
          lessThanOrEqualTo(.001),
          reason: '单次请求失败率必须<=0.1%',
        );
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(minutes: 45)));
  }
}

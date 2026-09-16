import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:idiom_crossword/src/data/mainline_learning.dart';
import 'package:idiom_crossword/src/engine/adaptive_policy.dart';
import 'package:idiom_crossword/src/engine/distractor_engine.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';
import 'package:idiom_crossword/src/state/level_state_codec.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('真实资产：前期、后期和等级切换都满足成品准入与配额', () async {
    final dir = await Directory.systemTemp.createTemp('mainline_');
    final file = await File(
      'assets/data/idiom_crossword.db',
    ).copy('${dir.path}/test.db');
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    for (final step in [0, 15, 30]) {
      await db.setSetting(
        MainlineLearning.key,
        jsonEncode({
          'sessions': [],
          'words': {},
          'adaptive': {'step': step},
          'progression': {
            'tier': step == 30
                ? 3
                : step == 15
                ? 2
                : 1,
            'next': step == 30 ? 1 : 0,
          },
        }),
      );
      for (final number in [1, 10, 11, 200, 6000]) {
        final level = await generateLevel(db, number, seed: 17);
        expect(level, isNotNull, reason: 'number $number step $step');
        final policy = AdaptivePolicy(
          number,
          step,
          tier: step == 30
              ? 3
              : step == 15
              ? 2
              : 1,
          nextCount: step == 30 ? 1 : 0,
        );
        expect(level!.idioms.length, policy.size);
        if (number > 10) expect(level.idioms.length, inInclusiveRange(6, 12));
        expect(
          level.fillableCells,
          inInclusiveRange(policy.answerTarget - 2, policy.answerTarget),
        );
        expect(
          level.initialCandidates!.expand((r) => r).length,
          policy.candidateCount(level.fillableCells),
        );
        expect(
          level.initialCandidates!.expand((r) => r).length -
              level.fillableCells,
          greaterThanOrEqualTo(4),
        );
        expect(
          decodeLevel(encodeLevel(level))!.initialCandidates,
          level.initialCandidates,
        );
        expect(decodeLevel(encodeLevel(level))!.strategy, level.strategy);
        final tiers = Map<String, int>.from(level.strategy['wordTiers'] as Map);
        expect(policy.accepts(level.idioms, tiers), isTrue);
        expect(level.strategyVersion, 3);
        expect(level.contentVersion, 6);
        if (step == 30 && number > 10) expect(tiers.values, contains(4));
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('大量薄弱词不会把普通词池排空；主动复习最多两个', () async {
    final dir = await Directory.systemTemp.createTemp('review_pool_');
    final file = await File(
      'assets/data/idiom_crossword.db',
    ).copy('${dir.path}/test.db');
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    final rows = await (db.select(
      db.idioms,
    )..where((t) => t.difficultyTier.equals(1))).get();
    await db.setSetting(
      MainlineLearning.key,
      jsonEncode({
        'sessions': [],
        'words': {
          for (final r in rows)
            r.word: {'reviewNeeded': true, 'reviewDue': 0, 'seenSequence': -10},
        },
      }),
    );
    final level = await generateLevel(db, 11, seed: 881);
    expect(level, isNotNull);
    expect(
      (level!.strategy['reviewWords'] as List).length,
      lessThanOrEqualTo(2),
    );
    expect(
      (level.strategy['incidentalWeakWords'] as List).length,
      greaterThanOrEqualTo(4),
    );
  });

  test('每日冻结旧词集合；历史题面不随新增字典重做消歧', () async {
    final dir = await Directory.systemTemp.createTemp('daily_cohort_');
    final file = await File(
      'assets/data/idiom_crossword.db',
    ).copy('${dir.path}/test.db');
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    final all = await db.findIdiomWordsMatchingPatterns(['漫天风雪']);
    final legacy = await db.findIdiomWordsMatchingPatterns([
      '漫天风雪',
    ], legacyOnly: true);
    expect(all, ['漫天风雪']);
    expect(legacy, isEmpty);
    Future<String> daily() async => encodeLevel(
      (await generateLevel(
        db,
        dailyLevelOffset + 20454,
        seed: 20454,
        targetSize: 12,
        difficultyRange: (1, 50),
      ))!,
    );
    final expanded = await daily();
    await db.customStatement(
      'DELETE FROM idiom_char_index WHERE idiom_id > 29502',
    );
    await db.customStatement('DELETE FROM idioms WHERE id > 29502');
    expect(await daily(), expanded);
    final generated = (await generateLevel(db, 11, seed: 17))!;
    final encoded = encodeLevel(generated);
    await db.addLevelHistory(
      levelNumber: 11,
      xpGained: 0,
      idiomsUsed: [],
      levelJson: encoded,
    );
    await db.setSetting(
      MainlineLearning.key,
      jsonEncode({
        'sessions': [],
        'words': {},
        'adaptive': {'step': 30},
      }),
    );
    expect(encodeLevel((await loadOrGenerateLevel(db, 11))!), encoded);
    final future = jsonDecode(encoded) as Map<String, dynamic>;
    future['contentVersion'] = 2;
    expect(decodeLevel(jsonEncode(future)), isNotNull);
    future['contentVersion'] = 7;
    expect(decodeLevel(jsonEncode(future)), isNull);
    future['contentVersion'] = 3;
    expect(decodeLevel(jsonEncode(future)), isNotNull);
    future['contentVersion'] = 4;
    future['strategyVersion'] = 99;
    expect(decodeLevel(jsonEncode(future)), isNull);
  });

  test('稀疏词库不能回退为不足六词的普通关卡', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final word in ['十全十美', '五光十色']) {
      await db
          .into(db.idioms)
          .insert(
            IdiomsCompanion.insert(
              word: word,
              pinyin: 'a b c d',
              pinyinAbbr: 'abcd',
              explanation: '测试',
              firstChar: word[0],
              lastChar: word[3],
              difficulty: 1,
              difficultyTier: const Value(1),
              isReviewed: Value(word == '十全十美'),
            ),
          );
    }
    final calibration = await generateLevel(db, 1, seed: 17);
    expect(
      calibration!.idioms.map((i) => i.text),
      containsAll(['十全十美', '五光十色']),
    );
    expect(await generateLevel(db, 11, seed: 17), isNull);
  });

  test('可变候选盘保留重复答案及不完整末行，不硬补到40字', () {
    final engine = DistractorEngine();
    final answers = ['人', '人', '天', '地'];
    final board = engine.generateCandidateBoard(
      correctAnswers: answers,
      countPerRow: 10,
      totalCount: 13,
    );
    expect(board.map((r) => r.length), [10, 3]);
    expect(board.expand((r) => r).where((c) => c == '人').length, 2);
    expect(board.expand((r) => r), containsAll(answers));
    expect(
      () =>
          engine.generateCandidateBoard(correctAnswers: answers, totalCount: 3),
      throwsArgumentError,
    );
    final filtered = engine
        .generateCandidateBoard(
          correctAnswers: ['色'],
          totalCount: 3,
          databaseRelatedCandidates: {
            '色': ['穑'],
          },
          allowedDistractorChars: {'天', '人', '地', '山', '水'},
        )
        .expand((r) => r);
    expect(filtered, isNot(contains('穑')));
    expect(filtered, isNot(contains('?')));
    expect(AdaptivePolicy(1, 0).candidateCount(4), 8);
    expect(AdaptivePolicy(11, 30).candidateCount(20), 36);
  });
}

import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/mainline_content.dart';
import 'package:idiom_crossword/src/engine/mainline_policy.dart';
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
    final content = await MainlineContent.load();
    for (final number in [1, 5, 6, 20, 21, 50, 51, 200, 201, 6000, 10001]) {
      for (final seed in [1, 17, 42]) {
        final level = await generateLevel(
          db,
          number,
          seed: seed,
          playerLevel: 21,
          globalRange: true,
        );
        expect(level, isNotNull, reason: 'level $number seed $seed');
        final policy = MainlinePolicy.forLevel(number);
        expect(
          level!.idioms.every(
            (i) =>
                content.foundation.contains(i.text) ||
                content.expansion.contains(i.text),
          ),
          isTrue,
        );
        expect(
          hasMainlineRoute(level, content.foundation, policy.expansionLimit),
          isTrue,
        );
        expect(level.fillableCells, greaterThan(0));
        if (number <= 20) {
          expect(
            level.idioms.every((i) => content.intro.contains(i.text)),
            isTrue,
          );
        }
        expect(
          level.placements.every(
            (p) => p.cells.any((c) => !level.grid.cellAt(c.$1, c.$2).isGiven),
          ),
          isTrue,
        );
        expect(level.placements.length, lessThanOrEqualTo(policy.size));
        expect(level.support, policy.support);
        expect(decodeLevel(encodeLevel(level))!.support, level.support);
        expect(
          decodeLevel(encodeLevel(level))!.contentVersion,
          content.version,
        );
      }
    }
  });

  test('稀疏准入池仍能生成两词题', () async {
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
            ),
          );
    }
    for (final seed in [1, 17, 42]) {
      expect(await generateLevel(db, 1, seed: seed), isNotNull);
    }
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
    expect(MainlinePolicy.candidateCount(4, 2, 3), 6);
    expect(MainlinePolicy.candidateCount(4, 2, 1), greaterThan(6));
  });
}

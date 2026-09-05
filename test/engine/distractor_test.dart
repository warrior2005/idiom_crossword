import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/distractor_engine.dart';

void main() {
  group('DistractorEngine.generateCandidateBoard', () {
    const answers = ['画', '蛇', '添', '足', '守', '株', '待', '兔'];

    test('干扰位按一半相关、一半随机组成', () {
      final board = DistractorEngine(random: Random(42)).generateCandidateBoard(
        correctAnswers: answers,
        rows: 3,
        countPerRow: 8,
      );

      final candidates = board.expand((row) => row).toList();
      final distractors = candidates
          .where((char) => !answers.contains(char))
          .toList();
      final relatedChars = _relatedCharsFor(answers);

      expect(candidates, hasLength(24));
      expect(distractors, hasLength(16));
      expect(distractors.where(relatedChars.contains), hasLength(8));
      expect(
        distractors.where((char) => !relatedChars.contains(char)),
        hasLength(8),
      );
    });

    test('干扰位为奇数时随机字多一个', () {
      const oddAnswers = ['画', '蛇', '添'];
      final candidates = DistractorEngine(random: Random(7))
          .generateCandidateBoard(
            correctAnswers: oddAnswers,
            rows: 1,
            countPerRow: 10,
          )
          .single;
      final distractors = candidates
          .where((char) => !oddAnswers.contains(char))
          .toList();
      final relatedChars = _relatedCharsFor(oddAnswers);

      expect(distractors, hasLength(7));
      expect(distractors.where(relatedChars.contains), hasLength(3));
      expect(
        distractors.where((char) => !relatedChars.contains(char)),
        hasLength(4),
      );
    });

    test('相关候选不足时用随机字补足', () {
      final candidates = DistractorEngine(random: Random(9))
          .generateCandidateBoard(
            correctAnswers: const ['龘'],
            rows: 1,
            countPerRow: 6,
          )
          .single;

      expect(candidates, hasLength(6));
      expect(candidates, contains('龘'));
      expect(candidates, isNot(contains('?')));
      expect(candidates.toSet(), hasLength(6));
    });

    test('使用数据库相关候选组成相关配额', () {
      const databaseCandidates = ['甲', '乙', '丙', '丁', '戊', '己', '庚', '辛'];
      final candidates = DistractorEngine(random: Random(13))
          .generateCandidateBoard(
            correctAnswers: const ['龘'],
            rows: 1,
            countPerRow: 9,
            databaseRelatedCandidates: const {'龘': databaseCandidates},
          )
          .single;

      expect(candidates.where(databaseCandidates.contains), hasLength(4));
    });

    test('保留每个待填字的实际数量，干扰字不重复', () {
      const duplicateAnswers = ['一', '一', '海', '海', '山', '水'];
      final candidates = DistractorEngine(random: Random(11))
          .generateCandidateBoard(
            correctAnswers: duplicateAnswers,
            rows: 2,
            countPerRow: 8,
          )
          .expand((row) => row)
          .toList();

      for (final answer in duplicateAnswers.toSet()) {
        expect(
          candidates.where((char) => char == answer),
          hasLength(duplicateAnswers.where((char) => char == answer).length),
        );
      }
      final distractors = candidates
          .where((char) => !duplicateAnswers.contains(char))
          .toList();
      expect(distractors.toSet(), hasLength(distractors.length));
    });

    test('相同种子可复现，不同种子会变化', () {
      List<List<String>> generate(int seed) =>
          DistractorEngine(random: Random(seed)).generateCandidateBoard(
            correctAnswers: answers,
            rows: 3,
            countPerRow: 8,
          );

      expect(generate(21), generate(21));
      expect(generate(21), isNot(generate(22)));
    });

    test('相邻关卡优先使用不同的随机字组', () {
      Set<String> randomCharsFor(int levelNumber) =>
          DistractorEngine(random: Random(31))
              .generateCandidateBoard(
                correctAnswers: const ['龘'],
                rows: 2,
                countPerRow: 10,
                randomRotationKey: levelNumber,
              )
              .expand((row) => row)
              .where((char) => char != '龘')
              .toSet();

      expect(randomCharsFor(100).intersection(randomCharsFor(101)), isEmpty);
    });

    test('排除干扰字时仍保留同字的正式答案', () {
      final candidates = DistractorEngine(random: Random(37))
          .generateCandidateBoard(
            correctAnswers: const ['力'],
            rows: 1,
            countPerRow: 8,
            excludeDistractorChars: const {'力', '气'},
          )
          .single;

      expect(candidates.where((char) => char == '力'), hasLength(1));
      expect(candidates, isNot(contains('气')));
    });
  });

  test('generate 仍优先返回经典形近字', () {
    final engine = DistractorEngine(random: Random(1));
    final distractors = engine.generate(
      '人',
      count: 2,
      allAnswerChars: const [],
    );

    expect(distractors, containsAll(const ['入', '八']));
  });
}

Set<String> _relatedCharsFor(List<String> answers) {
  final result = <String>{};
  for (final answer in answers) {
    result.addAll(shapeSimilar[answer] ?? const []);
    for (final group in pinyinGroup.values) {
      if (group.contains(answer)) result.addAll(group);
    }
  }
  result.removeAll(answers);
  return result;
}

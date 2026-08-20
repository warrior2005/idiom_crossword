import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';

void main() {
  test('预置数据库相关字覆盖全部成语库汉字', () async {
    final tempDir = await Directory.systemTemp.createTemp('char_similar_test_');
    addTearDown(() => tempDir.delete(recursive: true));
    final databaseFile = await File(
      'assets/data/idiom_crossword.db',
    ).copy('${tempDir.path}/idiom_crossword.db');
    final database = AppDatabase(NativeDatabase(databaseFile));
    addTearDown(database.close);

    final summary = await database.customSelect('''
      WITH candidate_counts AS (
        SELECT char, COUNT(*) AS candidate_count
        FROM char_similar
        GROUP BY char
      ), corpus_chars AS (
        SELECT DISTINCT char FROM idiom_char_index
      )
      SELECT
        (SELECT COUNT(*) FROM char_similar) AS relation_count,
        COUNT(*) AS corpus_char_count,
        SUM(CASE WHEN candidate_count >= 8 THEN 1 ELSE 0 END)
          AS chars_with_eight
      FROM corpus_chars
      LEFT JOIN candidate_counts USING (char)
    ''').getSingle();

    expect(
      summary.read<int>('relation_count'),
      greaterThanOrEqualTo(minimumBundledCharSimilarCount),
    );
    expect(summary.read<int>('corpus_char_count'), 4846);
    expect(summary.read<int>('chars_with_eight'), 4846);

    final candidates = await database.findSimilarCharsFor(const ['人', '天']);
    expect(candidates['人'], containsAll(const ['入', '八']));
    expect(candidates['天'], containsAll(const ['大', '无', '夫']));
    expect(candidates['人']!.length, greaterThanOrEqualTo(8));
    expect(candidates['天']!.length, greaterThanOrEqualTo(8));
  });
}

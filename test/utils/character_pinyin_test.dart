import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/distractor_engine.dart';
import 'package:idiom_crossword/src/utils/character_pinyin.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('单字拼音使用与现有棋盘一致的无声调格式', () {
    expect(characterPinyin('蛇'), 'she');
    expect(characterPinyin('足'), 'zu');
    expect(characterPinyin('天'), 'tian');
  });

  test('所有预置成语字、数据库干扰字和内置候选字都有拼音', () {
    final db = sqlite3.open(
      'assets/data/idiom_crossword.db',
      mode: OpenMode.readOnly,
    );
    addTearDown(db.close);
    final chars = {
      ...corpusRandomChars.split(''),
      ...shapeSimilar.keys,
      ...shapeSimilar.values.expand((chars) => chars),
      ...pinyinGroup.values.expand((chars) => chars),
      for (final row in db.select('SELECT word FROM idioms'))
        ...(row['word'] as String).split(''),
      for (final row in db.select(
        'SELECT char, similar FROM char_similar',
      )) ...[row['char'] as String, row['similar'] as String],
    };
    final missing = chars.where(
      (char) => !RegExp(r'^[a-zü]+$').hasMatch(characterPinyin(char)),
    );
    expect(missing, isEmpty, reason: '候选字缺少拼音会再次暴露答案正误');
  });
}

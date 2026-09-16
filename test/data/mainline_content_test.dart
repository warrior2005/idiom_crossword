import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:idiom_crossword/src/data/mainline_content.dart';

void main() {
  test('仅删除末尾未配对引号，保留正常引号且幂等', () {
    final cases =
        jsonDecode(
              File('test/fixtures/trailing_quotes.json').readAsStringSync(),
            )
            as List;
    for (final pair in cases) {
      expect(fixTrailingQuotes(pair[0] as String), pair[1]);
      expect(fixTrailingQuotes(pair[1] as String), pair[1]);
    }
  });
  final content = MainlineContent.fromJson(
    jsonDecode(File('assets/data/mainline_content.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  test('内容更新原子、幂等，保留用户数据、ID和收藏关系', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute(
      'CREATE TABLE idioms(id INTEGER PRIMARY KEY,word TEXT,pinyin TEXT,pinyin_abbr TEXT,derivation TEXT,explanation TEXT)',
    );
    db.execute('CREATE TABLE collection(idiom_id INTEGER PRIMARY KEY)');
    for (final row in content.corrections) {
      db.execute(
        'INSERT INTO idioms(id,word,pinyin,pinyin_abbr) VALUES (?,?,?,?)',
        [row['id'], row['word'], 'bad', 'bad'],
      );
      db.execute('INSERT INTO collection VALUES (?)', [row['id']]);
    }
    content.applyCorrections(db);
    content.applyCorrections(db);
    expect(db.select('SELECT * FROM collection').length, 5);
    for (final row in content.corrections) {
      expect(
        db.select('SELECT pinyin FROM idioms WHERE id=?', [
          row['id'],
        ]).single['pinyin'],
        row['pinyin'],
      );
    }
  });
  test('ID不匹配时回滚全部词条，不记录成功版本', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute(
      'CREATE TABLE idioms(id INTEGER PRIMARY KEY,word TEXT,pinyin TEXT,pinyin_abbr TEXT,derivation TEXT,explanation TEXT)',
    );
    final first = content.corrections.first;
    db.execute(
      'INSERT INTO idioms(id,word,pinyin,pinyin_abbr) VALUES (?,?,?,?)',
      [first['id'], first['word'], 'bad', 'bad'],
    );
    expect(() => content.applyCorrections(db), throwsStateError);
    expect(db.select('SELECT pinyin FROM idioms').single['pinyin'], 'bad');
    expect(db.select('SELECT * FROM content_version'), isEmpty);
  });
  test('准入清单无交集且全部引用稳定ID', () {
    final ids =
        jsonDecode(File('data/idiom_ids.json').readAsStringSync()) as Map;
    expect(content.foundation.intersection(content.expansion), isEmpty);
    for (final word in {...content.foundation, ...content.expansion}) {
      expect(word.length, 4);
      expect(ids.containsKey(word), isTrue);
    }
  });
}

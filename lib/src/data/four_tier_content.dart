import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqlite3/sqlite3.dart';

/// 统一分级内容。审核来源只作记录，不参与准入。
class FourTierContent {
  static const currentVersion = 5;
  final int version;
  final List<dynamic> entries;
  final List<dynamic> additions;
  FourTierContent.fromJson(Map<String, dynamic> json)
    : version = json['version'] as int,
      entries = json['entries'] as List,
      additions = json['additions'] as List;

  static Future<FourTierContent> load() async => FourTierContent.fromJson(
    jsonDecode(
          await rootBundle.loadString('assets/data/four_tier_content.json'),
        )
        as Map<String, dynamic>,
  );

  void apply(Database db) {
    db.execute(
      'CREATE TABLE IF NOT EXISTS four_tier_version '
      '(id INTEGER PRIMARY KEY CHECK(id=1), version INTEGER NOT NULL)',
    );
    final current = db.select(
      'SELECT version FROM four_tier_version WHERE id=1',
    );
    if (current.isNotEmpty && (current.first['version'] as int) >= version) {
      return;
    }
    db.execute('BEGIN IMMEDIATE');
    try {
      final columns = db
          .select('PRAGMA table_info(idioms)')
          .map((r) => r['name'])
          .toSet();
      const fields = {
        'difficulty_tier': 'INTEGER NOT NULL DEFAULT 4',
        'difficulty_source': "TEXT NOT NULL DEFAULT 'inferred'",
        'difficulty_version': 'INTEGER NOT NULL DEFAULT 0',
        'is_reviewed': 'INTEGER NOT NULL DEFAULT 0',
      };
      for (final field in fields.entries) {
        if (!columns.contains(field.key)) {
          db.execute(
            'ALTER TABLE idioms ADD COLUMN ${field.key} ${field.value}',
          );
        }
      }
      for (final row in additions) {
        final word = row['word'] as String;
        final existing = db.select('SELECT id FROM idioms WHERE word=?', [
          word,
        ]);
        if (existing.isNotEmpty && existing.first['id'] != row['id']) {
          throw StateError('新增词ID冲突：$word');
        }
        db.execute(
          'INSERT OR IGNORE INTO idioms '
          '(id,word,pinyin,pinyin_abbr,explanation,derivation,first_char,last_char,difficulty,example) '
          "VALUES (?,?,?,?,?,?,?,?,?,'')",
          [
            row['id'],
            word,
            row['pinyin'],
            row['pinyinAbbr'],
            row['explanation'],
            row['derivation'],
            word[0],
            word[3],
            row['difficulty'],
          ],
        );
        for (var position = 0; position < 4; position++) {
          db.execute(
            'INSERT OR IGNORE INTO idiom_char_index '
            '(idiom_id,char,position,is_first,is_last) VALUES (?,?,?,?,?)',
            [
              row['id'],
              word[position],
              position,
              position == 0 ? 1 : 0,
              position == 3 ? 1 : 0,
            ],
          );
        }
      }
      final update = db.prepare(
        'UPDATE idioms SET difficulty_tier=?,difficulty_source=?, '
        'difficulty_version=?,is_reviewed=? WHERE id=? AND word=?',
      );
      try {
        for (final row in entries) {
          update.execute([
            row[2],
            row[3],
            version,
            row[4] == true ? 1 : 0,
            row[0],
            row[1],
          ]);
          if (db.updatedRows != 1) throw StateError('分级ID不一致：${row[1]}');
        }
      } finally {
        update.close();
      }
      db.execute(
        'CREATE INDEX IF NOT EXISTS idx_idiom_tier ON idioms(difficulty_tier)',
      );
      db.execute('INSERT OR REPLACE INTO four_tier_version VALUES (1,?)', [
        version,
      ]);
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqlite3/sqlite3.dart';

/// 版本化主线准入清单。未列出的词不会因旧分数较低自动进入主线。
class MainlineContent {
  final int version;
  final Set<String> foundation;
  final Set<String> intro;
  final Set<String> expansion;
  final List<Map<String, dynamic>> corrections;

  MainlineContent.fromJson(Map<String, dynamic> json)
    : version = json['version'] as int,
      foundation = Set<String>.from(json['foundation'] as List),
      intro = Set<String>.from(json['intro'] as List),
      expansion = Set<String>.from(json['expansion'] as List),
      corrections = (json['pinyinCorrections'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();

  static Future<MainlineContent> load() async => MainlineContent.fromJson(
    jsonDecode(await rootBundle.loadString('assets/data/mainline_content.json'))
        as Map<String, dynamic>,
  );

  /// 与 schema 迁移独立；事务提交版本，校验 ID，重复启动不重写用户数据。
  void applyCorrections(Database db) {
    db.execute(
      'CREATE TABLE IF NOT EXISTS content_version '
      '(id INTEGER PRIMARY KEY CHECK(id = 1), version INTEGER NOT NULL)',
    );
    final current = db.select('SELECT version FROM content_version WHERE id=1');
    if (current.isNotEmpty && (current.first['version'] as int) >= version) {
      return;
    }
    db.execute('BEGIN IMMEDIATE');
    try {
      for (final row in corrections) {
        final found = db.select('SELECT word FROM idioms WHERE id=?', [
          row['id'],
        ]);
        if (found.length != 1 || found.first['word'] != row['word']) {
          throw StateError('成语 ID 不一致：${row['word']}');
        }
        db.execute('UPDATE idioms SET pinyin=?, pinyin_abbr=? WHERE id=?', [
          row['pinyin'],
          row['pinyinAbbr'],
          row['id'],
        ]);
      }
      // v2：只清理末尾未配对的右引号，不改正文中的引号或正常配对。
      if (version >= 2) {
        for (final row in db.select(
          'SELECT id,derivation,explanation FROM idioms',
        )) {
          for (final field in ['derivation', 'explanation']) {
            final old = row[field] as String?;
            if (old == null) continue;
            final fixed = fixTrailingQuotes(old);
            if (fixed != old) {
              db.execute('UPDATE idioms SET $field=? WHERE id=?', [
                fixed,
                row['id'],
              ]);
            }
          }
        }
      }
      db.execute('INSERT OR REPLACE INTO content_version VALUES (1, ?)', [
        version,
      ]);
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }
}

/// 保留正文和尾部空白，只删除末尾没有对应左引号的连续右引号。
String fixTrailingQuotes(String text) {
  final end = text.trimRight().length;
  var depth = 0;
  final unmatched = <int>{};
  for (var i = 0; i < end; i++) {
    if (text[i] == '“') {
      depth++;
    } else if (text[i] == '”') {
      if (depth > 0) {
        depth--;
      } else {
        unmatched.add(i);
      }
    }
  }
  var cut = end;
  while (unmatched.contains(cut - 1)) {
    cut--;
  }
  return text.substring(0, cut) + text.substring(end);
}

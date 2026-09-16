import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/four_tier_content.dart';
import 'package:idiom_crossword/src/data/mainline_content.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';
import 'package:idiom_crossword/src/state/level_state_codec.dart';

// 走 AppDatabase() 的真实启动路径：资产复制、内容补丁、结构迁移与重开。
// 旧库按历史迁移边界构造，不等同于所有历史发行包的真机存档。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory directory;
  late MainlineContent pinyin;
  late FourTierContent tiers;
  late File template;
  late String frozen;

  setUpAll(() async {
    pinyin = await MainlineContent.load();
    tiers = await FourTierContent.load();
    final folder = await Directory.systemTemp.createTemp('upgrade_template_');
    addTearDown(() => folder.delete(recursive: true));
    template = await File(
      'assets/data/idiom_crossword.db',
    ).copy('${folder.path}/db');
    final db = AppDatabase(NativeDatabase(template));
    try {
      await db.updatePlayerProgress(
        level: 3,
        totalXp: 700,
        completedLevels: 20,
        hintCards: 7,
        reviveCards: 2,
      );
      await db.addToCollection(1);
      await db.addToFavorites(1);
      await db.setSetting('sound_enabled', 'false');
      final level = (await generateLevel(db, 11, seed: 721))!;
      frozen = encodeLevel(level);
      await db.addLevelHistory(
        levelNumber: 11,
        xpGained: 30,
        idiomsUsed: (await db.findIdiomIdsByWords(
          level.idioms.map((i) => i.text).toList(),
        )).values.toList(),
        levelJson: frozen,
      );
      await db.saveLevelState(
        levelNumber: 21,
        levelJson: frozen,
        stateJson: '{"answers":[]}',
      );
    } finally {
      await db.close();
    }
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('install_upgrade_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return directory.path;
          }
          throw MissingPluginException(call.method);
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });

  Future<void> verify({int? oldSchema}) async {
    for (var opening = 0; opening < 2; opening++) {
      final db = AppDatabase();
      try {
        expect(
          (await db.customSelect('PRAGMA user_version').getSingle())
              .data
              .values
              .single,
          currentSchemaVersion,
        );
        expect(
          (await db
                  .customSelect('SELECT COUNT(*) AS n FROM idioms')
                  .getSingle())
              .read<int>('n'),
          29724,
        );
        expect(
          (await db
                  .customSelect('SELECT version FROM four_tier_version')
                  .getSingle())
              .read<int>('version'),
          tiers.version,
        );
        expect(
          (await db
                  .customSelect('SELECT version FROM content_version')
                  .getSingle())
              .read<int>('version'),
          pinyin.version,
        );
        final words = await db.select(db.idioms).get();
        final byId = {for (final word in words) word.id: word};
        for (final word in words) {
          expect(fixTrailingQuotes(word.explanation), word.explanation);
          if (word.derivation != null) {
            expect(fixTrailingQuotes(word.derivation!), word.derivation);
          }
        }
        for (final entry in tiers.entries) {
          final actual = byId[entry[0]]!;
          expect(
            [
              actual.word,
              actual.difficultyTier,
              actual.difficultySource,
              actual.isReviewed,
            ],
            [entry[1], entry[2], entry[3], entry[4]],
          );
        }
        for (final correction in pinyin.corrections) {
          expect(byId[correction['id']]!.pinyin, correction['pinyin']);
        }
        if (oldSchema != null && oldSchema >= 2) {
          final progress = (await db.getPlayerProgress())!;
          expect(
            [
              progress.totalXp,
              progress.completedLevels,
              progress.hintCards,
              progress.reviveCards,
            ],
            [700, 20, 7, 2],
          );
          expect((await db.getCollectionWithDetails()).single.id, 1);
          final history = (await db.getLevelHistory()).single;
          expect([history.levelNumber, history.xpGained], [11, 30]);
          if (oldSchema >= 7) expect(history.levelJson, frozen);
        }
        if (oldSchema != null && oldSchema >= 3) {
          final saved = (await db.getLevelState(21))!;
          expect(saved.levelJson, frozen);
          expect(saved.stateJson, '{"answers":[]}');
          expect(decodeLevel(frozen), isNotNull);
        }
        if (oldSchema != null && oldSchema >= 6) {
          expect(await db.getSetting('sound_enabled'), 'false');
        }
        if (oldSchema != null && oldSchema >= 11) {
          expect(await db.getFavoriteIds(), [1]);
        }
        final level = await generateLevel(db, 11, seed: 811);
        expect(level, isNotNull);
        expect(level!.idioms.length, inInclusiveRange(6, 12));
      } finally {
        await db.close();
      }
    }
  }

  test('新安装：复制资产、应用内容、生成关卡及再次启动', () => verify());

  test('内容 v1 升级到 v2：修复双字段、保留正常引号与玩家存档', () async {
    final file = await template.copy('${directory.path}/idiom_crossword.db');
    final old = sqlite.sqlite3.open(file.path);
    old.execute(
      'CREATE TABLE IF NOT EXISTS content_version '
      '(id INTEGER PRIMARY KEY, version INTEGER NOT NULL)',
    );
    old.execute('INSERT OR REPLACE INTO content_version VALUES (1,1)');
    old.execute('UPDATE idioms SET derivation=?,explanation=? WHERE id=1', [
      '出处。”',
      '同师出无名”',
    ]);
    old.execute('UPDATE idioms SET derivation=? WHERE id=2', ['《书》：“正文。”']);
    old.close();
    await verify(oldSchema: currentSchemaVersion);
    final updated = sqlite.sqlite3.open(file.path);
    try {
      final row = updated
          .select('SELECT derivation,explanation FROM idioms WHERE id=1')
          .single;
      expect(row['derivation'], '出处。');
      expect(row['explanation'], '同师出无名');
      expect(
        updated
            .select('SELECT derivation FROM idioms WHERE id=2')
            .single['derivation'],
        '《书》：“正文。”',
      );
    } finally {
      updated.close();
    }
  });

  test('早期异构 idiom 单数表：沿用重建路径后能够启动', () async {
    final old = sqlite.sqlite3.open('${directory.path}/idiom_crossword.db');
    old.execute('CREATE TABLE idiom (id INTEGER PRIMARY KEY, word TEXT)');
    old.execute("INSERT INTO idiom VALUES (1,'旧库样本')");
    old.close();
    // 此路径重建数据库，不宣称保留该异构旧库中的用户进度。
    await verify();
  });

  for (var schema = 1; schema <= currentSchemaVersion; schema++) {
    test('同构旧库 schema $schema：直接升级并保留已有用户数据', () async {
      final file = await template.copy('${directory.path}/idiom_crossword.db');
      final db = sqlite.sqlite3.open(file.path);
      try {
        // 删除在该历史版本尚未引入的结构，避免只改 user_version 的假迁移。
        final columns = <int, Map<String, List<String>>>{
          4: {
            'level_history': ['errors_made'],
          },
          7: {
            'level_history': ['level_json'],
          },
          8: {
            'level_history': ['total_fills'],
          },
          9: {
            'player_progress_table': [
              'current_correct_streak',
              'best_correct_streak',
            ],
          },
          10: {
            'player_progress_table': ['points'],
          },
          12: {
            'idioms': [
              'difficulty_tier',
              'difficulty_source',
              'difficulty_version',
              'is_reviewed',
            ],
          },
        };
        db.execute('DROP INDEX IF EXISTS idx_idiom_tier');
        for (final change in columns.entries) {
          if (schema >= change.key) continue;
          for (final table in change.value.entries) {
            for (final column in table.value) {
              db.execute('ALTER TABLE ${table.key} DROP COLUMN $column');
            }
          }
        }
        final tables = {
          2: [
            'player_progress_table',
            'collection',
            'level_history',
            'decoration_table',
          ],
          3: ['level_state_table'],
          5: ['achievement_table'],
          6: ['settings_table'],
          11: ['favorites'],
        };
        for (final change in tables.entries) {
          if (schema >= change.key) continue;
          for (final table in change.value) {
            db.execute('DROP TABLE $table');
          }
        }
        db.execute('DROP TABLE IF EXISTS four_tier_version');
        db.execute('DROP TABLE IF EXISTS content_version');
        if (schema < 12) {
          for (final word in tiers.additions) {
            db.execute('DELETE FROM idiom_char_index WHERE idiom_id=?', [
              word['id'],
            ]);
            db.execute('DELETE FROM idioms WHERE id=?', [word['id']]);
          }
        }
        for (final correction in pinyin.corrections) {
          db.execute("UPDATE idioms SET pinyin='old' WHERE id=?", [
            correction['id'],
          ]);
        }
        db.execute('PRAGMA user_version=$schema');
      } finally {
        db.close();
      }
      await verify(oldSchema: schema);
    });
  }

  for (var version = 1; version <= FourTierContent.currentVersion; version++) {
    test('已安装内容版本 $version：更新或跳过补丁后正常重开', () async {
      final file = await template.copy('${directory.path}/idiom_crossword.db');
      final db = sqlite.sqlite3.open(file.path);
      try {
        pinyin.applyCorrections(db);
        tiers.apply(db);
        if (version < tiers.version) {
          db.execute(
            "UPDATE idioms SET difficulty_tier=4,is_reviewed=0,difficulty_source='inferred',difficulty_version=?",
            [version],
          );
        }
        db.execute('UPDATE four_tier_version SET version=?', [version]);
      } finally {
        db.close();
      }
      await verify(oldSchema: currentSchemaVersion);
    });
  }
}

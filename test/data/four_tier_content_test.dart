import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:idiom_crossword/src/data/four_tier_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('旧库内容升级完整、幂等，稳定ID和用户数据不变', () async {
    final dir = await Directory.systemTemp.createTemp('tier_migration');
    final file = await File(
      'assets/data/idiom_crossword.db',
    ).copy('${dir.path}/old.db');
    final db = sqlite3.open(file.path);
    addTearDown(() {
      db.close();
      dir.deleteSync(recursive: true);
    });
    final oldIds = db
        .select('SELECT id,word FROM idioms WHERE id<=29502')
        .map((r) => '${r['id']}:${r['word']}')
        .toList();
    db.execute('DELETE FROM idiom_char_index WHERE idiom_id>29502');
    db.execute('DELETE FROM idioms WHERE id>29502');
    db.execute('DROP INDEX IF EXISTS idx_idiom_tier');
    for (final column in [
      'difficulty_tier',
      'difficulty_source',
      'difficulty_version',
      'is_reviewed',
    ]) {
      db.execute('ALTER TABLE idioms DROP COLUMN $column');
    }
    db.execute(
      "INSERT INTO settings_table VALUES ('mainline_learning_v1','legacy learning')",
    );
    db.execute('INSERT INTO collection (idiom_id) VALUES (1)');
    db.execute(
      'INSERT INTO player_progress_table (total_xp,completed_levels) VALUES (700,20)',
    );
    db.execute(
      "INSERT INTO level_history (level_number,xp_gained,idioms_used,level_json) VALUES (20,30,'1','frozen')",
    );
    db.execute(
      "INSERT INTO level_state_table (level_number,level_json,state_json) VALUES (21,'frozen21','answers21')",
    );
    final userTables = [
      'settings_table',
      'collection',
      'player_progress_table',
      'level_history',
      'level_state_table',
    ];
    final userBefore = {
      for (final table in userTables)
        table: db
            .select('SELECT * FROM $table')
            .map((r) => r.values.toList())
            .toList(),
    };
    final content = await FourTierContent.load();
    content.apply(db);
    expect(db.select('SELECT count(*) AS n FROM idioms').first['n'], 29724);
    expect(
      db.select('SELECT count(*) AS n FROM idiom_char_index').first['n'],
      29724 * 4,
    );
    expect(
      db.select('SELECT sum(is_reviewed) AS n FROM idioms').first['n'],
      29724,
    );
    expect(
      db
          .select('SELECT id,word FROM idioms WHERE id<=29502')
          .map((r) => '${r['id']}:${r['word']}')
          .toList(),
      oldIds,
    );
    expect(
      db
          .select("SELECT difficulty_tier FROM idioms WHERE word='流水桃花'")
          .first['difficulty_tier'],
      4,
    );
    expect(
      db
          .select("SELECT difficulty_tier FROM idioms WHERE word='蒙袂辑屦'")
          .first['difficulty_tier'],
      4,
    );
    expect(db.select("SELECT word FROM idioms WHERE word='漫天风雪'").length, 1);
    expect(db.select('PRAGMA integrity_check').first.values.first, 'ok');
    content.apply(db);
    expect(db.select('SELECT count(*) AS n FROM idioms').first['n'], 29724);
    for (final table in userTables) {
      expect(
        db
            .select('SELECT * FROM $table')
            .map((r) => r.values.toList())
            .toList(),
        userBefore[table],
      );
    }
  });
  test('已安装内容版本4升级到5，人工改档生效且旧分、ID和冻结题不变', () async {
    final dir = await Directory.systemTemp.createTemp('tier_v2_upgrade');
    final file = await File(
      'assets/data/idiom_crossword.db',
    ).copy('${dir.path}/v2.db');
    final db = sqlite3.open(file.path);
    addTearDown(() {
      db.close();
      dir.deleteSync(recursive: true);
    });
    db.execute(
      'CREATE TABLE four_tier_version (id INTEGER PRIMARY KEY, version INTEGER NOT NULL)',
    );
    db.execute('INSERT INTO four_tier_version VALUES (1,4)');
    db.execute(
      "UPDATE idioms SET difficulty_tier=1,difficulty_source='inferred',is_reviewed=0,difficulty_version=2 WHERE word='一心一计'",
    );
    db.execute(
      "UPDATE idioms SET difficulty_tier=1,difficulty_source='textbook',difficulty_version=3 WHERE word='桃花潭水'",
    );
    db.execute(
      "INSERT INTO level_state_table (level_number,level_json,state_json) VALUES (11,'v2 frozen puzzle','v2 candidates')",
    );
    db.execute(
      "UPDATE idioms SET difficulty_tier=1,difficulty_source='inferred',is_reviewed=0,difficulty_version=4 WHERE word='一举成名'",
    );
    final original = db
        .select('SELECT id,word,difficulty FROM idioms ORDER BY id')
        .map((r) => r.values.toList())
        .toList();
    final content = await FourTierContent.load();
    expect(content.version, FourTierContent.currentVersion);
    content.apply(db);
    expect(
      db
          .select(
            "SELECT difficulty_tier,is_reviewed FROM idioms WHERE word='一举成名'",
          )
          .single
          .values
          .toList(),
      [2, 1],
    );
    expect(
      db.select('SELECT version FROM four_tier_version').single['version'],
      5,
    );
    expect(
      db
          .select(
            "SELECT difficulty_tier,difficulty_source,is_reviewed FROM idioms WHERE word='一心一计'",
          )
          .single
          .values
          .toList(),
      [4, 'manual', 1],
    );
    expect(
      db
          .select("SELECT difficulty_tier FROM idioms WHERE word='桃花潭水'")
          .single['difficulty_tier'],
      2,
    );
    expect(
      db
          .select('SELECT id,word,difficulty FROM idioms ORDER BY id')
          .map((r) => r.values.toList())
          .toList(),
      original,
    );
    content.apply(db);
    expect(db.select('SELECT COUNT(*) AS n FROM idioms').single['n'], 29724);
    expect(
      db
          .select('SELECT level_json,state_json FROM level_state_table')
          .single
          .values
          .toList(),
      ['v2 frozen puzzle', 'v2 candidates'],
    );
  });

  test('ID冲突使内容事务回滚，不提交版本', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute('CREATE TABLE idioms (id INTEGER PRIMARY KEY, word TEXT)');
    db.execute("INSERT INTO idioms VALUES (1,'一心一意')");
    final content = FourTierContent.fromJson({
      'version': 2,
      'additions': [],
      'entries': [
        [1, '一心一意', 1, 'textbook', true],
        [2, '不存在词', 2, 'textbook', true],
      ],
    });
    expect(() => content.apply(db), throwsStateError);
    expect(
      db.select('PRAGMA table_info(idioms)').map((r) => r['name']),
      isNot(contains('difficulty_tier')),
    );
    expect(db.select('SELECT * FROM four_tier_version'), isEmpty);
  });
}

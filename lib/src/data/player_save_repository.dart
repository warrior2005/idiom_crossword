import 'dart:convert';

import 'database.dart';

/// 用户存档的逻辑快照。静态成语库不进入云存档。
class PlayerSaveRepository {
  static const int formatVersion = 1;
  static const String customAvatarPathKey = 'custom_avatar_path';
  static const Set<String> _excludedSettingKeys = {
    customAvatarPathKey,
    'active_background',
  };

  static Future<bool> isLocalSaveEmpty(AppDatabase db) async {
    final row = await db.customSelect('''
      SELECT
        (SELECT COUNT(*) FROM user_progress) +
        (SELECT COUNT(*) FROM player_progress_table) +
        (SELECT COUNT(*) FROM collection) +
        (SELECT COUNT(*) FROM favorites) +
        (SELECT COUNT(*) FROM level_history) +
        (SELECT COUNT(*) FROM decoration_table) +
        (SELECT COUNT(*) FROM level_state_table) +
        (SELECT COUNT(*) FROM achievement_table) +
        (SELECT COUNT(*) FROM settings_table) AS user_row_count
    ''').getSingle();
    return row.read<int>('user_row_count') == 0;
  }

  static Future<Map<String, dynamic>> exportSnapshot(AppDatabase db) async {
    final settings = await db.select(db.settingsTable).get();
    return {
      'formatVersion': formatVersion,
      'databaseSchemaVersion': currentSchemaVersion,
      'savedAt': DateTime.now().toUtc().toIso8601String(),
      'tables': {
        'userProgress': (await db.select(db.userProgress).get())
            .map((row) => row.toJson())
            .toList(),
        'playerProgress': (await db.select(db.playerProgressTable).get())
            .map((row) => row.toJson())
            .toList(),
        'collection': (await db.select(db.collection).get())
            .map((row) => row.toJson())
            .toList(),
        'favorites': (await db.select(db.favorites).get())
            .map((row) => row.toJson())
            .toList(),
        'levelHistory': (await db.select(db.levelHistory).get())
            .map((row) => row.toJson())
            .toList(),
        'decorations': (await db.select(db.decorationTable).get())
            .map((row) => row.toJson())
            .toList(),
        'levelStates': (await db.select(db.levelStateTable).get())
            .map((row) => row.toJson())
            .toList(),
        'achievements': (await db.select(db.achievementTable).get())
            .map((row) => row.toJson())
            .toList(),
        'settings': settings
            .where((row) => !_excludedSettingKeys.contains(row.key))
            .map((row) => row.toJson())
            .toList(),
      },
    };
  }

  static Future<void> importJson(AppDatabase db, String source) async {
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('存档不是 JSON 对象');
    final snapshot = Map<String, dynamic>.from(decoded);
    if (snapshot['formatVersion'] != formatVersion) {
      throw const FormatException('不支持的存档版本');
    }
    final rawTables = snapshot['tables'];
    if (rawTables is! Map) throw const FormatException('存档缺少数据表');
    final tables = Map<String, dynamic>.from(rawTables);

    final userProgressRows = _decodeRows(
      tables,
      'userProgress',
      UserProgressData.fromJson,
    );
    final playerProgressRows = _decodeRows(
      tables,
      'playerProgress',
      PlayerProgressTableData.fromJson,
    );
    if (playerProgressRows.length > 1) {
      throw const FormatException('玩家进度记录数量无效');
    }
    final collectionRows = _decodeRows(
      tables,
      'collection',
      CollectionData.fromJson,
    );
    final favoriteRows = _decodeRows(tables, 'favorites', Favorite.fromJson);
    final historyRows = _decodeRows(
      tables,
      'levelHistory',
      LevelHistoryData.fromJson,
    );
    final decorationRows = _decodeRows(
      tables,
      'decorations',
      DecorationTableData.fromJson,
    ).map((row) => row.copyWith(isActive: false)).toList();
    final levelStateRows = _decodeRows(
      tables,
      'levelStates',
      LevelStateTableData.fromJson,
    );
    final achievementRows = _decodeRows(
      tables,
      'achievements',
      AchievementTableData.fromJson,
    );
    final settingRows = _decodeRows(
      tables,
      'settings',
      SettingsTableData.fromJson,
    ).where((row) => !_excludedSettingKeys.contains(row.key)).toList();

    await db.transaction(() async {
      await db.batch((batch) {
        batch.insertAll(db.userProgress, userProgressRows);
        batch.insertAll(db.playerProgressTable, playerProgressRows);
        batch.insertAll(db.collection, collectionRows);
        batch.insertAll(db.favorites, favoriteRows);
        batch.insertAll(db.levelHistory, historyRows);
        batch.insertAll(db.decorationTable, decorationRows);
        batch.insertAll(db.levelStateTable, levelStateRows);
        batch.insertAll(db.achievementTable, achievementRows);
        batch.insertAll(db.settingsTable, settingRows);
      });
    });
  }

  static List<T> _decodeRows<T>(
    Map<String, dynamic> tables,
    String key,
    T Function(Map<String, dynamic>) decode,
  ) {
    final value = tables[key];
    if (value is! List) throw FormatException('存档缺少 $key');
    return value.map((row) {
      if (row is! Map) throw FormatException('$key 记录格式无效');
      return decode(Map<String, dynamic>.from(row));
    }).toList();
  }
}

/// Drift 数据库定义
/// 
/// 使用方式：
///   1. dart run build_runner build
///   2. 自动生成 database.g.dart
/// 
/// 注意：这个文件依赖于 drift 的代码生成。
/// 如果暂时不想引入 drift，可以先手写 SQLite 的 Dart 封装。

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database.g.dart';

// ============================================================
// 表定义
// ============================================================

/// 成语主表
class Idioms extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get word => text().withLength(min: 2, max: 32).unique()();
  TextColumn get pinyin => text()();
  TextColumn get pinyinAbbr => text()();
  TextColumn get explanation => text()();
  TextColumn get derivation => text().nullable()();
  TextColumn get example => text().nullable()();
  TextColumn get firstChar => text()();
  TextColumn get lastChar => text()();
  IntColumn get difficulty => integer()(); // 游戏难度 1-50（等量均匀分布）
  BoolColumn get reversible => boolean().withDefault(const Constant(false))();

  // 难度元数据
  IntColumn get difficultyOriginal => integer().nullable()();
  IntColumn get difficultyRank => integer().nullable()();
  RealColumn get difficultyPercentile => real().nullable()();
  TextColumn get difficultyMethod => text().nullable()();
  // 倒装/异形组
  IntColumn get variantGroupId => integer().nullable()();
  TextColumn get canonicalWord => text().nullable()();
  BoolColumn get isCanonical => boolean().nullable()();
  IntColumn get semanticDifficulty => integer().nullable()();
  RealColumn get surfacePenalty => real().nullable()();
  IntColumn get surfaceDifficultyScore => integer().nullable()();
  IntColumn get difficultyBaseBeforeVariantPenalty => integer().nullable()();
  IntColumn get difficultyRebalancedV1 => integer().nullable()();

  // 扩展字段
  TextColumn get emotion => text().nullable()();   // 褒/贬/中
  TextColumn get category => text().nullable()();  // 哲理/军事/自然/情感
  TextColumn get era => text().nullable()();       // 先秦/汉/唐
  TextColumn get sourceType => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// 成语倒排索引
class IdiomCharIndex extends Table {
  IntColumn get idiomId => integer().references(Idioms, #id, onDelete: KeyAction.cascade)();
  TextColumn get char => text()();
  IntColumn get position => integer()();
  BoolColumn get isFirst => boolean().withDefault(const Constant(false))();
  BoolColumn get isLast => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {idiomId, char, position};
}

/// 倒装成语对
class IdiomReversiblePair extends Table {
  IntColumn get idiomIdA => integer().references(Idioms, #id, onDelete: KeyAction.cascade)();
  IntColumn get idiomIdB => integer().references(Idioms, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {idiomIdA, idiomIdB};
}

/// 形近/音近字
class CharSimilar extends Table {
  TextColumn get char => text()();
  TextColumn get similar => text()();
  TextColumn get simType => text().check(simType.equals('shape') | simType.equals('sound'))();
  RealColumn get simScore => real().withDefault(const Constant(0.5))();

  @override
  Set<Column> get primaryKey => {char, similar};
}

/// 用户进度
class UserProgress extends Table {
  TextColumn get userId => text()();
  IntColumn get level => integer()();
  TextColumn get state => text().check(
      state.equals('locked') | state.equals('unlocked') | state.equals('completed') | state.equals('perfect'))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get timeSpent => integer().withDefault(const Constant(0))(); // 秒
  IntColumn get hintsUsed => integer().withDefault(const Constant(0))();
  IntColumn get errorsMade => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {userId, level};
}

// ============================================================
// 数据库
// ============================================================

@DriftDatabase(
  tables: [Idioms, IdiomCharIndex, IdiomReversiblePair, CharSimilar, UserProgress],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();

        // 创建额外索引
        await customStatement(
          'CREATE INDEX idx_ici_char ON idiom_char_index(char)');
        await customStatement(
          'CREATE INDEX idx_ici_char_pos ON idiom_char_index(char, position)');
        await customStatement(
          'CREATE INDEX idx_idiom_difficulty ON idioms(difficulty)');
        await customStatement(
          'CREATE INDEX idx_idiom_first_char ON idioms(first_char)');
        await customStatement(
          'CREATE INDEX idx_idiom_last_char ON idioms(last_char)');
      },
    );
  }

  // ============================================================
  // 关键查询
  // ============================================================

  /// 按字查成语（倒排索引查询）
  Future<List<Idiom>> findIdiomsByChar(String char) {
    return (select(idioms).join([
      innerJoin(idiomCharIndex, idiomCharIndex.idiomId.equalsExp(idioms.id)),
    ])
      ..where(idiomCharIndex.char.equals(char)))
        .map((row) => row.readTable(idioms))
        .get();
  }

  /// 找可与给定成语交叉的成语（通过共享字）
  Future<List<Idiom>> findCrossableIdioms(String idiomWord, int excludeId) {
    final chars = idiomWord.split('');
    return (select(idioms).join([
      innerJoin(idiomCharIndex, idiomCharIndex.idiomId.equalsExp(idioms.id)),
    ])
      ..where(idiomCharIndex.char.isIn(chars) & idioms.id.isNotEquals(excludeId)))
        .map((row) => row.readTable(idioms))
        .get();
  }

  /// 按难度获取一批成语
  Future<List<Idiom>> findIdiomsByDifficulty(int min, int max, int limit) {
    return (select(idioms)
      ..where(idioms.difficulty.isBetweenValues(min, max))
      ..orderBy([OrderingTerm.random()])
      ..limit(limit))
        .get();
  }

  /// 找倒装形式
  Future<Idiom?> findReversibleForm(int idiomId) {
    return _findReversible(idiomId);
  }

  Future<Idiom?> _findReversible(int idiomId) async {
    final pair = await (select(idiomReversiblePair)
      ..where(idiomReversiblePair.idiomIdA.equals(idiomId) |
              idiomReversiblePair.idiomIdB.equals(idiomId)))
        .getSingleOrNull();
    if (pair == null) return null;
    final otherId = pair.idiomIdA == idiomId ? pair.idiomIdB : pair.idiomIdA;
    return (select(idioms)..where((t) => t.id.equals(otherId))).getSingleOrNull();
  }

  /// 找形近/音近字
  Future<List<String>> findSimilarChars(String char, String type) {
    return (select(charSimilar)
      ..where(charSimilar.char.equals(char) & charSimilar.simType.equals(type))
      ..orderBy([OrderingTerm.desc(charSimilar.simScore)]))
        .map((row) => row.similar)
        .get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'idiom_crossword.db'));
    return NativeDatabase.createInBackground(file);
  });
}

// ============================================================
// DAO 快捷方法（可选）
// ============================================================
extension IdiomQueries on AppDatabase {
  /// 按首字匹配（接龙用）
  Future<List<Idiom>> findByFirstChar(String char) {
    return (select(idioms)
      ..where((t) => t.firstChar.equals(char)))
        .get();
  }

  /// 按末字匹配（倒接龙）
  Future<List<Idiom>> findByLastChar(String char) {
    return (select(idioms)
      ..where((t) => t.lastChar.equals(char)))
        .get();
  }

  /// 首尾字匹配（循环接龙）
  Future<List<Idiom>> findByFirstOrLastChar(String char) {
    return (select(idioms)
      ..where((t) => t.firstChar.equals(char) | t.lastChar.equals(char)))
        .get();
  }
}

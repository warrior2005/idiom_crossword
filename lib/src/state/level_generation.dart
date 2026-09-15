import 'package:drift/drift.dart' show OrderingTerm;
import 'dart:math';
import 'dart:convert';

import '../data/database.dart';
import '../data/four_tier_content.dart';
import '../engine/adaptive_policy.dart';
import '../engine/distractor_engine.dart';
import '../data/mainline_learning.dart';
import '../data/mainline_exposure.dart';
import '../data/tier_progression.dart';
import '../engine/candidate_ambiguity.dart';
import '../engine/crossing_graph.dart';
import '../engine/grid_engine.dart' as engine;
import '../engine/integrated_generator.dart';
import '../engine/spiral_difficulty.dart';
import '../engine/global_difficulty.dart';
import 'level_state_codec.dart';

/// 每日挑战专用关卡号段起点（1000000+epochDay，与普通关卡区分）
const int dailyLevelOffset = 1000000;

/// 普通关卡不重复使用最近这些关卡出现过的成语。
const int recentLevelExclusionCount = 3;

/// 今日每日挑战关卡号
int dailyLevelNumber([DateTime? now]) => dailyLevelOffset + epochDay(now);

/// 距 1970 的天数（每日挑战种子）
int epochDay([DateTime? now]) {
  final date = _chinaCalendarDate(now);
  final calendarDay = DateTime.utc(date.year, date.month, date.day);
  return calendarDay.difference(DateTime.utc(1970)).inDays;
}

/// 每日挑战展示日期，例如 20260820期。
String dailyIssueLabel([DateTime? now]) {
  final date = _chinaCalendarDate(now);
  return _formatDailyIssue(date);
}

/// 从每日挑战专用关卡号还原展示日期。
String dailyIssueLabelForLevel(int levelNumber) {
  final date = DateTime.utc(
    1970,
    1,
    1,
  ).add(Duration(days: levelNumber - dailyLevelOffset));
  return _formatDailyIssue(date);
}

String _formatDailyIssue(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}'
    '${date.month.toString().padLeft(2, '0')}'
    '${date.day.toString().padLeft(2, '0')}期';

/// 每日挑战按中国标准时间的日历日统一刷新。
DateTime _chinaCalendarDate(DateTime? now) =>
    (now ?? DateTime.now()).toUtc().add(const Duration(hours: 8));

/// 按关卡编号生成一关（首页/关卡选择共用）
///
/// 难度区间在螺旋基准上放宽 ±2，按关卡规模取 300/600 条候选成语再交给
/// IntegratedGenerator 生成；非固定种子首次失败时会重新抽取一次候选池。
Future<engine.CrosswordLevel?> generateLevel(
  AppDatabase db,
  int levelNumber, {
  int maxAttempts = 50,
  int? seed,
  int? targetSize,
  (int, int)? difficultyRange,
  String? title,
  bool globalRange = false,
  int playerLevel = 1,
  DateTime? now,
}) async {
  if (levelNumber > 0 &&
      levelNumber < dailyLevelOffset &&
      targetSize == null &&
      difficultyRange == null) {
    return _generateMainline(
      db,
      levelNumber,
      maxAttempts: maxAttempts,
      seed: seed,
      title: title,
      now: now,
    );
  }
  final (minD, maxD) = globalRange
      ? (1, 50)
      : difficultyRange ?? _spiralRange(levelNumber);
  final excludedIds =
      seed == null && levelNumber > 0 && levelNumber < dailyLevelOffset
      ? await db.getRecentlyUsedMainIdiomIds(recentLevelExclusionCount)
      : const <int>{};
  final generationTries = seed == null ? 2 : 1;

  if (globalRange && targetSize == null) {
    for (
      var generationTry = 0;
      generationTry < generationTries;
      generationTry++
    ) {
      final level = await _generateGlobalLevel(
        db,
        levelNumber,
        maxAttempts: maxAttempts,
        seed: seed,
        title: title,
        excludedIds: excludedIds,
      );
      if (level != null) return _addDisambiguatingGivens(db, level);
    }
    return null;
  }

  final needsLargeCandidatePool = targetSize != null
      ? targetSize >= 10
      : levelNumber > 5;
  final candidateLimit = needsLargeCandidatePool ? 600 : 300;
  for (
    var generationTry = 0;
    generationTry < generationTries;
    generationTry++
  ) {
    final dbIdioms = await db.findIdiomsByDifficulty(
      minD,
      maxD,
      candidateLimit,
      randomOrder: seed == null,
      legacyOnly: levelNumber >= dailyLevelOffset,
    );
    final engineIdioms = dbIdioms
        .where((i) => !excludedIds.contains(i.id))
        .map(
          (i) => engine.Idiom(
            text: i.word,
            pinyin: i.pinyin,
            meaning: i.explanation,
            difficulty: i.difficulty,
            source: i.derivation ?? '',
          ),
        )
        .toList();
    if (engineIdioms.length < 5) continue;

    final graph = CrossingGraph(idioms: engineIdioms);
    final generator = IntegratedGenerator(
      graph: graph,
      random: seed == null ? null : Random(seed),
    );
    if (targetSize != null) {
      final level = generator.generate(
        targetSize: targetSize,
        minDifficulty: minD,
        maxDifficulty: maxD,
        maxAttempts: maxAttempts,
        levelNumber: levelNumber,
      );
      if (level == null) continue;
      final titledLevel = title == null
          ? level
          : engine.CrosswordLevel(
              levelId: level.levelId,
              grid: level.grid,
              placements: level.placements,
              givenCharacters: level.givenCharacters,
              title: title,
              storyHint: level.storyHint,
            );
      return _addDisambiguatingGivens(db, titledLevel);
    }
    final level = generator.generateSpiral(
      levelNumber: levelNumber,
      playerLevel: playerLevel,
      maxAttempts: maxAttempts,
    );
    if (level != null) return _addDisambiguatingGivens(db, level);
  }
  return null;
}

/// 全词库按档位配额抽样；审核标记不参与过滤。实际题目和候选盘在这里冻结。
Future<engine.CrosswordLevel?> _generateMainline(
  AppDatabase db,
  int number, {
  int maxAttempts = 50,
  int? seed,
  String? title,
  DateTime? now,
}) async {
  final step = await MainlineLearning.ability(db);
  final observations = await MainlineLearning.read(db);
  if (observations['progression'] == null &&
      (observations['sessions'] as List).any(
        (s) => (s['strategy'] as int? ?? 0) == 2,
      )) {
    final rows = await db.select(db.idioms).get();
    TierProgression.restoreLegacy(observations, {
      for (final r in rows) r.word: r.difficultyTier,
    });
    await db.setSetting(MainlineLearning.key, jsonEncode(observations));
  }
  final progression = TierProgression.state(observations);
  final policy = AdaptivePolicy(
    number,
    step,
    tier: progression['tier'] as int,
    nextCount: progression['next'] as int,
  );
  final exposure = await MainlineExposure.read(db);
  final blocked = MainlineExposure.blocked(db, exposure);
  final due = await MainlineLearning.dueWords(db, now: now);
  final familiar = await MainlineLearning.familiarWords(db);
  final weakTiers = await MainlineLearning.weakTiers(db);
  final excluded = MainlineExposure.recentWords(exposure);
  final activeTiers = policy.quotas.entries
      .where((q) => q.value > 0)
      .map((q) => q.key)
      .toList();
  final all =
      await (db.select(db.idioms)
            ..where((t) => t.difficultyTier.isIn(activeTiers))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();
  final eligible = all.where((r) => !excluded.contains(r.word)).toList();
  final tiers = {for (final row in eligible) row.word: row.difficultyTier};
  final rng = Random(seed);
  final knownCount = eligible.where((r) => familiar.contains(r.word)).length;
  // 熟悉池不足时不强求半题旧词，避免围绕少数连接词反复组题。
  var noveltyBudget = knownCount >= policy.size * 8
      ? (policy.size / 2).ceil()
      : policy.size;
  final knownByTier = <int, int>{};
  for (final r in eligible.where((r) => familiar.contains(r.word))) {
    knownByTier.update(r.difficultyTier, (v) => v + 1, ifAbsent: () => 1);
  }
  final minimumUnknown = policy.quotas.entries.fold<int>(
    0,
    (sum, q) => sum + max(0, q.value - (knownByTier[q.key] ?? 0)),
  );
  noveltyBudget = max(noveltyBudget, minimumUnknown);
  final previous = (observations['sessions'] as List)
      .where(
        (s) =>
            (s['strategy'] as int? ?? 0) >= 3 &&
            ((s['number'] as int) == number - 1 ||
                (s['number'] as int) == number),
      )
      .lastOrNull;
  final previousPolicy = previous?['policy'] as Map?;
  final previousUnfamiliar = previousPolicy?['unfamiliar'] as int?;
  if (previousUnfamiliar != null) {
    noveltyBudget = noveltyBudget.clamp(
      max(0, previousUnfamiliar - 1),
      min(policy.size, previousUnfamiliar + 1),
    );
  }

  final recentCounts = <String, int>{};
  for (final r in exposure['recent'] as List) {
    for (final word in (r['words'] as List).cast<String>()) {
      recentCounts[word] = (recentCounts[word] ?? 0) + 1;
    }
  }
  final lastPolicy =
      (observations['sessions'] as List).lastOrNull?['policy'] as Map?;
  final hadReview = (lastPolicy?['reviewWords'] as List? ?? []).isNotEmpty;
  final reviewOptions =
      eligible
          .where(
            (r) =>
                due.contains(r.word) &&
                (policy.quotas[r.difficultyTier] ?? 0) > 0,
          )
          .toList()
        ..shuffle(rng);
  final learningWords = observations['words'] as Map;
  final reviewPriority = {
    for (final r in reviewOptions)
      r.word:
          rng.nextDouble() /
          (1 +
              ((learningWords[r.word] as Map?)?['reviewSignals'] as int? ?? 0)),
  };
  reviewOptions.sort(
    (a, b) => reviewPriority[a.word]!.compareTo(reviewPriority[b.word]!),
  );
  final planned = !hadReview && reviewOptions.isNotEmpty
      ? reviewOptions.first.word
      : null;
  for (var attempt = 0; attempt < 5; attempt++) {
    final pool = <Idiom>[];
    final fallbackWords = <String>{};
    for (final quota in policy.quotas.entries) {
      if (quota.value == 0) continue;
      final rows = eligible.where((r) => r.difficultyTier == quota.key).toList()
        ..shuffle(rng);
      if (rows.length < quota.value) return null;
      final byWord = <String, Idiom>{};
      for (final row
          in rows.where((r) => familiar.contains(r.word)).take(100)) {
        byWord[row.word] = row;
      }
      for (final row in rows.take(350 + attempt * 150)) {
        byWord[row.word] = row;
      }
      // 备用复习池扩大连接机会，但不要求出现在成品中。
      for (final row
          in reviewOptions
              .where((r) => r.difficultyTier == quota.key)
              .take(100)) {
        if (!byWord.containsKey(row.word) && row.word != planned) {
          fallbackWords.add(row.word);
        }
        byWord[row.word] = row;
      }
      pool.addAll(byWord.values);
    }
    final availableKnown = <int, int>{};
    for (final r in pool) {
      if (familiar.contains(r.word)) {
        availableKnown.update(
          r.difficultyTier,
          (v) => v + 1,
          ifAbsent: () => 1,
        );
      }
    }
    bool selectable(Iterable<engine.Idiom> words) {
      if (!policy.accepts(words, tiers)) return false;
      if (words
              .where((w) => w.text == planned || fallbackWords.contains(w.text))
              .length >
          2) {
        return false;
      }
      final unknown = words.where((w) => !familiar.contains(w.text)).length;
      var requiredUnknown = 0;
      final counts = <int, int>{}, known = <int, int>{};
      for (final w in words) {
        final t = tiers[w.text]!;
        counts.update(t, (v) => v + 1, ifAbsent: () => 1);
        if (familiar.contains(w.text)) {
          known.update(t, (v) => v + 1, ifAbsent: () => 1);
        }
      }
      for (final q in policy.quotas.entries) {
        final remaining = q.value - (counts[q.key] ?? 0);
        final usable = max(
          0,
          (availableKnown[q.key] ?? 0) - (known[q.key] ?? 0),
        );
        requiredUnknown += max(0, remaining - usable);
      }
      if (unknown + requiredUnknown > noveltyBudget) return false;
      // 相邻题陌生量的下限也在选词时检查，避免完整布局后才拒绝。
      if (previousUnfamiliar != null &&
          unknown + policy.size - words.length <
              max(0, previousUnfamiliar - 2)) {
        return false;
      }
      return true;
    }

    final graph = CrossingGraph(
      idioms: pool
          .map(
            (r) => engine.Idiom(
              text: r.word,
              pinyin: r.pinyin,
              meaning: r.explanation,
              difficulty: r.difficulty,
              source: r.derivation ?? '',
            ),
          )
          .toList(),
    );
    final priorities = {
      for (final r in pool)
        r.word:
            -log(max(0.000001, rng.nextDouble())) *
            (1 + (recentCounts[r.word] ?? 0) * 2),
    };
    final generator = IntegratedGenerator(graph: graph, random: rng);
    final generated = generator.generate(
      targetSize: policy.size,
      minDifficulty: 1,
      maxDifficulty: 50,
      levelNumber: number,
      maxAttempts: maxAttempts,
      boundedSearch: true,
      candidatePool: {
        for (var i = 0; i < pool.length; i++)
          if (!fallbackWords.contains(pool[i].word)) i,
      },
      fallbackPool: {
        for (var i = 0; i < pool.length; i++)
          if (fallbackWords.contains(pool[i].word)) i,
      },
      preferredSeeds: planned != null
          ? {planned}
          : noveltyBudget < policy.size
          ? familiar
          : {},
      fallbackSeeds: noveltyBudget < policy.size ? familiar : {},
      wordPriority: (word) => priorities[word]!,
      canSelect: selectable,
      accept: (level) =>
          !blocked.contains(
            MainlineExposure.fingerprint(level.idioms.map((i) => i.text)),
          ) &&
          level.placements.length == policy.size &&
          (previousUnfamiliar == null ||
              (level.idioms.where((i) => !familiar.contains(i.text)).length -
                          previousUnfamiliar)
                      .abs() <=
                  2) &&
          policy.accepts(level.idioms, tiers) &&
          policy.support(level, tiers, familiar, weakTiers: weakTiers),
    );
    if (generated == null) continue;
    final dictionary = await db.findIdiomWordsMatchingPatterns(
      candidatePatternsForLevel(generated),
    );
    final alternatives = await db.findReversibleWordsFor(
      generated.idioms.map((i) => i.text),
    );
    final level = addDisambiguatingGivens(
      level: generated,
      dictionaryWords: dictionary,
      allowedAlternatives: alternatives,
    );
    if (level.fillableCells < policy.answerTarget - 2 ||
        !level.placements.every(
          (p) => p.cells.any((c) => !level.grid.cellAt(c.$1, c.$2).isGiven),
        )) {
      continue;
    }
    final answers = <(int, int), String>{};
    for (final p in level.placements) {
      for (final c in p.cells) {
        final cell = level.grid.cellAt(c.$1, c.$2);
        if (!cell.isGiven) answers[c] = cell.character;
      }
    }
    final candidatesCount = policy.candidateCount(answers.length);
    final unfamiliar = level.idioms
        .where((i) => !familiar.contains(i.text))
        .length;
    if (previousUnfamiliar != null &&
        (unfamiliar - previousUnfamiliar).abs() > 2) {
      continue;
    }

    if (previousPolicy != null) {
      final previousAnswers = previousPolicy['answers'] as int?;
      final previousCandidates = previousPolicy['candidates'] as int?;
      if (previousAnswers != null &&
          (answers.length - previousAnswers).abs() > 3) {
        continue;
      }
      if (previousCandidates != null &&
          (candidatesCount - previousCandidates).abs() > 5) {
        continue;
      }
    }
    final related = await db.findSimilarCharsFor(answers.values);
    final exclusions = <String>{};
    List<List<String>>? board;
    final distractors = DistractorEngine(random: rng);
    for (var trial = 0; trial < 40; trial++) {
      try {
        final trialBoard = distractors.generateCandidateBoard(
          correctAnswers: answers.values.toList(),
          totalCount: candidatesCount,
          countPerRow: 10,
          databaseRelatedCandidates: related,
          excludeDistractorChars: exclusions,
        );
        final ambiguous = findCandidateAmbiguities(
          level: level,
          dictionaryWords: dictionary,
          availableChars: trialBoard.expand((r) => r),
          allowedAlternatives: alternatives,
        );
        if (ambiguous.isEmpty) {
          board = trialBoard;
          break;
        }
        final added = distractorCharsToExclude(
          ambiguous,
          answers.values.toSet(),
        )..removeAll(exclusions);
        if (added.isEmpty) break;
        exclusions.addAll(added);
      } on StateError {
        break;
      }
    }
    if (board == null) continue;
    final result = engine.CrosswordLevel(
      levelId: number,
      grid: level.grid,
      placements: level.placements,
      givenCharacters: level.givenCharacters,
      title: title ?? '第 $number 关',
      contentVersion: FourTierContent.currentVersion,
      strategyVersion: 3,
      support: 2,
      instanceId: '${number}_${DateTime.now().microsecondsSinceEpoch}',
      initialCandidates: board,
      strategy: {
        'step': step,
        'tier': policy.tier,
        'next': policy.nextCount,
        'fingerprint': MainlineExposure.fingerprint(
          level.idioms.map((i) => i.text),
        ),
        'reviewWords': level.idioms
            .where((i) => i.text == planned || fallbackWords.contains(i.text))
            .map((i) => i.text)
            .toList(),
        'reviewReasons': {
          for (final i in level.idioms.where(
            (i) => i.text == planned || fallbackWords.contains(i.text),
          ))
            i.text: i.text == planned ? 'learning' : 'fallback',
        },
        'incidentalWeakWords': level.idioms
            .where(
              (i) =>
                  due.contains(i.text) &&
                  i.text != planned &&
                  !fallbackWords.contains(i.text),
            )
            .map((i) => i.text)
            .toList(),
        'generationAttempt': attempt + 1,
        'size': policy.size,
        'answers': answers.length,
        'candidates': candidatesCount,
        'distractorRatio': policy.distractorRatio,
        'quotas': {for (final e in policy.quotas.entries) '${e.key}': e.value},
        'wordTiers': {for (final i in level.idioms) i.text: tiers[i.text]},
        'noveltyBudget': noveltyBudget,
        'unfamiliar': level.idioms
            .where((i) => !familiar.contains(i.text))
            .length,
      },
    );
    if (await MainlineExposure.reserve(db, result)) return result;
  }
  return null;
}

Future<engine.CrosswordLevel> _addDisambiguatingGivens(
  AppDatabase db,
  engine.CrosswordLevel level,
) async {
  try {
    final words = await db.findIdiomWordsMatchingPatterns(
      candidatePatternsForLevel(level),
      legacyOnly: level.levelId >= dailyLevelOffset,
    );
    final allowedAlternatives = await db.findReversibleWordsFor(
      level.idioms.map((idiom) => idiom.text),
    );
    return addDisambiguatingGivens(
      level: level,
      dictionaryWords: words,
      allowedAlternatives: allowedAlternatives,
    );
  } catch (_) {
    // 歧义检查不可用时保留原关卡，不能降低已有生成成功率。
    return level;
  }
}

/// Lv.20 后：按“波浪中心 + 三区混排”从各难度区取词生成
Future<engine.CrosswordLevel?> _generateGlobalLevel(
  AppDatabase db,
  int levelNumber, {
  required int maxAttempts,
  int? seed,
  String? title,
  required Set<int> excludedIds,
}) async {
  final global = GlobalDifficulty.calculate(
    levelNumber,
    random: seed == null ? null : Random(seed),
  );
  final zones = [
    (global.mainMin, global.mainMax, global.mainCount * 20),
    (global.reviewMin, global.reviewMax, global.reviewCount * 20),
    (global.sprintMin, global.sprintMax, global.sprintCount * 20),
    (global.surpriseMin, global.surpriseMax, global.surpriseCount * 25),
  ];

  final byWord = <String, Idiom>{};
  for (final (minD, maxD, limit) in zones) {
    if (minD <= 0 || maxD < minD) continue;
    final rows = await db.findIdiomsByDifficulty(
      minD,
      maxD,
      limit,
      randomOrder: seed == null,
    );
    for (final row in rows) {
      if (excludedIds.contains(row.id)) continue;
      byWord.putIfAbsent(row.word, () => row);
    }
  }
  if (byWord.length < 5) return null;

  final engineIdioms = byWord.values
      .map(
        (i) => engine.Idiom(
          text: i.word,
          pinyin: i.pinyin,
          meaning: i.explanation,
          difficulty: i.difficulty,
          source: i.derivation ?? '',
        ),
      )
      .toList();

  final graph = CrossingGraph(idioms: engineIdioms);
  final generator = IntegratedGenerator(
    graph: graph,
    random: seed == null ? null : Random(seed),
  );
  final level = generator.generate(
    targetSize: global.targetSize,
    minDifficulty: 1,
    maxDifficulty: 50,
    maxAttempts: maxAttempts,
    levelNumber: levelNumber,
  );
  return level == null || title == null
      ? level
      : engine.CrosswordLevel(
          levelId: level.levelId,
          grid: level.grid,
          placements: level.placements,
          givenCharacters: level.givenCharacters,
          title: title,
          storyHint: level.storyHint,
        );
}

/// 螺旋基准难度放宽 ±2，并覆盖长尾/预览区间的取数范围
(int, int) _spiralRange(int levelNumber) {
  final spiral = SpiralDifficulty.calculate(levelNumber);
  final tailMin = spiral.tailMin <= 0 ? spiral.mainMin : spiral.tailMin;
  final previewMax = spiral.previewMax <= 0
      ? spiral.mainMax
      : spiral.previewMax;
  return ((tailMin - 2).clamp(1, 50), (previewMax + 2).clamp(1, 50));
}

/// 进入关卡：优先恢复未完成存档，没有存档才新生成
Future<engine.CrosswordLevel?> loadOrGenerateLevel(
  AppDatabase db,
  int levelNumber, {
  bool globalRange = false,
  int playerLevel = 1,
}) async {
  final saved = await loadExistingLevel(db, levelNumber);
  if (saved != null) return saved;
  // 3) 否则新生成
  return generateLevel(
    db,
    levelNumber,
    globalRange: globalRange,
    playerLevel: playerLevel,
  );
}

/// 已作答存档、预生成题面、已通关冻结定义均优先复用。
Future<engine.CrosswordLevel?> loadExistingLevel(
  AppDatabase db,
  int levelNumber,
) async {
  // 1) 未完成存档优先（断点续玩）
  final saved = await db.getLevelState(levelNumber);
  if (saved != null) {
    final restored = decodeLevel(saved.levelJson);
    if (restored != null) return restored;
  }
  // 2) 已通关关卡使用冻结定义（保证每次进入同一题）
  final frozen = await db.getLevelDefinition(levelNumber);
  if (frozen != null) {
    final restored = decodeLevel(frozen);
    if (restored != null) return restored;
  }
  return null;
}

# Growth System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the imperial examination growth system with 20 levels, exponential XP curve, spiral difficulty model, and item system.

**Architecture:** 
- Data layer: SQLite tables for player progress, collections, level history, decorations
- Logic layer: Growth system manager, spiral difficulty calculator, reward system
- Integration: Extend IntegratedGenerator to accept spiral difficulty parameters

**Tech Stack:** Flutter 3.44.2, Dart 3.12.2, drift (SQLite ORM), flutter_riverpod

## Global Constraints

- Flutter 3.44.2 + Dart 3.12.2
- iOS 15.0 minimum
- SQLite via drift package
- All idioms have difficulty 1-50 from scoring_progress.json
- Test with `flutter test`

---

## File Structure

```
lib/src/
├── engine/
│   ├── integrated_generator.dart  (modify: accept spiral params)
│   └── spiral_difficulty.dart     (create: spiral calculation)
├── data/
│   ├── database.dart              (modify: add new tables)
│   ├── database_schema_v2.dart    (modify: add player tables)
│   └── growth_manager.dart        (create: growth logic)
├── state/
│   └── player_state.dart          (create: riverpod state)
└── ui/
    ├── widgets/
    │   ├── level_display.dart     (create: level badge + progress)
    │   └── shop_screen.dart       (create: item shop)
    └── screens/
        └── game_screen.dart       (modify: integrate growth)

test/
├── engine/
│   └── spiral_difficulty_test.dart (create)
└── data/
    └── growth_manager_test.dart    (create)
```

---

## Task 1: Spiral Difficulty Calculator

**Files:**
- Create: `lib/src/engine/spiral_difficulty.dart`
- Create: `test/engine/spiral_difficulty_test.dart`

**Interfaces:**
- Consumes: level number (int), total levels (10000+)
- Produces: `SpiralDifficultyResult` with baseDifficulty, mainRange, tailRange, previewRange

- [ ] **Step 1: Write the failing test**

```dart
// test/engine/spiral_difficulty_test.dart
import 'package:idiom_crossword/src/engine/spiral_difficulty.dart';
import 'package:test/test.dart';

void main() {
  group('SpiralDifficulty', () {
    test('level 1 should have base difficulty 1', () {
      final result = SpiralDifficulty.calculate(1);
      expect(result.baseDifficulty, 1);
    });

    test('level 200 should have base difficulty 1', () {
      final result = SpiralDifficulty.calculate(200);
      expect(result.baseDifficulty, 1);
    });

    test('level 201 should have base difficulty 2', () {
      final result = SpiralDifficulty.calculate(201);
      expect(result.baseDifficulty, 2);
    });

    test('level 10000 should have base difficulty 50', () {
      final result = SpiralDifficulty.calculate(10000);
      expect(result.baseDifficulty, 50);
    });

    test('main range should be base ± 3', () {
      final result = SpiralDifficulty.calculate(1000);
      expect(result.mainMin, greaterThanOrEqualTo(1));
      expect(result.mainMax, lessThanOrEqualTo(50));
      expect(result.mainMax - result.mainMin, 6); // ±3 = range of 6
    });

    test('tail range should be 5-10 below base', () {
      final result = SpiralDifficulty.calculate(1000);
      if (result.tailMax > 0) {
        expect(result.tailMax, lessThan(result.baseDifficulty));
        expect(result.tailMin, greaterThanOrEqualTo(1));
      }
    });

    test('preview range should be 3-5 above base', () {
      final result = SpiralDifficulty.calculate(1000);
      if (result.previewMax > 0) {
        expect(result.previewMin, greaterThan(result.baseDifficulty));
        expect(result.previewMax, lessThanOrEqualTo(50));
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/engine/spiral_difficulty_test.dart`
Expected: FAIL with "class 'SpiralDifficulty' not found"

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/engine/spiral_difficulty.dart
/// 螺旋难度计算器
/// 
/// 根据关卡编号计算该关的难度分布：
/// - baseDifficulty: 基准难度 (1-50)
/// - mainRange: 主体难度范围 (base ± 3)
/// - tailRange: 长尾难度范围 (base - 10 to base - 5)
/// - previewRange: 预览难度范围 (base + 3 to base + 5)

class SpiralDifficultyResult {
  final int baseDifficulty;
  final int mainMin;
  final int mainMax;
  final int tailMin;
  final int tailMax;
  final int previewMin;
  final int previewMax;

  const SpiralDifficultyResult({
    required this.baseDifficulty,
    required this.mainMin,
    required this.mainMax,
    required this.tailMin,
    required this.tailMax,
    required this.previewMin,
    required this.previewMax,
  });
}

class SpiralDifficulty {
  /// 计算关卡的螺旋难度分布
  /// 
  /// [levelNumber] 关卡编号 (1-based)
  /// [totalLevels] 总关卡数 (默认 10000)
  static SpiralDifficultyResult calculate(
    int levelNumber, {
    int totalLevels = 10000,
  }) {
    // 基准难度 = ceil(关卡编号 / 200)，映射到 1-50
    final baseDifficulty = ((levelNumber - 1) ~/ 200 + 1).clamp(1, 50);
    
    // 主体范围：base ± 3
    final mainMin = (baseDifficulty - 3).clamp(1, 50);
    final mainMax = (baseDifficulty + 3).clamp(1, 50);
    
    // 长尾范围：base - 10 to base - 5（如果 base > 5）
    final tailMin = baseDifficulty > 5 ? (baseDifficulty - 10).clamp(1, 50) : 0;
    final tailMax = baseDifficulty > 5 ? (baseDifficulty - 5).clamp(1, 50) : 0;
    
    // 预览范围：base + 3 to base + 5（如果 base < 45）
    final previewMin = baseDifficulty < 45 ? (baseDifficulty + 3).clamp(1, 50) : 0;
    final previewMax = baseDifficulty < 45 ? (baseDifficulty + 5).clamp(1, 50) : 0;
    
    return SpiralDifficultyResult(
      baseDifficulty: baseDifficulty,
      mainMin: mainMin,
      mainMax: mainMax,
      tailMin: tailMin,
      tailMax: tailMax,
      previewMin: previewMin,
      previewMax: previewMax,
    );
  }
  
  /// 根据螺旋难度选择成语数量
  /// 
  /// [levelNumber] 关卡编号
  /// 返回：(主体数量, 长尾数量, 预览数量)
  static (int mainCount, int tailCount, int previewCount) selectIdiomCounts(
    int levelNumber,
  ) {
    if (levelNumber <= 5) {
      // 教学关：固定 5 条
      return (5, 0, 0);
    } else if (levelNumber <= 200) {
      // 过渡关：6 条
      return (5, 1, 0);
    } else {
      // 正式关：8-12 条（7-9 主体 + 1-2 长尾 + 0-1 预览）
      final random = DateTime.now().microsecondsSinceEpoch;
      final mainCount = 7 + (random % 3); // 7-9
      final tailCount = 1 + (random % 2); // 1-2
      final previewCount = random % 2; // 0-1
      return (mainCount, tailCount, previewCount);
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/engine/spiral_difficulty_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/engine/spiral_difficulty.dart test/engine/spiral_difficulty_test.dart
git commit -m "feat: add spiral difficulty calculator"
```

---

## Task 2: Growth System Manager

**Files:**
- Create: `lib/src/data/growth_manager.dart`
- Create: `test/data/growth_manager_test.dart`

**Interfaces:**
- Consumes: player progress from database
- Produces: `PlayerProgress`, `LevelReward`, `ExperienceResult`

- [ ] **Step 1: Write the failing test**

```dart
// test/data/growth_manager_test.dart
import 'package:idiom_crossword/src/data/growth_manager.dart';
import 'package:test/test.dart';

void main() {
  group('GrowthManager', () {
    test('XP formula should match design doc', () {
      // XP(n) = 100 × 1.6^(n-1)
      expect(GrowthManager.xpForLevel(1), 100);
      expect(GrowthManager.xpForLevel(2), 160);
      expect(GrowthManager.xpForLevel(5), 409);
      expect(GrowthManager.xpForLevel(10), 1074);
    });

    test('level from XP should be correct', () {
      expect(GrowthManager.levelFromXp(0), 1);
      expect(GrowthManager.levelFromXp(100), 2);
      expect(GrowthManager.levelFromXp(260), 3);
      expect(GrowthManager.levelFromXp(10000), 10);
    });

    test('reward for level should return correct type', () {
      final reward1 = GrowthManager.rewardForLevel(1);
      expect(reward1.type, RewardType.functional);
      expect(reward1.item, 'hint_card');
      expect(reward1.quantity, 3);

      final reward3 = GrowthManager.rewardForLevel(3);
      expect(reward3.type, RewardType.decoration);
      expect(reward3.item, 'grid_skin_bamboo');
    });

    test('title for level should return correct title', () {
      expect(GrowthManager.titleForLevel(1), '童生');
      expect(GrowthManager.titleForLevel(5), '举人');
      expect(GrowthManager.titleForLevel(12), '状元');
      expect(GrowthManager.titleForLevel(20), '位极人臣');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/data/growth_manager_test.dart`
Expected: FAIL with "class 'GrowthManager' not found"

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/src/data/growth_manager.dart
/// 成长系统管理器
/// 
/// 负责：
/// - 经验值计算（暴雪式指数曲线）
/// - 等级判定
/// - 升级奖励
/// - 称号管理

enum RewardType { functional, decoration }

class LevelReward {
  final RewardType type;
  final String item;
  final int quantity;

  const LevelReward({
    required this.type,
    required this.item,
    required this.quantity,
  });
}

class PlayerProgress {
  final int level;
  final int totalXp;
  final int completedLevels;
  final Map<String, int> functionalItems; // hint_card: 5, revive_card: 2
  final Set<String> ownedDecorations; // grid_skin_bamboo, avatar_frame_wusha

  const PlayerProgress({
    required this.level,
    required this.totalXp,
    required this.completedLevels,
    required this.functionalItems,
    required this.ownedDecorations,
  });
}

class ExperienceResult {
  final int xpGained;
  final bool leveledUp;
  final int newLevel;
  final LevelReward? reward;

  const ExperienceResult({
    required this.xpGained,
    required this.leveledUp,
    required this.newLevel,
    this.reward,
  });
}

class GrowthManager {
  /// 升级所需经验值公式：XP(n) = 100 × 1.6^(n-1)
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    return (100 * pow(1.6, level - 2)).round();
  }

  /// 根据总经验值计算当前等级
  static int levelFromXp(int totalXp) {
    int level = 1;
    int xpNeeded = 0;
    while (level < 20) {
      xpNeeded += xpForLevel(level + 1);
      if (totalXp < xpNeeded) break;
      level++;
    }
    return level;
  }

  /// 升级奖励配置
  static const Map<int, LevelReward> _rewards = {
    1: LevelReward(type: RewardType.functional, item: 'hint_card', quantity: 3),
    2: LevelReward(type: RewardType.functional, item: 'hint_card', quantity: 2),
    3: LevelReward(type: RewardType.decoration, item: 'grid_skin_bamboo', quantity: 1),
    4: LevelReward(type: RewardType.functional, item: 'revive_card', quantity: 1),
    5: LevelReward(type: RewardType.decoration, item: 'avatar_frame_wusha', quantity: 1),
    6: LevelReward(type: RewardType.functional, item: 'hint_card', quantity: 3),
    7: LevelReward(type: RewardType.decoration, item: 'grid_skin_paper', quantity: 1),
    8: LevelReward(type: RewardType.functional, item: 'revive_card', quantity: 2),
    9: LevelReward(type: RewardType.decoration, item: 'title_effect_jinbang', quantity: 1),
    10: LevelReward(type: RewardType.functional, item: 'hint_card', quantity: 5),
    11: LevelReward(type: RewardType.decoration, item: 'grid_skin_dragon', quantity: 1),
    12: LevelReward(type: RewardType.functional, item: 'revive_card', quantity: 3),
    13: LevelReward(type: RewardType.decoration, item: 'avatar_frame_xiezhi', quantity: 1),
    14: LevelReward(type: RewardType.functional, item: 'hint_card', quantity: 5),
    15: LevelReward(type: RewardType.decoration, item: 'grid_skin_gold', quantity: 1),
    16: LevelReward(type: RewardType.functional, item: 'revive_card', quantity: 5),
    17: LevelReward(type: RewardType.decoration, item: 'title_effect_tianzi', quantity: 1),
    18: LevelReward(type: RewardType.decoration, item: 'avatar_frame_sangong', quantity: 1),
    19: LevelReward(type: RewardType.decoration, item: 'grid_skin_emperor', quantity: 1),
    20: LevelReward(type: RewardType.decoration, item: 'custom_title_unlock', quantity: 1),
  };

  /// 获取升级奖励
  static LevelReward? rewardForLevel(int level) => _rewards[level];

  /// 称号配置
  static const Map<int, String> _titles = {
    1: '童生',
    2: '生员',
    3: '廪生',
    4: '贡生',
    5: '举人',
    6: '解元',
    7: '会元',
    8: '进士',
    9: '殿试',
    10: '探花',
    11: '榜眼',
    12: '状元',
    13: '编修',
    14: '侍郎',
    15: '尚书',
    16: '大学士',
    17: '太子少师',
    18: '太傅',
    19: '太师',
    20: '位极人臣',
  };

  /// 获取称号
  static String titleForLevel(int level) => _titles[level] ?? '童生';

  /// 计算通关获得的经验值
  /// 
  /// [levelNumber] 关卡编号
  /// [idiomDifficulties] 该关成语的难度列表
  static int calculateXp(int levelNumber, List<int> idiomDifficulties) {
    if (levelNumber <= 5) {
      return 10; // 教学关固定 10 经验
    }
    final avgDifficulty = idiomDifficulties.reduce((a, b) => a + b) / 
        idiomDifficulties.length;
    return (avgDifficulty * 2).round();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/data/growth_manager_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/data/growth_manager.dart test/data/growth_manager_test.dart
git commit -m "feat: add growth system manager with XP formula and rewards"
```

---

## Task 3: Database Schema Update

**Files:**
- Modify: `lib/src/data/database_schema_v2.dart`
- Modify: `lib/src/data/database.dart`

**Interfaces:**
- Consumes: existing idiom table
- Produces: new tables for player_progress, collection, level_history, decoration

- [ ] **Step 1: Add new table definitions to schema**

```dart
// lib/src/data/database_schema_v2.dart - add at end of file

// ============================================================
// 玩家进度表
// ============================================================
/*
  TABLE player_progress (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    level           INTEGER NOT NULL DEFAULT 1,
    total_xp        INTEGER NOT NULL DEFAULT 0,
    completed_levels INTEGER NOT NULL DEFAULT 0,
    hint_cards      INTEGER NOT NULL DEFAULT 0,
    revive_cards    INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
  );
*/

// ============================================================
// 收藏成语表
// ============================================================
/*
  TABLE collection (
    idiom_id        INTEGER NOT NULL REFERENCES idiom(id) ON DELETE CASCADE,
    collected_at    TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (idiom_id)
  );
*/

// ============================================================
// 关卡通关记录表
// ============================================================
/*
  TABLE level_history (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    level_number    INTEGER NOT NULL,
    completed_at    TEXT NOT NULL DEFAULT (datetime('now')),
    xp_gained       INTEGER NOT NULL,
    idioms_used     TEXT NOT NULL,  -- JSON array of idiom IDs
    time_spent_ms   INTEGER,
    hints_used      INTEGER DEFAULT 0
  );
  CREATE INDEX idx_lh_level ON level_history(level_number);
*/

// ============================================================
// 装饰道具拥有状态表
// ============================================================
/*
  TABLE decoration (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    decoration_type TEXT NOT NULL,  -- 'grid_skin', 'avatar_frame', 'title_effect'
    decoration_id   TEXT NOT NULL,  -- 'bamboo', 'wusha', 'jinbang'
    owned_at        TEXT NOT NULL DEFAULT (datetime('now')),
    is_active       INTEGER DEFAULT 0,  -- 是否当前使用
    UNIQUE(decoration_type, decoration_id)
  );
*/
```

- [ ] **Step 2: Update database.dart with DAO methods**

```dart
// Add to lib/src/data/database.dart

// Player Progress DAO
Future<PlayerProgress?> getPlayerProgress() async {
  // Query player_progress table
  // Return PlayerProgress object or default
}

Future<void> updatePlayerProgress({
  required int level,
  required int totalXp,
  required int completedLevels,
  required int hintCards,
  required int reviveCards,
}) async {
  // Update player_progress table
}

// Collection DAO
Future<void> addToCollection(int idiomId) async {
  // Insert into collection table
}

Future<List<int>> getCollection() async {
  // Query all collected idiom IDs
}

Future<bool> isInCollection(int idiomId) async {
  // Check if idiom is in collection
}

// Level History DAO
Future<void> addLevelHistory({
  required int levelNumber,
  required int xpGained,
  required List<int> idiomsUsed,
  int? timeSpentMs,
  int hintsUsed = 0,
}) async {
  // Insert into level_history table
}

// Decoration DAO
Future<void> addDecoration(String type, String id) async {
  // Insert into decoration table
}

Future<List<String>> getOwnedDecorations(String type) async {
  // Query decorations by type
}

Future<void> setActiveDecoration(String type, String id) async {
  // Set is_active for decoration
}
```

- [ ] **Step 3: Run flutter analyze to verify no errors**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/src/data/database_schema_v2.dart lib/src/data/database.dart
git commit -m "feat: add database tables for growth system"
```

---

## Task 4: Integrate Spiral Difficulty with IntegratedGenerator

**Files:**
- Modify: `lib/src/engine/integrated_generator.dart`

**Interfaces:**
- Consumes: `SpiralDifficultyResult` from Task 1
- Produces: `CrosswordLevel` with difficulty metadata

- [ ] **Step 1: Add spiral difficulty parameter to generate method**

```dart
// lib/src/engine/integrated_generator.dart

// Modify generate method signature
CrosswordLevel? generate({
  required int targetSize,
  required int minDifficulty,
  required int maxDifficulty,
  int maxAttempts = 50,
  int? levelNumber,  // NEW: for spiral difficulty
  SpiralDifficultyResult? spiralResult,  // NEW: pre-calculated spiral
}) {
  // If spiralResult provided, use it to determine difficulty ranges
  if (spiralResult != null) {
    // Use spiral ranges instead of min/maxDifficulty
    minDifficulty = spiralResult.mainMin;
    maxDifficulty = spiralResult.mainMax;
  }
  
  // ... existing implementation
}
```

- [ ] **Step 2: Add spiral-aware generation method**

```dart
/// 生成螺旋难度关卡
/// 
/// [levelNumber] 关卡编号 (1-based)
/// [totalLevels] 总关卡数
CrosswordLevel? generateSpiral({
  required int levelNumber,
  int totalLevels = 10000,
  int maxAttempts = 50,
}) {
  final spiral = SpiralDifficulty.calculate(levelNumber);
  final (mainCount, tailCount, previewCount) = 
      SpiralDifficulty.selectIdiomCounts(levelNumber);
  
  final targetSize = mainCount + tailCount + previewCount;
  
  // First try with main range
  var level = generate(
    targetSize: targetSize,
    minDifficulty: spiral.mainMin,
    maxDifficulty: spiral.mainMax,
    maxAttempts: maxAttempts ~/ 2,
  );
  
  // If failed, try with wider range
  level ??= generate(
    targetSize: targetSize,
    minDifficulty: (spiral.mainMin - 2).clamp(1, 50),
    maxDifficulty: (spiral.mainMax + 2).clamp(1, 50),
    maxAttempts: maxAttempts ~/ 2,
  );
  
  return level;
}
```

- [ ] **Step 3: Run existing tests to verify no regression**

Run: `flutter test test/engine/integrated_gen_test.dart`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/src/engine/integrated_generator.dart
git commit -m "feat: integrate spiral difficulty with IntegratedGenerator"
```

---

## Task 5: Player State (Riverpod)

**Files:**
- Create: `lib/src/state/player_state.dart`

**Interfaces:**
- Consumes: `GrowthManager` from Task 2, database from Task 3
- Produces: `PlayerState` notifier for UI

- [ ] **Step 1: Create player state provider**

```dart
// lib/src/state/player_state.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/growth_manager.dart';
import '../data/database.dart';

class PlayerState {
  final int level;
  final int totalXp;
  final int xpToNextLevel;
  final String title;
  final int completedLevels;
  final Map<String, int> functionalItems;
  final Set<String> ownedDecorations;

  const PlayerState({
    required this.level,
    required this.totalXp,
    required this.xpToNextLevel,
    required this.title,
    required this.completedLevels,
    required this.functionalItems,
    required this.ownedDecorations,
  });

  double get xpProgress {
    if (xpToNextLevel == 0) return 1.0;
    final currentLevelXp = totalXp - _xpForPreviousLevels();
    return currentLevelXp / xpToNextLevel;
  }

  int _xpForPreviousLevels() {
    int total = 0;
    for (int i = 1; i < level; i++) {
      total += GrowthManager.xpForLevel(i);
    }
    return total;
  }
}

class PlayerNotifier extends StateNotifier<PlayerState> {
  final Database _db;

  PlayerNotifier(this._db) : super(const PlayerState(
    level: 1,
    totalXp: 0,
    xpToNextLevel: 100,
    title: '童生',
    completedLevels: 0,
    functionalItems: {},
    ownedDecorations: {},
  )) {
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final progress = await _db.getPlayerProgress();
    if (progress != null) {
      state = PlayerState(
        level: progress.level,
        totalXp: progress.totalXp,
        xpToNextLevel: GrowthManager.xpForLevel(progress.level + 1),
        title: GrowthManager.titleForLevel(progress.level),
        completedLevels: progress.completedLevels,
        functionalItems: {
          'hint_card': progress.hintCards,
          'revive_card': progress.reviveCards,
        },
        ownedDecorations: await _db.getOwnedDecorations().then(
          (list) => list.toSet(),
        ),
      );
    }
  }

  Future<ExperienceResult> completeLevel(
    int levelNumber,
    List<int> idiomDifficulties,
  ) async {
    final xp = GrowthManager.calculateXp(levelNumber, idiomDifficulties);
    final oldLevel = state.level;
    final newTotalXp = state.totalXp + xp;
    final newLevel = GrowthManager.levelFromXp(newTotalXp);
    final leveledUp = newLevel > oldLevel;
    final reward = leveledUp ? GrowthManager.rewardForLevel(newLevel) : null;

    // Update state
    state = PlayerState(
      level: newLevel,
      totalXp: newTotalXp,
      xpToNextLevel: GrowthManager.xpForLevel(newLevel + 1),
      title: GrowthManager.titleForLevel(newLevel),
      completedLevels: state.completedLevels + 1,
      functionalItems: _applyReward(state.functionalItems, reward),
      ownedDecorations: state.ownedDecorations,
    );

    // Persist to database
    await _db.updatePlayerProgress(
      level: newLevel,
      totalXp: newTotalXp,
      completedLevels: state.completedLevels,
      hintCards: state.functionalItems['hint_card'] ?? 0,
      reviveCards: state.functionalItems['revive_card'] ?? 0,
    );

    // Record level history
    await _db.addLevelHistory(
      levelNumber: levelNumber,
      xpGained: xp,
      idiomsUsed: idiomDifficulties, // This should be idiom IDs
    );

    return ExperienceResult(
      xpGained: xp,
      leveledUp: leveledUp,
      newLevel: newLevel,
      reward: reward,
    );
  }

  Map<String, int> _applyReward(Map<String, int> items, LevelReward? reward) {
    if (reward == null || reward.type != RewardType.functional) return items;
    final updated = Map<String, int>.from(items);
    updated[reward.item] = (updated[reward.item] ?? 0) + reward.quantity;
    return updated;
  }

  Future<void> useHintCard() async {
    final current = state.functionalItems['hint_card'] ?? 0;
    if (current > 0) {
      state = PlayerState(
        level: state.level,
        totalXp: state.totalXp,
        xpToNextLevel: state.xpToNextLevel,
        title: state.title,
        completedLevels: state.completedLevels,
        functionalItems: {...state.functionalItems, 'hint_card': current - 1},
        ownedDecorations: state.ownedDecorations,
      );
      await _db.updatePlayerProgress(
        level: state.level,
        totalXp: state.totalXp,
        completedLevels: state.completedLevels,
        hintCards: current - 1,
        reviveCards: state.functionalItems['revive_card'] ?? 0,
      );
    }
  }
}

final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>(
  (ref) => PlayerNotifier(Database()),
);
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/src/state/player_state.dart
git commit -m "feat: add player state with Riverpod"
```

---

## Task 6: Level Display Widget

**Files:**
- Create: `lib/src/ui/widgets/level_display.dart`

**Interfaces:**
- Consumes: `PlayerState` from Task 5
- Produces: Widget showing level badge and progress bar

- [ ] **Step 1: Create level display widget**

```dart
// lib/src/ui/widgets/level_display.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';

class LevelDisplay extends ConsumerWidget {
  const LevelDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Level badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _iconForLevel(player.level),
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Lv.${player.level} ${player.title}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // XP progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '经验值',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${player.totalXp} / ${player.totalXp + player.xpToNextLevel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: player.xpProgress,
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForLevel(int level) {
    if (level >= 20) return Icons.emoji_events; // 位极人臣
    if (level >= 16) return Icons.school; // 大学士+
    if (level >= 12) return Icons.workspace_premium; // 状元+
    if (level >= 8) return Icons.book; // 进士+
    if (level >= 4) return Icons.person; // 贡生+
    return Icons.menu_book; // 童生+
  }
}
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/src/ui/widgets/level_display.dart
git commit -m "feat: add level display widget"
```

---

## Task 7: Integrate Growth System into Game Screen

**Files:**
- Modify: `lib/src/ui/screens/game_screen.dart`

**Interfaces:**
- Consumes: `PlayerState` from Task 5, `LevelDisplay` from Task 6
- Produces: Updated game screen with growth system integration

- [ ] **Step 1: Add level display to game screen**

```dart
// lib/src/ui/screens/game_screen.dart

// Add import
import '../widgets/level_display.dart';
import '../../state/player_state.dart';

// In build method, add LevelDisplay to UI
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('成语填字'),
      actions: [
        // Add level display in app bar
        const Padding(
          padding: EdgeInsets.only(right: 16),
          child: LevelDisplay(),
        ),
      ],
    ),
    body: // ... existing body
  );
}

// In _onLevelComplete method, add experience gain
void _onLevelComplete() {
  final player = ref.read(playerProvider.notifier);
  final result = player.completeLevel(
    _currentLevelNumber,
    _currentIdioms.map((i) => i.difficulty).toList(),
  );
  
  // Show reward animation if leveled up
  if (result.leveledUp && result.reward != null) {
    _showRewardDialog(result.newLevel, result.reward!);
  }
}
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/src/ui/screens/game_screen.dart
git commit -m "feat: integrate growth system into game screen"
```

---

## Task 8: Collection System

**Files:**
- Create: `lib/src/ui/screens/collection_screen.dart`

**Interfaces:**
- Consumes: database collection table
- Produces: UI for viewing collected idioms

- [ ] **Step 1: Create collection screen**

```dart
// lib/src/ui/screens/collection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';
import '../../data/database.dart';

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('成语收藏'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadCollection(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final collection = snapshot.data!;
          if (collection.isEmpty) {
            return const Center(
              child: Text('还没有收藏任何成语\n通关后自动收录'),
            );
          }
          
          return ListView.builder(
            itemCount: collection.length,
            itemBuilder: (context, index) {
              final idiom = collection[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text(
                    idiom['word'],
                    style: const TextStyle(fontSize: 20),
                  ),
                  subtitle: Text(idiom['explanation']),
                  trailing: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _difficultyColor(idiom['difficulty']),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${idiom['difficulty']}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadCollection() async {
    final db = Database();
    final collection = await db.getCollection();
    // Load full idiom details for each collected idiom
    // This is a placeholder - implement actual query
    return [];
  }

  Color _difficultyColor(int difficulty) {
    if (difficulty <= 10) return Colors.green;
    if (difficulty <= 20) return Colors.blue;
    if (difficulty <= 30) return Colors.orange;
    if (difficulty <= 40) return Colors.red;
    return Colors.purple;
  }
}
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/src/ui/screens/collection_screen.dart
git commit -m "feat: add collection screen"
```

---

## Task 9: Shop Screen

**Files:**
- Create: `lib/src/ui/widgets/shop_screen.dart`

**Interfaces:**
- Consumes: `PlayerState` from Task 5
- Produces: UI for purchasing items

- [ ] **Step 1: Create shop screen**

```dart
// lib/src/ui/widgets/shop_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('商城'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '功能道具'),
              Tab(text: '装饰道具'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FunctionalItemsTab(player: player),
            _DecorationItemsTab(player: player),
          ],
        ),
      ),
    );
  }
}

class _FunctionalItemsTab extends StatelessWidget {
  final PlayerState player;
  
  const _FunctionalItemsTab({required this.player});
  
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _ShopItem(
          name: '提示卡×10',
          description: '揭示单个空格答案',
          price: '¥6',
          onPurchase: () {
            // TODO: Implement IAP
          },
        ),
        _ShopItem(
          name: '复活卡×5',
          description: '失败后可继续当前关',
          price: '¥12',
          onPurchase: () {
            // TODO: Implement IAP
          },
        ),
      ],
    );
  }
}

class _DecorationItemsTab extends StatelessWidget {
  final PlayerState player;
  
  const _DecorationItemsTab({required this.player});
  
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _ShopItem(
          name: '龙纹网格皮肤',
          description: '限定装饰',
          price: '¥18',
          isOwned: player.ownedDecorations.contains('grid_skin_dragon'),
          onPurchase: () {
            // TODO: Implement IAP
          },
        ),
        _ShopItem(
          name: '獬豸冠头像框',
          description: '限定装饰',
          price: '¥12',
          isOwned: player.ownedDecorations.contains('avatar_frame_xiezhi'),
          onPurchase: () {
            // TODO: Implement IAP
          },
        ),
      ],
    );
  }
}

class _ShopItem extends StatelessWidget {
  final String name;
  final String description;
  final String price;
  final bool isOwned;
  final VoidCallback onPurchase;
  
  const _ShopItem({
    required this.name,
    required this.description,
    required this.price,
    this.isOwned = false,
    required this.onPurchase,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(name),
        subtitle: Text(description),
        trailing: isOwned
            ? const Chip(label: Text('已拥有'))
            : ElevatedButton(
                onPressed: onPurchase,
                child: Text(price),
              ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/src/ui/widgets/shop_screen.dart
git commit -m "feat: add shop screen with IAP placeholders"
```

---

## Task 10: End-to-End Integration Test

**Files:**
- Create: `test/integration/growth_system_test.dart`

**Interfaces:**
- Consumes: All previous tasks
- Produces: Integration test verifying full flow

- [ ] **Step 1: Write integration test**

```dart
// test/integration/growth_system_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/spiral_difficulty.dart';
import 'package:idiom_crossword/src/data/growth_manager.dart';

void main() {
  group('Growth System Integration', () {
    test('full flow: level 1 to level 2', () {
      // Start at level 1
      var totalXp = 0;
      var level = GrowthManager.levelFromXp(totalXp);
      expect(level, 1);
      
      // Complete 20 levels (each gives 10 xp in tutorial)
      for (int i = 1; i <= 20; i++) {
        totalXp += GrowthManager.calculateXp(i, [1, 1, 1, 1, 1]);
      }
      
      // Should be level 2 now
      level = GrowthManager.levelFromXp(totalXp);
      expect(level, 2);
    });

    test('spiral difficulty generates valid ranges', () {
      for (int levelNum = 1; levelNum <= 10000; levelNum += 100) {
        final result = SpiralDifficulty.calculate(levelNum);
        expect(result.baseDifficulty, greaterThanOrEqualTo(1));
        expect(result.baseDifficulty, lessThanOrEqualTo(50));
        expect(result.mainMin, greaterThanOrEqualTo(1));
        expect(result.mainMax, lessThanOrEqualTo(50));
        expect(result.mainMin, lessThanOrEqualTo(result.mainMax));
      }
    });

    test('rewards are assigned correctly', () {
      expect(GrowthManager.rewardForLevel(1)?.item, 'hint_card');
      expect(GrowthManager.rewardForLevel(3)?.item, 'grid_skin_bamboo');
      expect(GrowthManager.rewardForLevel(20)?.item, 'custom_title_unlock');
    });
  });
}
```

- [ ] **Step 2: Run integration test**

Run: `flutter test test/integration/growth_system_test.dart`
Expected: PASS

- [ ] **Step 3: Run all tests**

Run: `flutter test`
Expected: All tests pass

- [ ] **Step 4: Final commit**

```bash
git add test/integration/growth_system_test.dart
git commit -m "feat: add growth system integration tests"
```

---

## Summary

| Task | Description | Files Created/Modified |
|------|-------------|----------------------|
| 1 | Spiral Difficulty Calculator | spiral_difficulty.dart |
| 2 | Growth System Manager | growth_manager.dart |
| 3 | Database Schema Update | database_schema_v2.dart, database.dart |
| 4 | Integrate with IntegratedGenerator | integrated_generator.dart |
| 5 | Player State (Riverpod) | player_state.dart |
| 6 | Level Display Widget | level_display.dart |
| 7 | Integrate into Game Screen | game_screen.dart |
| 8 | Collection System | collection_screen.dart |
| 9 | Shop Screen | shop_screen.dart |
| 10 | Integration Test | growth_system_test.dart |

**Total estimated time:** 4-6 hours for a skilled developer

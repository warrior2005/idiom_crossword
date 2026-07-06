# Pattern Collision Disambiguation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a disambiguation step to level generation that pre-fills extra characters to break identical visible patterns between placement slots.

**Architecture:** A new function in `integrated_generator.dart` that runs after `_buildLevel` constructs the grid but before the `CrosswordLevel` is returned. Detects pattern collisions between all placement pairs and resolves each by pre-filling (setting `isGiven = true`) one additional character.

**Tech Stack:** Dart, existing `CrosswordGrid`, `Placement`, `Cell` types.

## Global Constraints

- No new dependencies.
- Only modify `lib/src/engine/integrated_generator.dart`.
- Disambiguation runs after placements are finalized, before returning `CrosswordLevel`.

---

### Task 1: `_visiblePattern` helper

**Files:**
- Modify: `lib/src/engine/integrated_generator.dart` (new method on `IntegratedGenerator`)

**Interfaces:**
- Produces: `String _visiblePattern(Placement p)` — returns e.g. `"大___"`

- [ ] **Step 1: Write the failing test**

In a test file, call the function with a placement where first char is given:
```dart
final grid = CrosswordGrid(rows: 4, cols: 4);
// set up: cell(0,0).isGiven = true, cell(0,0).character = '大'
//         cell(0,1-3).isGiven = false
final placement = Placement(idiom: ..., startRow: 0, startCol: 0, direction: Direction.horizontal);
final pattern = generator._visiblePattern(placement);
assert(pattern == "大___");
```

- [ ] **Step 2: Run test to verify it fails**

Run: `dart test`
Expected: FAIL — `_visiblePattern` not defined

- [ ] **Step 3: Write minimal implementation**

Add to `IntegratedGenerator`:
```dart
/// Return the visible pattern string for a placement:
/// - actual character if isGiven
/// - '_' if not
String _visiblePattern(Placement p) {
  final buf = StringBuffer();
  for (int k = 0; k < p.idiom.text.length; k++) {
    final (r, c) = p.cellAt(k);
    final cell = grid.cellAt(r, c);  // Wait, grid isn't accessible here
  }
}
```

Wait — the generator doesn't have a reference to `CrosswordGrid` during `_buildLevel`... Actually, `_buildLevel` creates a `CrosswordGrid` and builds it up, then calls disambiguation on it before returning. So the disambiguation function needs the grid as a parameter.

Let me revise: the disambiguation method takes `(List<Placement> placements, CrosswordGrid grid)` and modifies `grid` in place.

Actually, looking at the `IntegratedGenerator` class — it has no instance state that persists between generate calls (except `graph` and `_random`). The grid is created inside `_buildLevel`. So I'll pass the grid as a parameter.

Let me revise the approach:

```dart
static String visiblePattern(Placement p, CrosswordGrid grid) {
  final buf = StringBuffer();
  for (int k = 0; k < p.idiom.text.length; k++) {
    final (r, c) = p.cellAt(k);
    final cell = grid.cellAt(r, c);
    buf.write(cell.isGiven ? cell.character : '_');
  }
  return buf.toString();
}
```

Make it static since it doesn't use instance state.

- [ ] **Step 4: Run test to verify it passes**

Run: `dart test`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/engine/integrated_generator.dart
git commit -m "feat: add visiblePattern helper for placement disambiguation"
```

---

### Task 2: `_slotCollisions` and `_disambiguate` methods

**Files:**
- Modify: `lib/src/engine/integrated_generator.dart`

**Interfaces:**
- Produces: `static void disambiguate(List<Placement> placements, CrosswordGrid grid)` — modifies grid in place, setting `isGiven = true` on selected cells.

- [ ] **Step 1: Write failing test**

```dart
// Two placements with same visible pattern
// Both: 大___  (大 is given, rest empty)
grid.cellAt(0,0).isGiven = true;
grid.cellAt(0,0).character = '大';
grid.cellAt(1,0).isGiven = true;
grid.cellAt(1,0).character = '大';
Placement a = Placement(idiom: 大声疾呼, startRow: 0, startCol: 0, dir: horizontal);
Placement b = Placement(idiom: 大有可为, startRow: 1, startCol: 0, dir: horizontal);

IntegratedGenerator.disambiguate([a, b], grid);

// After disambiguation, at least one of a or b should have an extra given cell
int givenA = ...; // count given cells in a
int givenB = ...; // count given cells in b
assert(givenA > 1 || givenB > 1);  // at least one got an extra given
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL — `disambiguate` not defined

- [ ] **Step 3: Write implementation**

```dart
static void disambiguate(List<Placement> placements, CrosswordGrid grid) {
  // Limit iterations to prevent infinite loops
  for (int iter = 0; iter < 20; iter++) {
    final collisions = _findCollisions(placements, grid);
    if (collisions.isEmpty) return;
    final (a, b) = collisions.first;
    _resolveCollision(a, b, placements, grid);
  }
}

static List<(Placement, Placement)> _findCollisions(
    List<Placement> placements, CrosswordGrid grid) {
  final result = <(Placement, Placement)>[];
  for (int i = 0; i < placements.length; i++) {
    for (int j = i + 1; j < placements.length; j++) {
      final a = placements[i];
      final b = placements[j];
      final patternA = visiblePattern(a, grid);
      final patternB = visiblePattern(b, grid);
      if (patternA != patternB) continue;
      // Skip if either has only 1 empty cell
      if (patternA.replaceAll('_', '').length >= a.idiom.text.length - 1) continue;
      if (patternB.replaceAll('_', '').length >= b.idiom.text.length - 1) continue;
      result.add((a, b));
    }
  }
  return result;
}

static void _resolveCollision(
    Placement a, Placement b,
    List<Placement> placements, CrosswordGrid grid) {
  // Collect candidate positions from both: non-crossing first, then crossing
  final candidates = <_PreFillCandidate>[];
  for (final p in [a, b]) {
    for (int k = 0; k < p.idiom.text.length; k++) {
      final (r, c) = p.cellAt(k);
      final cell = grid.cellAt(r, c);
      if (cell.isGiven) continue;
      // Check if this cell belongs to multiple placements (crossing)
      final crossingCount = placements.where((other) {
        for (int k2 = 0; k2 < other.idiom.text.length; k2++) {
          if (other.cellAt(k2) == (r, c)) return true;
        }
        return false;
      }).length;
      candidates.add(_PreFillCandidate(
        row: r, col: c, placement: p, isCrossing: crossingCount > 1,
      ));
    }
  }
  // non-crossing first
  candidates.sort((a, b) => a.isCrossing ? 1 : b.isCrossing ? -1 : 0);

  for (final cand in candidates) {
    // Try: set isGiven
    final cell = grid.cellAt(cand.row, cand.col);
    cell.isGiven = true;
    // Check: any new collisions?
    final newCollisions = _findCollisions(placements, grid);
    if (newCollisions.isEmpty) return;  // success
    // Revert
    cell.isGiven = false;
  }
  // All candidates failed — leave unresolved
}
```

- [ ] **Step 4: Run test**

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/src/engine/integrated_generator.dart
git commit -m "feat: add disambiguate method to resolve pattern collisions"
```

---

### Task 3: Wire disambiguation into `_buildLevel`

**Files:**
- Modify: `lib/src/engine/integrated_generator.dart`

**Interfaces:**
- Consumes: `disambiguate(placements, grid)` from Task 2

- [ ] **Step 1: Write failing test**

Test that generated level from `generate()` has no pattern collisions:

```dart
final level = generator.generate(targetSize: 5, minDifficulty: 1, maxDifficulty: 50);
if (level != null) {
  // Verify no collisions
  final patterns = level!.placements.map((p) => IntegratedGenerator.visiblePattern(p, level.grid)).toList();
  for (int i = 0; i < patterns.length; i++) {
    for (int j = i + 1; j < patterns.length; j++) {
      assert(patterns[i] != patterns[j], 'Collision: ${patterns[i]} == ${patterns[j]}');
    }
  }
}
```

But this test is probabilistic (might generate levels without collisions even without the fix). Let me test more directly.

Actually, Task 1 and 2 already have their own tests. For Task 3, the change is minimal — just one line added to `_buildLevel`. Let me verify by adding a print/grid state check.

Actually, the simplest: test that `disambiguate` is called by running generation and checking no collisions exist.

- [ ] **Step 2: Add call to `disambiguate` in `_buildLevel`**

```dart
// In _buildLevel, right before return:
IntegratedGenerator.disambiguate(placements, grid);
```

Place it right after the `givenChars` loop (after line 398), before the `return`:

```dart
    // 消歧义：在给定的 pattern 碰撞中预填额外字
    IntegratedGenerator.disambiguate(placements, grid);
```

- [ ] **Step 3: Commit**

```bash
git add lib/src/engine/integrated_generator.dart
git commit -m "feat: wire disambiguation into level generation"
```

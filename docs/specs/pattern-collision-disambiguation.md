# Pattern Collision Disambiguation

## Problem

When two placement slots have the same visible pattern in the grid (same given characters + same number/slot positions of empty cells), the player cannot distinguish which characters belong to which slot.

Example:
```
Slot A (horizontal):  大 _ _ _   → 大声疾呼
Slot B (horizontal):  大 _ _ _   → 大有可为
```
The player sees three empty cells after `大` in both rows and has no way to know which characters to fill where.

This applies regardless of whether the slots cross — two non-overlapping placement slots with identical patterns are equally ambiguous.

## Solution

During level generation, detect pattern collisions and pre-fill (make `isGiven = true`) one extra character in one of the colliding placements to break the symmetry.

### Collision Detection

Two placement slots **collide** if their visible patterns are identical.

A placement's **visible pattern** is a string of the same length as the idiom, where each position is:
- The character itself if `isGiven` (pre-filled or collision-resolved)
- `_` if the cell needs filling

Example:
```
大声疾呼, given 大 at position 0 → pattern: "大___"
大有可为, given 大 at position 0 → pattern: "大___"
→ COLLISION
```

**Skip rule**: If a placement has only 1 remaining empty cell (`visiblePattern` has exactly 1 `_`), skip it — it is too close to solved to warrant disambiguation.

### Resolution Algorithm (Constraint-based)

1. Collect all placement slots for the level.
2. For each pair `(A, B)`, if `skip(A) || skip(B)`, skip pair.
3. If `visiblePattern(A) == visiblePattern(B)`, mark as collision.
4. For each collision pair:
   a. Collect candidate positions from both `A` and `B` — all positions where `!isGiven`.
   b. Order candidates: non-crossing cells first (less likely to affect other placements), then crossing cells.
   c. For each candidate position `pos`:
      - Temporarily set `isGiven = true` at `pos`.
      - Re-run collision detection for ALL placement pairs.
      - If zero new collisions introduced, commit and continue to next pair.
      - If new collisions introduced, revert and try next candidate.
   d. If all candidates for `A` fail, try all candidates for `B`.
   e. If both fail, skip the pair (log, no action needed — extremely rare in practice).

### Placement in Generation Pipeline

Call disambiguation step in `IntegratedGenerator.generate()` and `IntegratedGenerator.generateSpiral()` just before returning the level, after all placements and given cells are finalized.

### Data Changes

`Placement` needs no new fields. The algorithm modifies `_grid.cellAt(r, c).given` or the placement's `isGiven` flags directly.

### Edge Cases

- A cell that becomes given may belong to multiple placements (crossing). The collision detection naturally accounts for this — all placements see the given and adjust their visible pattern.
- If disambiguation fails for a pair, the level still works; the player just sees the ambiguity. UI-side hints (like highlighting the current slot) can serve as fallback, but this spec does not prescribe UI changes.

### Future Considerations

None. The algorithm is self-contained and idempotent.

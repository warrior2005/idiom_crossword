import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart' as engine;
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';
import 'package:idiom_crossword/src/ui/screens/game_screen.dart';

/// 完整通关流程端到端测试：候选字填字 → 过关对话框 → 经验/记录落库
void main() {
  testWidgets('填满空格后过关，经验与通关记录写入数据库', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: GameScreen(level: _buildLevel())),
      ),
    );
    await tester.pumpAndSettle();

    // 依次填入 蛇 → 添 → 足（焦点自动前进到下一空格）
    for (final ch in ['蛇']) {
      await tester.tap(find.text(ch));
      await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));
    }

    // PRD 6.3：点击已聚焦的已填格两次 → 清除该字（候选槽位释放）
    final gridRect = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is GridPainter,
      ),
    );
    final cellSize = gridRect.width / 5;
    final snakeCell = Offset(
      gridRect.left + 2 * cellSize + cellSize / 2,
      gridRect.top + 1 * cellSize + cellSize / 2,
    );
    await tester.tapAt(snakeCell); // 聚焦已填格
    await tester.pump();
    await tester.tapAt(snakeCell); // 再次点击 → 清除
    await tester.pump();

    // 槽位已释放：重新填入 蛇 → 添 → 足 可正常通关
    for (final ch in ['蛇', '添', '足']) {
      await tester.tap(find.text(ch));
      await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));
    }

    // 过关对话框出现（异步完成流程需要轮询）
    await _pumpUntil(
      tester,
      () => find.text('恭喜过关！').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );
    expect(find.text('恭喜过关！'), findsOneWidget);

    // 排空闪烁动画 / SnackBar 的挂起定时器
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 800));

    // 教学关经验 +10，通关记录已落库
    final progress = await db.getPlayerProgress();
    expect(progress, isNotNull);
    expect(progress!.totalXp, 10);
    expect(progress.completedLevels, 1);
    expect(await db.getCompletedLevelNumbers(), {1});

    // 冻结定义：再次进入同一关得到同一题
    final frozen = await db.getLevelDefinition(1);
    expect(frozen, isNotNull);
    final replay = await loadOrGenerateLevel(db, 1);
    expect(replay, isNotNull);
    expect(replay!.placements.single.idiom.text, '画蛇添足');
    expect(replay.grid.rows, 5);
    expect(replay.grid.cols, 5);
  });

  testWidgets('一字提示揭示答案后通关，提示次数落库', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: GameScreen(level: _buildLevel())),
      ),
    );
    await tester.pumpAndSettle();

    // 一字提示揭示焦点格（蛇），焦点停留在该格
    await tester.tap(find.text('一字×3'));
    await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));
    expect(find.text('一字×2'), findsOneWidget);

    // 点击"添"空格聚焦后填入，焦点自动前进到"足"再填入
    final gridRect = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is GridPainter,
      ),
    );
    final cellSize = gridRect.width / 5;
    Offset cellCenter(int col, int row) => Offset(
      gridRect.left + col * cellSize + cellSize / 2,
      gridRect.top + row * cellSize + cellSize / 2,
    );
    await tester.tapAt(cellCenter(3, 1));
    await tester.pump();
    await tester.tap(find.text('添'));
    await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));
    await tester.tap(find.text('足'));
    await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));

    await _pumpUntil(
      tester,
      () => find.text('恭喜过关！').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );
    expect(find.text('恭喜过关！'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 800));

    final history = await db.getLevelHistory();
    expect(history.single.hintsUsed, 1);
  });

  testWidgets('长按空格显示所属成语及其拼音（PRD 6.3）', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: GameScreen(level: _buildLevel())),
      ),
    );
    await tester.pumpAndSettle();

    final gridRect = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is GridPainter,
      ),
    );
    final cellSize = gridRect.width / 5;
    final snakeCell = Offset(
      gridRect.left + 2 * cellSize + cellSize / 2,
      gridRect.top + 1 * cellSize + cellSize / 2,
    );

    await tester.longPressAt(snakeCell);
    await tester.pumpAndSettle();
    expect(find.text('该字属于：'), findsOneWidget);
    expect(find.text('画蛇添足'), findsOneWidget);
    expect(find.text('hua she tian zu'), findsOneWidget);
  });
}

/// 轮询直到 [condition] 成立或超时
Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition,
  Duration timeout,
) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  }
}

engine.CrosswordLevel _buildLevel() {
  final grid = engine.CrosswordGrid(rows: 5, cols: 5);
  const idiom = engine.Idiom(
    text: '画蛇添足',
    pinyin: 'hua she tian zu',
    meaning: '比喻做了多余的事',
    difficulty: 1,
  );
  final placement = engine.Placement(
    idiom: idiom,
    startRow: 1,
    startCol: 1,
    direction: engine.Direction.horizontal,
  );
  for (var k = 0; k < 4; k++) {
    final cell = grid.cellAt(1, 1 + k);
    cell.state = engine.CellState.filled;
    cell.character = idiom.text[k];
    if (k == 0) cell.isGiven = true;
  }
  return engine.CrosswordLevel(
    levelId: 1,
    grid: grid,
    placements: [placement],
    givenCharacters: {'画'},
    title: '第 1 关',
  );
}

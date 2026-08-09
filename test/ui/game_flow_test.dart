import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart' as engine;
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';
import 'package:idiom_crossword/src/state/player_state.dart';
import 'package:idiom_crossword/src/ui/screens/game_screen.dart';

/// 完整通关流程端到端测试：候选字填字 → 过关对话框 → 经验/记录落库
void main() {
  test('网格单元尺寸尽量撑满可用区域', () {
    // 空间富余时不再被 48px 上限限制：360/6 = 60
    expect(
      gridCellSize(availableWidth: 360, availableHeight: 500, rows: 6, cols: 6),
      60,
    );
    // 高度不足时以高度为准，保持正方形
    expect(
      gridCellSize(
        availableWidth: 360,
        availableHeight: 200,
        rows: 8,
        cols: 10,
      ),
      25,
    );
    // 非法行列返回 0
    expect(
      gridCellSize(availableWidth: 100, availableHeight: 100, rows: 0, cols: 5),
      0,
    );
  });

  test('usedGridBounds 排除生成器隐形边框', () {
    final grid = engine.CrosswordGrid(rows: 5, cols: 6);
    // 模拟生成器：内容占第 1~2 行、第 1~3 列，四周是 blocked 边框
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 6; c++) {
        if (r >= 1 && r <= 2 && c >= 1 && c <= 3) {
          grid.cellAt(r, c).state = engine.CellState.filled;
        }
      }
    }
    expect(usedGridBounds(grid), (2, 3));
    // 全 blocked 的网格返回 (0, 0)
    expect(usedGridBounds(engine.CrosswordGrid(rows: 3, cols: 3)), (0, 0));
  });

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
    final cellSize = gridRect.width / 4; // 实际使用 4 列（隐形边框已裁掉）
    final snakeCell = Offset(
      gridRect.left + 1 * cellSize + cellSize / 2,
      gridRect.top + cellSize / 2,
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
      () => find.text('恭喜通过 · 第 1 关').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );
    expect(find.text('恭喜通过 · 第 1 关'), findsOneWidget);
    expect(find.text('通'), findsOneWidget);
    expect(find.text('下一关'), findsOneWidget);

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
    await db.updatePlayerProgress(
      level: 1,
      totalXp: 0,
      completedLevels: 0,
      hintCards: 3,
      reviveCards: 0,
    );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    await container.read(playerProvider.notifier).loadFromDatabase(db);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: GameScreen(level: _buildLevel())),
      ),
    );
    await tester.pumpAndSettle();

    // 一字提示揭示焦点格（蛇），焦点停留在该格
    await tester.tap(find.text('提示'));
    await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));
    expect(find.text('剩 2'), findsOneWidget);

    // 点击"添"空格聚焦后填入，焦点自动前进到"足"再填入
    final gridRect = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is GridPainter,
      ),
    );
    final cellSize = gridRect.width / 4;
    Offset cellCenter(int col, int row) => Offset(
      gridRect.left + col * cellSize + cellSize / 2,
      gridRect.top + row * cellSize + cellSize / 2,
    );
    await tester.tapAt(cellCenter(2, 0)); // 添（矩阵第 3 列 → 实际第 2 列）
    await tester.pump();
    await tester.tap(find.text('添'));
    await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));
    await tester.tap(find.text('足'));
    await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));

    await _pumpUntil(
      tester,
      () => find.text('恭喜通过 · 第 1 关').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );
    expect(find.text('恭喜通过 · 第 1 关'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 800));

    final history = await db.getLevelHistory();
    expect(history.single.hintsUsed, 1);
    expect((await db.getPlayerProgress())!.hintCards, 2);
  });

  testWidgets('过关弹窗展示本局填错过的成语', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: GameScreen(level: _buildLevel())),
      ),
    );
    await tester.pumpAndSettle();

    // 先故意填错一个字
    final wrongChar = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data != null &&
          w.data!.length == 1 &&
          !'蛇添足'.contains(w.data!),
    );
    await tester.tap(wrongChar.first);
    await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));

    // 回到填错的“蛇”格并改正，再依次补完
    final gridRect = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is GridPainter,
      ),
    );
    final cellSize = gridRect.width / 4;
    await tester.tapAt(
      Offset(
        gridRect.left + 1 * cellSize + cellSize / 2,
        gridRect.top + cellSize / 2,
      ),
    );
    await tester.pump();
    await tester.tap(find.text('蛇'));
    await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));
    for (final ch in ['添', '足']) {
      await tester.tap(find.text(ch));
      await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));
    }

    await _pumpUntil(
      tester,
      () => find.text('恭喜通过 · 第 1 关').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );
    expect(find.text('恭喜通过 · 第 1 关'), findsOneWidget);
    expect(find.text('返回主页'), findsOneWidget);
    expect(find.byKey(const ValueKey('win-card-idiom-画蛇添足')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('每日挑战倒计时结束显示失败弹框', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.updatePlayerProgress(
      level: 1,
      totalXp: 0,
      completedLevels: 0,
      hintCards: 5,
      reviveCards: 0,
    );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(playerProvider.notifier).loadFromDatabase(db);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GameScreen(level: _buildLevel(levelId: dailyLevelNumber())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 121));
    await tester.pumpAndSettle();

    expect(find.text('挑战失败'), findsOneWidget);
    expect(find.text('复活(剩余 0)'), findsOneWidget);
    expect(find.text('重玩本关（无经验）'), findsOneWidget);
    expect(find.text('返回主页'), findsOneWidget);
    expect(await db.getLevelState(dailyLevelNumber()), isNull);

    await tester.tap(find.text('复活(剩余 0)'));
    await tester.pumpAndSettle();
    expect(find.text('复活卡 ×1'), findsOneWidget);
    expect(find.text('15 积分'), findsOneWidget);
    expect(find.text('当前积分：0'), findsOneWidget);
    expect(find.text('内购功能即将上线'), findsNothing);

    await tester.tap(find.text('购买'));
    await tester.pumpAndSettle();
    expect(find.text('积分不足，可观看广告赚取积分'), findsOneWidget);
  });

  testWidgets('noReward 关卡通关不获得经验', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: GameScreen(level: _buildLevel(), noReward: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final ch in ['蛇', '添', '足']) {
      await tester.tap(find.text(ch));
      await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));
    }
    await _pumpUntil(
      tester,
      () => find.text('恭喜通过 · 第 1 关').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 800));

    final history = await db.getLevelHistory();
    expect(history.single.xpGained, 0);
    expect((await db.getPlayerProgress())?.totalXp ?? 0, 0);
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

engine.CrosswordLevel _buildLevel({int levelId = 1}) {
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
    levelId: levelId,
    grid: grid,
    placements: [placement],
    givenCharacters: {'画'},
    title: levelId >= dailyLevelOffset ? '每日挑战' : '第 1 关',
  );
}

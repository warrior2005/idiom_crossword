import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/audio/music_manager.dart';
import 'package:idiom_crossword/src/audio/sound_manager.dart';
import 'package:idiom_crossword/src/data/achievement_manager.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart' as engine;
import 'package:idiom_crossword/src/notifications/daily_reminder_platform.dart';
import 'package:idiom_crossword/src/reviews/app_review.dart';
import 'package:idiom_crossword/src/state/daily_challenge.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';
import 'package:idiom_crossword/src/state/player_state.dart';
import 'package:idiom_crossword/src/ui/screens/game_screen.dart';
import 'package:idiom_crossword/src/ui/screens/settings_screen.dart';
import 'package:idiom_crossword/src/ui/widgets/app_icons.dart';
import 'package:idiom_crossword/src/ui/widgets/primary_button.dart';
import 'package:idiom_crossword/src/utils/ad_manager.dart';

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

  test('网格拼音按成语字序映射到格子', () {
    final pinyin = pinyinByCell(_buildLevel());

    expect(pinyin[(1, 1)], 'hua');
    expect(pinyin[(1, 2)], 'she');
    expect(pinyin[(1, 3)], 'tian');
    expect(pinyin[(1, 4)], 'zu');
  });

  testWidgets('显示拼音设置控制网格标注', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.setSetting(showPinyinKey, 'false');
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: GameScreen(level: _buildLevel())),
      ),
    );
    await tester.pumpAndSettle();
    GridPainter gridPainter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<GridPainter>()
        .single;
    expect(gridPainter().showPinyin, isFalse);

    await container.read(showPinyinProvider.notifier).setEnabled(true);
    await tester.pump();
    expect(gridPainter().showPinyin, isTrue);
  });

  testWidgets('填错时不展示正确答案的拼音', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.setSetting(showPinyinKey, 'true');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: GameScreen(level: _buildLevel())),
      ),
    );
    await tester.pumpAndSettle();

    final wrongChar = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data != null &&
          widget.data!.length == 1 &&
          !'蛇添足'.contains(widget.data!),
    );
    await tester.tap(wrongChar.first);
    await tester.pump();

    final painter = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<GridPainter>()
        .single;
    expect(painter.playerAnswers[(1, 2)], isNot('蛇'));
    expect(painter.pinyinAt(1, 2), isNull);
    expect(painter.pinyinAt(1, 1), 'hua');

    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('关闭触感反馈后填字不触发震动', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.setSetting(hapticEnabledKey, 'false');
    final hapticCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') hapticCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: GameScreen(level: _buildLevel())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('蛇'));
    await tester.pump();

    expect(hapticCalls, isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('完成新成语后滚动到列表最右侧', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: GameScreen(level: _buildScrollableLevel())),
      ),
    );
    await tester.pumpAndSettle();

    for (final char in ['足', '牢', '兔', '威', '铃']) {
      await tester.tap(find.text(char));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final completedScrollView = tester.widget<SingleChildScrollView>(
      find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
    );
    final position = completedScrollView.controller!.position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, closeTo(position.maxScrollExtent, 0.01));
  });

  testWidgets('填入正确单字后立即更新本关进度', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: GameScreen(level: _buildLevel())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('0/3 字', findRichText: true), findsOneWidget);

    await tester.tap(find.text('蛇'));
    await tester.pump();

    expect(find.text('1/3 字', findRichText: true), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('清空保留已完成成语并清除所有未完成成语的已填字', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: GameScreen(level: _buildCrossingLevel())),
      ),
    );
    await tester.pumpAndSettle();

    for (final char in ['蛇', '添', '足', '蝎']) {
      await tester.tap(find.text(char));
      await tester.pump();
    }
    final wrongChar = find.byWidgetPredicate(
      (widget) =>
          widget is Text &&
          widget.data != null &&
          widget.data!.length == 1 &&
          !'画蛇添足蝎心肠'.contains(widget.data!),
    );
    await tester.tap(wrongChar.first);
    await tester.pump();

    GridPainter painter() => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<GridPainter>()
        .single;
    expect(painter().playerAnswers[(1, 2)], '蛇');
    expect(painter().playerAnswers[(1, 3)], '添');
    expect(painter().playerAnswers[(1, 4)], '足');
    expect(painter().playerAnswers[(2, 2)], '蝎');
    expect(painter().playerAnswers[(3, 2)], isNotNull);

    await tester.tap(find.text('清空'));
    await tester.pump();

    expect(painter().playerAnswers[(1, 2)], '蛇');
    expect(painter().playerAnswers[(1, 3)], '添');
    expect(painter().playerAnswers[(1, 4)], '足');
    expect(painter().playerAnswers[(2, 2)], isNull);
    expect(painter().playerAnswers[(3, 2)], isNull);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('GameScreen 声音按钮同时控制音乐和音效', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    SoundManager.instance.setEnabled(true);
    await MusicManager.instance.setMusicEnabled(true);
    addTearDown(() async {
      SoundManager.instance.setEnabled(true);
      await MusicManager.instance.setMusicEnabled(true);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: GameScreen(level: _buildLevel())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is AppIcon && widget.name == 'sound',
      ),
    );
    await tester.pumpAndSettle();

    expect(SoundManager.instance.enabled, isFalse);
    expect(MusicManager.instance.musicEnabled, isFalse);
    expect(await db.getSetting(soundEnabledKey), 'false');
    expect(await db.getSetting(musicEnabledKey), 'false');
  });

  testWidgets('交叉格优先沿前方已有字的方向移动', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: GameScreen(level: _buildDirectionInferenceLevel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gridFinder = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GridPainter,
    );
    final gridRect = tester.getRect(gridFinder);
    final cellSize = gridRect.width / 4;
    await tester.tapAt(
      Offset(gridRect.left + cellSize * 2.5, gridRect.top + cellSize * 2.5),
    );
    await tester.pump();
    await tester.tap(find.text('不'));
    await tester.pump();

    final painter =
        tester.widget<CustomPaint>(gridFinder).painter! as GridPainter;
    expect((painter.focusRow, painter.focusCol), (4, 3));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('成语末字交叉到另一成语第三字时先移到其第二字', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: GameScreen(level: _buildEndToThirdCrossingLevel()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gridFinder = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GridPainter,
    );
    final gridRect = tester.getRect(gridFinder);
    final cellSize = gridRect.width / 4;
    await tester.tapAt(
      Offset(gridRect.left + cellSize * 1.5, gridRect.top + cellSize * 2.5),
    );
    await tester.pump();
    for (final char in ['蛇', '添', '足']) {
      await tester.tap(find.text(char));
      await tester.pump();
    }

    final painter =
        tester.widget<CustomPaint>(gridFinder).painter! as GridPainter;
    expect((painter.focusRow, painter.focusCol), (2, 4));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('每日挑战通关后刷新完成状态', (tester) async {
    final db = _DelayedHistoryDatabase();
    addTearDown(db.close);
    for (final id in AchievementId.values) {
      await db.unlockAchievement(id.name);
    }
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      dailyDoneProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    expect(await container.read(dailyDoneProvider.future), isFalse);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GameScreen(level: _buildLevel(levelId: dailyLevelNumber())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final char in ['蛇', '添', '足']) {
      await tester.tap(find.text(char));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await _pumpUntil(
      tester,
      () => find.text('每日挑战 · 完成').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );
    await _pumpUntil(
      tester,
      () => container.read(dailyDoneProvider).value == true,
      const Duration(seconds: 2),
    );

    expect(container.read(dailyDoneProvider).value, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('首次完成每日挑战后才请求通知权限并默认12点提醒', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final platform = _GameReminderPlatform();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        dailyReminderPlatformProvider.overrideWithValue(platform),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GameScreen(level: _buildLevel(levelId: dailyLevelNumber())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(platform.requestCount, 0);

    for (final char in ['蛇', '添', '足']) {
      await tester.tap(find.text(char));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await _pumpUntil(
      tester,
      () => find.text('开启每日挑战提醒').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );
    expect(platform.requestCount, 0);
    expect(find.textContaining('“我的 → 设置”'), findsOneWidget);

    await tester.tap(find.text('继续'));
    await _pumpUntil(
      tester,
      () => find.text('每日挑战 · 完成').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );
    expect(platform.requestCount, 1);
    expect(platform.scheduledTimes, [(12, 0)]);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 800));
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

    // 关闭结算弹框后，顶栏和已完成成语区仍可正常交互。
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('恭喜通过 · 第 1 关'), findsNothing);

    expect(find.text('释义：比喻做了多余的事'), findsOneWidget);
    await tester.tap(find.text('画蛇添足'));
    await tester.pump();
    expect(find.text('释义：比喻做了多余的事'), findsNothing);
    expect(find.text('恭喜通过 · 第 1 关'), findsNothing);

    final soundEnabled = SoundManager.instance.enabled;
    final soundButton = find.byWidgetPredicate(
      (widget) => widget is AppIcon && widget.name == 'sound',
    );
    await tester.tap(soundButton);
    await tester.pumpAndSettle();
    expect(SoundManager.instance.enabled, !soundEnabled);
    expect(find.text('恭喜通过 · 第 1 关'), findsNothing);
    await tester.tap(soundButton);
    await tester.pumpAndSettle();
    expect(SoundManager.instance.enabled, soundEnabled);

    // 其余游戏区域仍会重新唤起 win-card。
    await tester.tapAt(tester.getCenter(find.byType(CustomPaint).first));
    await tester.pumpAndSettle();
    expect(find.text('恭喜通过 · 第 1 关'), findsOneWidget);

    // 排空闪烁动画 / SnackBar 的挂起定时器
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 800));

    // 教学关经验 +20，首关奖励 5 积分 + 首次通关成就 10 积分
    final progress = await db.getPlayerProgress();
    expect(progress, isNotNull);
    expect(progress!.totalXp, 20);
    expect(progress.completedLevels, 1);
    expect(progress.points, 15);
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

  testWidgets('累计第 10 次通关时请求系统评分并记录状态', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (var level = 1; level < 10; level++) {
      await db.addLevelHistory(
        levelNumber: level,
        xpGained: 0,
        idiomsUsed: const [],
        hintsUsed: 1,
        errorsMade: 1,
      );
    }
    await db.updatePlayerProgress(
      level: 1,
      totalXp: 0,
      completedLevels: 9,
      hintCards: 0,
      reviveCards: 0,
    );
    await db.unlockAchievement(AchievementId.firstLevel.name);
    final reviewPlatform = _GameReviewPlatform();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appReviewPlatformProvider.overrideWithValue(reviewPlatform),
      ],
    );
    addTearDown(container.dispose);
    await container.read(playerProvider.notifier).loadFromDatabase(db);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: GameScreen(level: _buildLevel(levelId: 10))),
      ),
    );
    await tester.pumpAndSettle();

    for (final char in ['蛇', '添', '足']) {
      await tester.tap(find.text(char));
      await tester.pump(const Duration(milliseconds: 200));
    }
    await _pumpUntil(
      tester,
      () => find.text('喜欢《成语接龙》吗？').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );

    expect(find.text('暂不评价'), findsOneWidget);
    expect(find.text('去评价'), findsOneWidget);
    expect(reviewPlatform.requestCount, 0);

    await tester.tap(find.text('去评价'));
    await _pumpUntil(
      tester,
      () => find.text('恭喜通过 · 第 1 关').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );

    expect(reviewPlatform.requestCount, 1);
    expect(await db.getSetting(appReviewRequestedKey), 'true');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 800));
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
    expect(find.byKey(const ValueKey('win-card-idiom-画蛇添足')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 800));

    final history = await db.getLevelHistory();
    expect(history.single.hintsUsed, 1);
    expect((await db.getPlayerProgress())!.hintCards, 2);
  });

  testWidgets('最后一个格子使用提示后自动通关并收录成语', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.idioms)
        .insert(
          IdiomsCompanion(
            word: const Value('画蛇添足'),
            pinyin: const Value('hua she tian zu'),
            pinyinAbbr: const Value('hstz'),
            explanation: const Value('比喻做了多余的事'),
            firstChar: const Value('画'),
            lastChar: const Value('足'),
            difficulty: const Value(1),
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: GameScreen(level: _buildLevel())),
      ),
    );
    await tester.pumpAndSettle();

    for (final ch in ['蛇', '添']) {
      await tester.tap(find.text(ch));
      await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));
    }

    await tester.tap(find.text('提示'));
    await _pumpUntil(
      tester,
      () => find.text('恭喜通过 · 第 1 关').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );
    expect(find.text('恭喜通过 · 第 1 关'), findsOneWidget);
    expect((await db.getPlayerProgress())!.totalXp, 20);

    final idiomId = await db.findIdiomIdByWord('画蛇添足');
    expect(idiomId, isNotNull);
    expect(await db.getCollection(), contains(idiomId));

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('提示卡为0时可打开积分购买弹框', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.updatePlayerProgress(
      level: 1,
      totalXp: 0,
      completedLevels: 0,
      hintCards: 0,
      reviveCards: 2,
    );

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(playerProvider.notifier).loadFromDatabase(db);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: GameScreen(level: _buildLevel())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('提示'));
    await tester.pumpAndSettle();
    expect(find.text('提示卡 ×1'), findsOneWidget);
    expect(find.text('10 积分'), findsOneWidget);
    expect(find.text('当前积分：0'), findsOneWidget);

    await tester.tap(find.text('购买'));
    await tester.pumpAndSettle();
    expect(find.text('积分不足，可观看广告赚取积分'), findsOneWidget);
  });

  testWidgets('半句可交换成语：先填交换位任一顺序都可通关', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.idioms)
        .insert(
          IdiomsCompanion(
            word: const Value('如痴如醉'),
            pinyin: const Value('ru chi ru zui'),
            pinyinAbbr: const Value('rcrz'),
            explanation: const Value('形容沉迷于某种状态'),
            firstChar: const Value('如'),
            lastChar: const Value('醉'),
            difficulty: const Value(1),
            reversible: const Value(true),
          ),
        );
    final idA = await db.findIdiomIdByWord('如痴如醉');
    await db
        .into(db.idioms)
        .insert(
          IdiomsCompanion(
            word: const Value('如醉如痴'),
            pinyin: const Value('ru zui ru chi'),
            pinyinAbbr: const Value('rzrc'),
            explanation: const Value('形容沉迷于某种状态'),
            firstChar: const Value('如'),
            lastChar: const Value('痴'),
            difficulty: const Value(1),
            reversible: const Value(true),
          ),
        );
    final idB = await db.findIdiomIdByWord('如醉如痴');
    await db
        .into(db.idiomReversiblePair)
        .insert(
          IdiomReversiblePairCompanion(
            idiomIdA: Value(idA!),
            idiomIdB: Value(idB!),
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: GameScreen(level: _buildReversibleLevel())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('醉'));
    await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));
    await tester.tap(find.text('痴'));
    await _pumpUntil(
      tester,
      () => find.text('恭喜通过 · 第 1 关').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );
    expect(find.text('恭喜通过 · 第 1 关'), findsOneWidget);
    expect(find.byKey(const ValueKey('life-heart-0')), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNWidgets(3));

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 800));
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

    // 在同一个成语中故意填错两次
    final wrongChar = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data != null &&
          w.data!.length == 1 &&
          !'蛇添足'.contains(w.data!),
    );
    await tester.tap(wrongChar.first);
    await _pumpUntil(tester, () => true, const Duration(milliseconds: 200));
    await tester.tap(wrongChar.at(1));
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
    await tester.tapAt(
      Offset(
        gridRect.left + 2 * cellSize + cellSize / 2,
        gridRect.top + cellSize / 2,
      ),
    );
    await tester.pump();
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
    expect(find.textContaining('填错 1'), findsOneWidget);
    expect(find.textContaining('填错 2'), findsNothing);
    expect(find.text('返回主页'), findsOneWidget);
    expect(find.byKey(const ValueKey('win-card-idiom-画蛇添足')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 800));
  });

  testWidgets('3 颗心允许填错 3 次，第 4 次才失败', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    AdManager().isRewardedAdReadyNotifier.value = false;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await db.setSetting(kDailyReviveDateKey, today);
    await db.setSetting(kDailyAdReviveCountKey, '$kDailyReviveLimit');
    await db.setSetting(kDailyShareReviveCountKey, '$kDailyReviveLimit');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: GameScreen(level: _buildLevel())),
      ),
    );
    await tester.pumpAndSettle();

    final wrongChar = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data != null &&
          w.data!.length == 1 &&
          !'蛇添足'.contains(w.data!),
    );
    final gridRect = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is GridPainter,
      ),
    );
    final snakeCell = Offset(
      gridRect.left + gridRect.width * 3 / 8,
      gridRect.center.dy,
    );

    for (var error = 1; error <= 3; error++) {
      await tester.tap(wrongChar.at(error - 1));
      await tester.pump();
      expect(find.text('挑战失败'), findsNothing);
      expect(find.byIcon(Icons.favorite), findsNWidgets(3 - error));
      await tester.tapAt(snakeCell);
      await tester.pump();
    }
    await tester.tap(wrongChar.at(3));
    await tester.pumpAndSettle();
    expect(find.text('挑战失败'), findsOneWidget);
    final adButton = tester.widget<PrimaryButton>(
      find.widgetWithText(PrimaryButton, '看广告复活(0)'),
    );
    final shareButton = tester.widget<PrimaryButton>(
      find.widgetWithText(PrimaryButton, '分享后复活(0)'),
    );
    expect(adButton.onTap, isNull);
    expect(shareButton.onTap, isNull);
    expect(find.text('使用复活卡(2)'), findsOneWidget);
    final replayButton = find.widgetWithText(PrimaryButton, '重玩本关');
    final homeButton = find.widgetWithText(PrimaryButton, '返回主页');
    expect(
      find.ancestor(of: replayButton, matching: find.byType(Row)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: homeButton, matching: find.byType(Row)),
      findsOneWidget,
    );
  });

  testWidgets('交叉格填错只记当前方向成语', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: GameScreen(level: _buildCrossingLevel())),
      ),
    );
    await tester.pumpAndSettle();

    final wrongChar = find.byWidgetPredicate(
      (w) =>
          w is Text &&
          w.data != null &&
          w.data!.length == 1 &&
          !'蛇添足蝎心'.contains(w.data!),
    );
    await tester.tap(wrongChar.first);
    await tester.pump();

    final gridRect = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is GridPainter,
      ),
    );
    final cellSize = gridRect.width / 4;
    await tester.tapAt(
      Offset(gridRect.left + cellSize * 1.5, gridRect.top + cellSize / 2),
    );
    await tester.pump();
    for (final char in ['蛇', '添', '足', '蝎', '心']) {
      await tester.tap(find.text(char));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _pumpUntil(
      tester,
      () => find.text('恭喜通过 · 第 1 关').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );
    expect(find.byKey(const ValueKey('win-card-idiom-画蛇添足')), findsOneWidget);
    expect(find.byKey(const ValueKey('win-card-idiom-蛇蝎心肠')), findsNothing);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('每日挑战倒计时结束显示失败弹框', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final adReady = AdManager().isRewardedAdReadyNotifier;
    adReady.value = false;
    addTearDown(() => adReady.value = false);
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
    expect(find.text('03:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 181));
    await tester.pumpAndSettle();

    expect(find.text('挑战失败'), findsOneWidget);
    expect(find.text('经验 +0', findRichText: true), findsNothing);
    var adButton = tester.widget<PrimaryButton>(
      find.widgetWithText(PrimaryButton, '看广告复活(加载中)'),
    );
    expect(adButton.onTap, isNull);
    adReady.value = true;
    await tester.pump();
    adButton = tester.widget<PrimaryButton>(
      find.widgetWithText(PrimaryButton, '看广告复活(10)'),
    );
    expect(adButton.onTap, isNotNull);
    expect(find.text('分享后复活(10)'), findsOneWidget);
    expect(find.text('使用复活卡(0)'), findsOneWidget);
    expect(find.text('重玩本关（无经验）'), findsOneWidget);
    expect(find.text('返回主页'), findsOneWidget);
    expect(await db.getLevelState(dailyLevelNumber()), isNull);

    await tester.tap(find.text('使用复活卡(0)'));
    await tester.pumpAndSettle();
    expect(find.text('复活卡 ×1'), findsOneWidget);
    expect(find.text('购买'), findsOneWidget);
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    await tester.tap(find.text('重玩本关（无经验）'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
  });

  testWidgets('每日挑战复活倒计时等待游戏页恢复前台后才开始', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.updatePlayerProgress(
      level: 1,
      totalXp: 0,
      completedLevels: 0,
      hintCards: 5,
      reviveCards: 1,
    );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(playerProvider.notifier).loadFromDatabase(db);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: GameScreen(level: _buildLevel(levelId: dailyLevelNumber())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _failCurrentLevel(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.tap(find.text('使用复活卡(1)'));
    await tester.pump();
    expect(find.text('03:00'), findsOneWidget);

    await tester.pump(const Duration(seconds: 15));
    expect(find.text('03:00'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('02:59'), findsOneWidget);
  });

  testWidgets('每日挑战复活后退出再进入仍恢复正常计时和奖励流程', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.updatePlayerProgress(
      level: 1,
      totalXp: 0,
      completedLevels: 0,
      hintCards: 5,
      reviveCards: 1,
    );
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(playerProvider.notifier).loadFromDatabase(db);
    final level = _buildLevel(levelId: dailyLevelNumber());

    Widget game() => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: GameScreen(level: level)),
    );

    await tester.pumpWidget(game());
    await tester.pumpAndSettle();
    await _failCurrentLevel(tester);
    await tester.tap(find.text('使用复活卡(1)'));
    await tester.pump();
    await _pumpUntil(
      tester,
      () => find.text('03:00').evaluate().isNotEmpty,
      const Duration(seconds: 2),
    );
    expect(await db.getLevelState(level.levelId), isNotNull);
    expect(await db.getSetting('daily_no_reward_${level.levelId}'), 'false');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(game());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
    for (final ch in ['蛇', '添', '足']) {
      await tester.tap(find.text(ch));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await _pumpUntil(
      tester,
      () => find.text('每日挑战 · 完成').evaluate().isNotEmpty,
      const Duration(seconds: 5),
    );
    expect((await db.getLevelHistory()).single.xpGained, greaterThan(0));
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
    expect((await db.getPlayerProgress())?.points ?? 0, 0);
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

Future<void> _failCurrentLevel(WidgetTester tester) async {
  final wrongChar = find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.data != null &&
        widget.data!.length == 1 &&
        !'蛇添足'.contains(widget.data!),
  );
  final gridRect = tester.getRect(
    find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is GridPainter,
    ),
  );
  final snakeCell = Offset(
    gridRect.left + gridRect.width * 3 / 8,
    gridRect.center.dy,
  );

  for (var error = 0; error < 4; error++) {
    await tester.tap(wrongChar.at(error));
    await tester.pump();
    if (error < 3) {
      await tester.tapAt(snakeCell);
      await tester.pump();
    }
  }
  await tester.pumpAndSettle();
  expect(find.text('挑战失败'), findsOneWidget);
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

engine.CrosswordLevel _buildScrollableLevel() {
  final grid = engine.CrosswordGrid(rows: 7, cols: 6);
  const words = ['画蛇添足', '亡羊补牢', '守株待兔', '狐假虎威', '掩耳盗铃'];
  final placements = <engine.Placement>[];
  for (var row = 1; row <= words.length; row++) {
    final idiom = engine.Idiom(
      text: words[row - 1],
      pinyin: '',
      meaning: '',
      difficulty: 1,
    );
    final placement = engine.Placement(
      idiom: idiom,
      startRow: row,
      startCol: 1,
      direction: engine.Direction.horizontal,
    );
    placements.add(placement);
    for (var k = 0; k < idiom.text.length; k++) {
      final cell = grid.cellAt(row, k + 1);
      cell.state = engine.CellState.filled;
      cell.character = idiom.text[k];
      cell.isGiven = k < idiom.text.length - 1;
    }
  }
  return engine.CrosswordLevel(
    levelId: 1,
    grid: grid,
    placements: placements,
    givenCharacters: words
        .expand((word) => word.substring(0, 3).split(''))
        .toSet(),
    title: '第 1 关',
  );
}

engine.CrosswordLevel _buildDirectionInferenceLevel() {
  final grid = engine.CrosswordGrid(rows: 6, cols: 6);
  const horizontal = engine.Idiom(
    text: '语焉不详',
    pinyin: 'yu yan bu xiang',
    meaning: '说得不详细',
    difficulty: 1,
  );
  const vertical = engine.Idiom(
    text: '不骄不躁',
    pinyin: 'bu jiao bu zao',
    meaning: '不骄傲，不急躁',
    difficulty: 1,
  );
  final placements = [
    const engine.Placement(
      idiom: horizontal,
      startRow: 3,
      startCol: 1,
      direction: engine.Direction.horizontal,
    ),
    const engine.Placement(
      idiom: vertical,
      startRow: 1,
      startCol: 3,
      direction: engine.Direction.vertical,
    ),
  ];
  for (final placement in placements) {
    for (var k = 0; k < placement.idiom.text.length; k++) {
      final (row, col) = placement.cellAt(k);
      final cell = grid.cellAt(row, col);
      if (cell.state == engine.CellState.filled) cell.isIntersection = true;
      cell.state = engine.CellState.filled;
      cell.character = placement.idiom.text[k];
    }
  }
  for (final position in [(3, 1), (1, 3), (2, 3)]) {
    grid.cellAt(position.$1, position.$2).isGiven = true;
  }
  return engine.CrosswordLevel(
    levelId: 1,
    grid: grid,
    placements: placements,
    givenCharacters: const {'语', '不', '骄'},
    title: '第 1 关',
  );
}

engine.CrosswordLevel _buildEndToThirdCrossingLevel() {
  final grid = engine.CrosswordGrid(rows: 6, cols: 6);
  const horizontal = engine.Idiom(
    text: '画蛇添足',
    pinyin: 'hua she tian zu',
    meaning: '比喻做了多余的事',
    difficulty: 1,
  );
  const vertical = engine.Idiom(
    text: '手舞足蹈',
    pinyin: 'shou wu zu dao',
    meaning: '形容高兴到了极点',
    difficulty: 1,
  );
  final placements = [
    const engine.Placement(
      idiom: horizontal,
      startRow: 3,
      startCol: 1,
      direction: engine.Direction.horizontal,
    ),
    const engine.Placement(
      idiom: vertical,
      startRow: 1,
      startCol: 4,
      direction: engine.Direction.vertical,
    ),
  ];
  for (final placement in placements) {
    for (var k = 0; k < placement.idiom.text.length; k++) {
      final (row, col) = placement.cellAt(k);
      final cell = grid.cellAt(row, col);
      if (cell.state == engine.CellState.filled) cell.isIntersection = true;
      cell.state = engine.CellState.filled;
      cell.character = placement.idiom.text[k];
    }
  }
  grid.cellAt(3, 1).isGiven = true;
  grid.cellAt(1, 4).isGiven = true;
  return engine.CrosswordLevel(
    levelId: 1,
    grid: grid,
    placements: placements,
    givenCharacters: const {'画', '手'},
    title: '第 1 关',
  );
}

engine.CrosswordLevel _buildReversibleLevel({int levelId = 1}) {
  final grid = engine.CrosswordGrid(rows: 5, cols: 5);
  const idiom = engine.Idiom(
    text: '如痴如醉',
    pinyin: 'ru chi ru zui',
    meaning: '形容沉迷于某种状态',
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
    if (k == 0 || k == 2) cell.isGiven = true;
  }
  return engine.CrosswordLevel(
    levelId: levelId,
    grid: grid,
    placements: [placement],
    givenCharacters: {'如'},
    title: levelId >= dailyLevelOffset ? '每日挑战' : '第 1 关',
  );
}

engine.CrosswordLevel _buildCrossingLevel() {
  final grid = engine.CrosswordGrid(rows: 6, cols: 6);
  const horizontal = engine.Idiom(
    text: '画蛇添足',
    pinyin: 'hua she tian zu',
    meaning: '比喻做了多余的事',
    difficulty: 1,
  );
  const vertical = engine.Idiom(
    text: '蛇蝎心肠',
    pinyin: 'she xie xin chang',
    meaning: '形容心肠狠毒',
    difficulty: 1,
  );
  final placements = [
    const engine.Placement(
      idiom: horizontal,
      startRow: 1,
      startCol: 1,
      direction: engine.Direction.horizontal,
    ),
    const engine.Placement(
      idiom: vertical,
      startRow: 1,
      startCol: 2,
      direction: engine.Direction.vertical,
    ),
  ];
  for (final placement in placements) {
    for (var k = 0; k < 4; k++) {
      final (row, col) = placement.cellAt(k);
      final cell = grid.cellAt(row, col);
      if (cell.state == engine.CellState.filled) cell.isIntersection = true;
      cell.state = engine.CellState.filled;
      cell.character = placement.idiom.text[k];
    }
  }
  grid.cellAt(1, 1).isGiven = true;
  grid.cellAt(4, 2).isGiven = true;
  return engine.CrosswordLevel(
    levelId: 1,
    grid: grid,
    placements: placements,
    givenCharacters: const {'画', '肠'},
    title: '第 1 关',
  );
}

class _DelayedHistoryDatabase extends AppDatabase {
  _DelayedHistoryDatabase() : super(NativeDatabase.memory());

  @override
  Future<void> addLevelHistory({
    required int levelNumber,
    required int xpGained,
    required List<int> idiomsUsed,
    int? timeSpentMs,
    int hintsUsed = 0,
    int errorsMade = 0,
    int? totalFills,
    String? levelJson,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await super.addLevelHistory(
      levelNumber: levelNumber,
      xpGained: xpGained,
      idiomsUsed: idiomsUsed,
      timeSpentMs: timeSpentMs,
      hintsUsed: hintsUsed,
      errorsMade: errorsMade,
      totalFills: totalFills,
      levelJson: levelJson,
    );
  }
}

class _GameReminderPlatform implements DailyReminderPlatform {
  var authorization = NotificationAuthorization.notDetermined;
  int requestCount = 0;
  final List<(int, int)> scheduledTimes = [];

  @override
  Future<void> cancelDailyReminder() async {}

  @override
  Future<NotificationAuthorization> getAuthorizationStatus() async =>
      authorization;

  @override
  Future<bool> openNotificationSettings() async => true;

  @override
  Future<NotificationAuthorization> requestAuthorization() async {
    requestCount++;
    authorization = NotificationAuthorization.authorized;
    return authorization;
  }

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    scheduledTimes.add((hour, minute));
  }
}

class _GameReviewPlatform implements AppReviewPlatform {
  int requestCount = 0;

  @override
  Future<void> requestReview() async {
    requestCount++;
  }
}

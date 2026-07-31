import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auto_size_text/auto_size_text.dart';
import '../../engine/grid_engine.dart';
import '../../engine/distractor_engine.dart';
import '../widgets/level_display.dart';
import '../../state/database_provider.dart';
import '../../state/player_state.dart';
import '../../state/level_generation.dart';
import '../../state/level_state_codec.dart';
import '../../state/leaderboard_service.dart';
import '../../data/growth_manager.dart';
import '../../data/achievement_manager.dart';
import '../../audio/game_audio.dart';
import '../widgets/level_loading_dialog.dart';
import 'learning_screen.dart';

/// 游戏主界面
///
/// 布局：
///   ┌──────────────────┐
///   │  关卡标题 + 进度   │
///   ├──────────────────┤
///   │                  │
///   │  填字网格区域      │  ← CustomPainter 绘制
///   │  (可滚动+缩放)    │
///   │                  │
///   ├──────────────────┤
///   │  当前选中成语释义  │
///   ├──────────────────┤
///   │  候选字盘 (3行)   │  ← 点击填入
///   ├──────────────────┤
///   │  提示/撤销/重置   │
///   └──────────────────┘

class GameScreen extends ConsumerStatefulWidget {
  final CrosswordLevel level;
  final bool isCustom; // 自定义练习关：不计入通关进度与成就

  const GameScreen({super.key, required this.level, this.isCustom = false});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late CrosswordGrid _grid;
  final DistractorEngine _distractorEngine = DistractorEngine();

  // 当前焦点格子
  int _focusRow = -1;
  int _focusCol = -1;
  Direction? _currentDirection; // 当前填字方向

  // 玩家填入的字（row, col) → char
  final Map<(int, int), String> _playerAnswers = {};

  // 候选字盘
  List<List<String>> _candidateBoard = [];

  // 已使用的候选字位置（row, col）
  final Set<(int, int)> _usedCandidateSlots = {};

  // 错误提示（闪烁效果用）
  final Set<(int, int)> _errorCells = {};

  // 填入历史（撤销用）
  final List<({int row, int col, int candRow, int candCol})> _fillHistory = [];

  // 格子 → 候选字槽位（清除用）
  final Map<(int, int), (int, int)> _cellToCandidateSlot = {};

  // 已完成成语
  final Set<(int, int)> _completedCells = {};
  final List<({String word, String meaning})> _completedIdiomList = [];
  int? _selectedCompletedIndex;

  // 本关提示使用情况
  int _hintUsesThisLevel = 0; // 一字提示次数（前 3 次免费，之后消耗提示卡）
  bool _idiomHintUsed = false; // 成语提示每关一次
  bool _revealedAll = false; // 全图揭示后本关不计入通关
  int _errorsMade = 0; // 错误填写次数（统计用）
  int _correctStreak = 0; // 连续答对字数（成就）
  bool _streak10Handled = false; // 十连击成就本会话已触发
  late DateTime _levelStartTime;

  // 断点续玩
  bool _restoring = true;
  bool _levelFinished = false; // 通关/放弃后不再写存档

  // 填入正确字时的闪烁反馈
  (int, int)? _flashCell;

  @override
  void initState() {
    super.initState();
    _grid = widget.level.grid;
    _buildCandidateBoard();
    _findFirstEmptyCell();
    _levelStartTime = DateTime.now();
    _restoreSavedState();
  }

  /// 构建候选字盘
  void _buildCandidateBoard() {
    // 收集所有正确答案
    final correctAnswers = <String>[];
    for (final placement in widget.level.placements) {
      for (int k = 0; k < placement.idiom.text.length; k++) {
        final (r, c) = placement.cellAt(k);
        if (!widget.level.grid.cellAt(r, c).isGiven) {
          correctAnswers.add(placement.idiom.text[k]);
        }
      }
    }

    _candidateBoard = _distractorEngine.generateCandidateBoard(
      correctAnswers: correctAnswers,
      rows: 3,
      countPerRow: 10,
    );
  }

  /// 找到第一个空白格作为初始焦点
  void _findFirstEmptyCell() {
    for (int r = 0; r < _grid.rows; r++) {
      for (int c = 0; c < _grid.cols; c++) {
        final cell = _grid.cellAt(r, c);
        if (cell.state == CellState.filled && !cell.isGiven) {
          _focusRow = r;
          _focusCol = c;
          // 根据格子所属成语确定初始方向
          _currentDirection = _getDirectionForCell(r, c);
          return;
        }
      }
    }
  }

  /// 尝试恢复本关未完成存档
  Future<void> _restoreSavedState() async {
    try {
      final saved = await ref
          .read(databaseProvider)
          .getLevelState(widget.level.levelId);
      if (saved == null) {
        if (mounted) setState(() => _restoring = false);
        return;
      }
      final state = decodeGameState(saved.stateJson);
      if (state == null) {
        if (mounted) setState(() => _restoring = false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _candidateBoard = state.candidateBoard;
        _playerAnswers.addAll(state.answers);
        _usedCandidateSlots.addAll(state.usedCandidateSlots);
        _fillHistory.addAll(state.fillHistory);
        _cellToCandidateSlot.addAll(state.cellToCandidateSlot);
        _hintUsesThisLevel = state.hintUsesThisLevel;
        _idiomHintUsed = state.idiomHintUsed;
        _errorsMade = state.errorsMade;
        _correctStreak = state.correctStreak;
        if (state.focusRow != null && state.focusCol != null) {
          _focusRow = state.focusRow!;
          _focusCol = state.focusCol!;
          _currentDirection = state.direction;
        }
        _recomputeDerivedState();
        _restoring = false;
      });
    } catch (_) {
      if (mounted) setState(() => _restoring = false);
    }
  }

  /// 根据当前答案重建派生状态（错误格、完成格、完成成语列表）
  void _recomputeDerivedState() {
    _errorCells.clear();
    _completedCells.clear();
    _completedIdiomList.clear();
    _selectedCompletedIndex = null;

    for (final placement in widget.level.placements) {
      var allFilled = true;
      var allCorrect = true;
      for (int k = 0; k < placement.idiom.text.length; k++) {
        final (r, c) = placement.cellAt(k);
        if (_grid.cellAt(r, c).isGiven) continue;
        final filled = _playerAnswers[(r, c)];
        if (filled == null) {
          allFilled = false;
        } else if (filled != placement.idiom.text[k]) {
          allCorrect = false;
          _errorCells.add((r, c));
        }
      }
      if (allFilled && allCorrect) {
        for (int k = 0; k < placement.idiom.text.length; k++) {
          final (r, c) = placement.cellAt(k);
          if (!_grid.cellAt(r, c).isGiven) {
            _completedCells.add((r, c));
          }
        }
        _completedIdiomList.add((
          word: placement.idiom.text,
          meaning: placement.idiom.meaning,
        ));
      }
    }
    if (_completedIdiomList.isNotEmpty) {
      _selectedCompletedIndex = _completedIdiomList.length - 1;
    }
  }

  /// 把当前进度写入存档（断点续玩）
  Future<void> _saveState() async {
    if (_levelFinished || widget.level.levelId <= 0) return;
    try {
      final db = ref.read(databaseProvider);
      await db.saveLevelState(
        levelNumber: widget.level.levelId,
        levelJson: encodeLevel(widget.level),
        stateJson: encodeGameState(
          SavedGameState(
            answers: Map.from(_playerAnswers),
            usedCandidateSlots: Set.from(_usedCandidateSlots),
            fillHistory: List.from(_fillHistory),
            cellToCandidateSlot: Map.from(_cellToCandidateSlot),
            candidateBoard: _candidateBoard
                .map((r) => List<String>.from(r))
                .toList(),
            hintUsesThisLevel: _hintUsesThisLevel,
            idiomHintUsed: _idiomHintUsed,
            errorsMade: _errorsMade,
            correctStreak: _correctStreak,
            focusRow: _focusRow < 0 ? null : _focusRow,
            focusCol: _focusCol < 0 ? null : _focusCol,
            direction: _currentDirection,
          ),
        ),
      );
    } catch (_) {
      // 存档失败不影响游戏进行
    }
  }

  /// 解锁成就并提示（幂等）
  Future<void> _unlockAndNotify(AchievementId id) async {
    try {
      await ref.read(databaseProvider).unlockAchievement(id.name);
    } catch (_) {}
    if (!mounted) return;
    final def = achievementDefs.firstWhere((d) => d.id == id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🏅 解锁成就：${def.title}'),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  /// 正确填字时的闪烁反馈
  void _flashCellAt(int row, int col) {
    setState(() => _flashCell = (row, col));
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted && _flashCell == (row, col)) {
        setState(() => _flashCell = null);
      }
    });
  }

  @override
  void dispose() {
    // 中途退出时保存进度；通关/放弃后 _levelFinished 为 true 不再写
    if (!_levelFinished && widget.level.levelId > 0) {
      _saveState();
    }
    super.dispose();
  }

  /// 获取格子所属成语的方向
  Direction? _getDirectionForCell(int row, int col) {
    final placements = _placementsContaining(row, col);
    return placements.isEmpty ? null : placements.first.direction;
  }

  /// 所有经过 (row, col) 的成语放置
  List<Placement> _placementsContaining(int row, int col) {
    final target = (row, col);
    return widget.level.placements
        .where((p) => p.cells.any((c) => c == target))
        .toList();
  }

  /// (row, col) 的正确字（该格可能属于多个成语，答案一致）
  String? _correctCharForCell(int row, int col) {
    for (final placement in _placementsContaining(row, col)) {
      return placement.idiom.text[placement.cells.indexOf((row, col))];
    }
    return null;
  }

  /// 玩家点击候选字
  void _onCandidateTap(int row, int col, String char) {
    if (_focusRow < 0 || _focusCol < 0) return;
    if (_completedCells.contains((_focusRow, _focusCol))) return;

    final cell = _grid.cellAt(_focusRow, _focusCol);
    if (cell.isGiven) return;

    final filledRow = _focusRow;
    final filledCol = _focusCol;
    final isCorrect = char == _correctCharForCell(filledRow, filledCol);
    if (isCorrect) {
      _correctStreak++;
      if (_correctStreak >= 10 && !_streak10Handled) {
        _streak10Handled = true;
        _unlockAndNotify(AchievementId.streak10);
      }
    } else {
      _errorsMade++;
      _correctStreak = 0;
    }

    setState(() {
      // 覆盖填入时，释放旧字占用的候选槽位
      final oldSlot = _cellToCandidateSlot[(_focusRow, _focusCol)];
      if (oldSlot != null) {
        _usedCandidateSlots.remove(oldSlot);
      }
      _playerAnswers[(_focusRow, _focusCol)] = char;
      _usedCandidateSlots.add((row, col));
      _fillHistory.add((
        row: _focusRow,
        col: _focusCol,
        candRow: row,
        candCol: col,
      ));
      _cellToCandidateSlot[(_focusRow, _focusCol)] = (row, col);
      _checkCompletionForCurrentIdiom();
    });

    HapticFeedback.lightImpact();
    GameAudio.instance.play(isCorrect ? 'correct.wav' : 'wrong.wav');
    _moveToNextEmptyCell();
    if (isCorrect) _flashCellAt(filledRow, filledCol);
    _saveState();
  }

  /// 检查当前焦点所在成语的完成状态
  void _checkCompletionForCurrentIdiom() {
    // 焦点格可能同时属于横、纵两个成语，需要都检查
    for (final placement in _placementsContaining(_focusRow, _focusCol)) {
      _checkIdiomCompletion(placement);
    }
  }

  /// 检查一个成语是否已被完整且正确地填入
  void _checkIdiomCompletion(Placement placement) {
    // 先清除这个 placement 的旧错误标记，再重新计算
    for (int k = 0; k < placement.idiom.text.length; k++) {
      final (r, c) = placement.cellAt(k);
      if (_grid.cellAt(r, c).isGiven) continue;
      _errorCells.remove((r, c));
    }

    bool allFilled = true;
    bool allCorrect = true;

    for (int k = 0; k < placement.idiom.text.length; k++) {
      final (r, c) = placement.cellAt(k);
      final cell = _grid.cellAt(r, c);
      if (cell.isGiven) continue;

      final filled = _playerAnswers[(r, c)];
      if (filled == null) {
        allFilled = false;
      } else if (filled != placement.idiom.text[k]) {
        allCorrect = false;
        _errorCells.add((r, c));
      }
    }

    if (!allFilled || !allCorrect) return;

    // 成语完成
    HapticFeedback.mediumImpact();
    GameAudio.instance.play('idiom.wav');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✓ ${placement.idiom.text}'),
        duration: const Duration(milliseconds: 800),
      ),
    );

    // 记录已完成格子
    for (int k = 0; k < placement.idiom.text.length; k++) {
      final (r, c) = placement.cellAt(k);
      if (!_grid.cellAt(r, c).isGiven) {
        _completedCells.add((r, c));
      }
    }
    _completedIdiomList.add((
      word: placement.idiom.text,
      meaning: placement.idiom.meaning,
    ));
    _selectedCompletedIndex = _completedIdiomList.length - 1;
  }

  /// 自动移到下一个空白格（沿当前成语方向移动）
  void _moveToNextEmptyCell() {
    // 找到包含当前格子的所有成语
    final containingPlacements = _placementsContaining(
      _focusRow,
      _focusCol,
    ).map((p) => (p, p.cells.indexOf((_focusRow, _focusCol)))).toList();

    // 优先沿当前方向继续
    if (_currentDirection != null) {
      for (final (placement, k) in containingPlacements) {
        if (placement.direction == _currentDirection) {
          // 沿当前方向找下一个空位
          for (int next = k + 1; next < placement.idiom.text.length; next++) {
            final (nr, nc) = placement.cellAt(next);
            final cell = _grid.cellAt(nr, nc);
            if (cell.state == CellState.filled &&
                !cell.isGiven &&
                !_playerAnswers.containsKey((nr, nc))) {
              setState(() {
                _focusRow = nr;
                _focusCol = nc;
              });
              return;
            }
          }
        }
      }
    }

    // 当前方向没有了，尝试其他方向
    for (final (placement, k) in containingPlacements) {
      // 跳过已尝试的方向
      if (placement.direction == _currentDirection) continue;

      for (int next = k + 1; next < placement.idiom.text.length; next++) {
        final (nr, nc) = placement.cellAt(next);
        final cell = _grid.cellAt(nr, nc);
        if (cell.state == CellState.filled &&
            !cell.isGiven &&
            !_playerAnswers.containsKey((nr, nc))) {
          setState(() {
            _focusRow = nr;
            _focusCol = nc;
            _currentDirection = placement.direction; // 切换方向
          });
          return;
        }
      }
    }

    // 没找到同方向的，回退到逐行扫描
    for (int r = 0; r < _grid.rows; r++) {
      for (int c = 0; c < _grid.cols; c++) {
        final cell = _grid.cellAt(r, c);
        if (cell.state == CellState.filled &&
            !cell.isGiven &&
            !_playerAnswers.containsKey((r, c))) {
          setState(() {
            _focusRow = r;
            _focusCol = c;
            _currentDirection = null; // 重置方向
          });
          return;
        }
      }
    }
    // 全部填完
    _focusRow = -1;
    _focusCol = -1;
    _currentDirection = null;
    _checkLevelComplete();
  }

  /// 检查整关是否完成
  void _checkLevelComplete() {
    if (_revealedAll) return;
    bool allDone = true;
    for (final placement in widget.level.placements) {
      for (int k = 0; k < placement.idiom.text.length; k++) {
        final (r, c) = placement.cellAt(k);
        if (!_grid.cellAt(r, c).isGiven) {
          final filled = _playerAnswers[(r, c)];
          if (filled != placement.idiom.text[k]) {
            allDone = false;
            break;
          }
        }
      }
    }
    if (allDone) {
      HapticFeedback.heavyImpact();
      GameAudio.instance.play('complete.wav');
      _onLevelComplete();
    }
  }

  /// 处理关卡完成，计算经验值并更新玩家状态
  void _onLevelComplete() async {
    final db = ref.read(databaseProvider);

    // 自定义练习关：只提示完成，不发放奖励/记录历史
    if (widget.isCustom) {
      _levelFinished = true;
      _showCustomCompleteDialog(
        DateTime.now().difference(_levelStartTime).inMilliseconds,
      );
      return;
    }

    // 重玩已通关的关卡不重复发放奖励
    if (await db.isLevelCompleted(widget.level.levelId)) {
      await db.clearLevelState(widget.level.levelId);
      _levelFinished = true;
      _showReplayCompleteDialog();
      return;
    }

    final player = ref.read(playerProvider.notifier);
    final result = await player.completeLevel(
      widget.level.levelId,
      widget.level.idioms.map((i) => i.difficulty).toList(),
    );

    // 通关成语自动收录 + 记录关卡历史
    final idiomIds = <int>[];
    final idByWord = await db.findIdiomIdsByWords(
      widget.level.idioms.map((i) => i.text).toList(),
    );
    for (final idiom in widget.level.idioms) {
      final id = idByWord[idiom.text];
      if (id != null) {
        idiomIds.add(id);
        await db.addToCollection(id);
      }
    }
    final timeSpentMs = DateTime.now()
        .difference(_levelStartTime)
        .inMilliseconds;
    await db.addLevelHistory(
      levelNumber: widget.level.levelId,
      xpGained: result.xpGained,
      idiomsUsed: idiomIds,
      timeSpentMs: timeSpentMs,
      hintsUsed: _hintUsesThisLevel,
      errorsMade: _errorsMade,
    );

    // 成就判定
    final alreadyUnlocked = <AchievementId>{};
    for (final s in await db.getUnlockedAchievementIds()) {
      for (final id in AchievementId.values) {
        if (id.name == s) alreadyUnlocked.add(id);
      }
    }
    final newly = AchievementManager.evaluateOnLevelComplete(
      alreadyUnlocked: alreadyUnlocked,
      levelNumber: widget.level.levelId,
      completedLevels: ref.read(playerProvider).completedLevels,
      isDaily: _isDaily,
      hintsUsed: _hintUsesThisLevel,
      errorsMade: _errorsMade,
      timeSpentMs: timeSpentMs,
      collectionCount: await db.getCollectionCount(),
    );
    for (final id in newly) {
      await db.unlockAchievement(id.name);
    }
    final newDefs = achievementDefs.where((d) => newly.contains(d.id)).toList();

    await db.clearLevelState(widget.level.levelId);
    _levelFinished = true;
    if (_isDaily) {
      // 每日挑战用时上报 Game Center 排行榜
      await LeaderboardService.submitDailyTime(
        DateTime.now().difference(_levelStartTime),
      );
    }

    if (result.leveledUp && result.reward != null) {
      _showRewardDialog(
        result.newLevel,
        result.reward!,
        result,
        newDefs,
        timeSpentMs,
      );
    } else {
      _showCompletionDialog(result, newDefs, timeSpentMs);
    }
  }

  /// 显示升级奖励对话框
  void _showRewardDialog(
    int newLevel,
    LevelReward reward,
    ExperienceResult result,
    List<AchievementDef> newAchievements,
    int timeSpentMs,
  ) {
    final title = GrowthManager.titleForLevel(newLevel);
    final rewardText = reward.type == RewardType.functional
        ? '${reward.item == "hint_card" ? "提示卡" : "复活卡"} x${reward.quantity}'
        : '装饰: ${reward.item}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恭喜升级！'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('你已升到 Lv.$newLevel $title'),
            const SizedBox(height: 12),
            Text('获得奖励: $rewardText'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showCompletionDialog(result, newAchievements, timeSpentMs);
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  /// 显示过关对话框（带庆祝动画，可进入下一关）
  void _showCompletionDialog(
    ExperienceResult result,
    List<AchievementDef> newAchievements,
    int timeSpentMs,
  ) {
    final isDaily = _isDaily;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (ctx, t, child) => Transform.scale(
          scale: t,
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        ),
        child: AlertDialog(
          title: Text(isDaily ? '🎉 每日挑战完成！' : '🎉 恭喜过关！'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('你完成了 "${widget.level.title}"'),
              const SizedBox(height: 8),
              Text(
                '获得经验 +${result.xpGained}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.brown.shade700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '用时 ${_formatDuration(timeSpentMs)} · '
                '提示 $_hintUsesThisLevel · 填错 $_errorsMade',
                style: TextStyle(fontSize: 13, color: Colors.brown.shade500),
              ),
              if (newAchievements.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '🏅 解锁成就：'
                  '${newAchievements.map((d) => d.title).join('、')}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('返回'),
            ),
            if (!isDaily)
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _startNextLevel();
                },
                child: const Text('下一关'),
              ),
            TextButton(
              onPressed: () => _showLearning(ctx),
              child: const Text('复习成语'),
            ),
          ],
        ),
      ),
    );
  }

  /// 自定义练习关完成对话框
  void _showCustomCompleteDialog(int timeSpentMs) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 完成！'),
        content: Text(
          '自定义关卡为练习模式，不计入通关进度。\n\n'
          '用时 ${_formatDuration(timeSpentMs)} · '
          '提示 $_hintUsesThisLevel · 填错 $_errorsMade',
        ),
        actions: [
          TextButton(
            onPressed: () => _showLearning(ctx),
            child: const Text('复习成语'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  /// 打开本关成语学习页（释义/出处/例句）
  void _showLearning(BuildContext dialogContext) {
    Navigator.of(dialogContext).push(
      MaterialPageRoute(
        builder: (_) => LearningScreen(
          words: widget.level.idioms.map((i) => i.text).toList(),
        ),
      ),
    );
  }

  /// 每日挑战关卡（专用关卡号段）
  bool get _isDaily => widget.level.levelId >= dailyLevelOffset;

  String _formatDuration(int ms) {
    if (ms <= 0) return '—';
    final seconds = (ms / 1000).round();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '$m分$s秒' : '$s秒';
  }

  /// 重玩已通关关卡：不再发放奖励
  void _showReplayCompleteDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('本关已完成'),
        content: const Text('重玩关卡不重复发放经验与收藏。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('返回'),
          ),
        ],
      ),
    );
  }

  /// 直接进入下一关
  Future<void> _startNextLevel() async {
    showLevelLoadingDialog(context);
    try {
      final db = ref.read(databaseProvider);
      final level = await loadOrGenerateLevel(db, widget.level.levelId + 1);
      if (!mounted) return;
      Navigator.pop(context); // 关闭加载框
      if (level == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('下一关生成失败，请重试')));
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GameScreen(level: level)),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('错误: $e')));
      }
    }
  }

  /// 点击网格中的格子切换焦点
  void _onGridTap(int row, int col) {
    final cell = _grid.cellAt(row, col);
    if (cell.state == CellState.blocked || cell.isGiven) return;
    if (_completedCells.contains((row, col))) return;

    // PRD 6.3：再次点击已聚焦的已填格 → 清除该字
    if (row == _focusRow &&
        col == _focusCol &&
        _playerAnswers.containsKey((row, col))) {
      _clearCell();
      return;
    }

    setState(() {
      _focusRow = row;
      _focusCol = col;
      _currentDirection = _getDirectionForCell(row, col);
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8), // 仿古纸色
      appBar: AppBar(
        title: Text(widget.level.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_off),
            tooltip: '揭示全部',
            color: Colors.brown.shade700,
            onPressed: _revealAll,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: LevelDisplay(),
          ),
        ],
      ),
      body: SafeArea(
        child: _restoring
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // 已完成成语 tags + 释义
                  _buildCompletedIdiomsSection(),

                  // 填字网格（占据上半部分）
                  Expanded(flex: 5, child: _buildGrid()),

                  // 候选字盘（下半部分）
                  Expanded(flex: 3, child: _buildCandidateBoardWidget()),

                  // 底部工具栏
                  _buildToolbar(),
                ],
              ),
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        final cellSize = 48.0;
        final maxCellWidth = availableWidth / _grid.cols;
        final maxCellHeight = availableHeight / _grid.rows;
        final actualCellSize = min(cellSize, min(maxCellWidth, maxCellHeight));

        final gridWidth = _grid.cols * actualCellSize;
        final gridHeight = _grid.rows * actualCellSize;

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            final offsetX = (availableWidth - gridWidth) / 2;
            final offsetY = (availableHeight - gridHeight) / 2;

            final cellX = (event.localPosition.dx - offsetX) / actualCellSize;
            final cellY = (event.localPosition.dy - offsetY) / actualCellSize;

            final col = cellX.floor();
            final row = cellY.floor();

            if (row >= 0 && row < _grid.rows && col >= 0 && col < _grid.cols) {
              _onGridTap(row, col);
            }
          },
          child: Center(
            child: SizedBox(
              width: gridWidth,
              height: gridHeight,
              child: CustomPaint(
                painter: GridPainter(
                  grid: _grid,
                  playerAnswers: _playerAnswers,
                  focusRow: _focusRow,
                  focusCol: _focusCol,
                  errorCells: _errorCells,
                  completedCells: _completedCells,
                  flashCell: _flashCell,
                  cellSize: actualCellSize,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompletedIdiomsSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_completedIdiomList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 3,
              children: _completedIdiomList.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                final isSelected = _selectedCompletedIndex == i;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCompletedIndex = isSelected ? null : i;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.green.shade100
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? Colors.green.shade700
                            : Colors.green.shade300,
                      ),
                    ),
                    child: Text(
                      item.word,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        if (_selectedCompletedIndex != null)
          Container(
            height: 36,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AutoSizeText(
              _completedIdiomList[_selectedCompletedIndex!].meaning,
              maxLines: 2,
              minFontSize: 10,
              stepGranularity: 1,
              style: TextStyle(
                fontSize: 13,
                color: Colors.brown.shade600,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildCandidateBoardWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _candidateBoard.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final row = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.asMap().entries.map((cellEntry) {
                final colIndex = cellEntry.key;
                final char = cellEntry.value;
                final isUsed = _usedCandidateSlots.contains((
                  rowIndex,
                  colIndex,
                ));
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: SizedBox(
                    width: 34,
                    height: 36,
                    child: Material(
                      color: isUsed
                          ? Colors.brown.shade100
                          : Colors.brown.shade50,
                      borderRadius: BorderRadius.circular(6),
                      elevation: isUsed ? 0 : 1,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: isUsed
                            ? null
                            : () => _onCandidateTap(rowIndex, colIndex, char),
                        child: Center(
                          child: Text(
                            char,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: isUsed
                                  ? Colors.brown.shade300
                                  : Colors.brown.shade900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildToolbar() {
    final playerState = ref.watch(playerProvider);
    final hintCount = playerState.functionalItems['hint_card'] ?? 0;
    final freeHintsLeft = max(0, 3 - _hintUsesThisLevel);
    final focusReady =
        _focusRow >= 0 &&
        _focusCol >= 0 &&
        !_completedCells.contains((_focusRow, _focusCol)) &&
        !_grid.cellAt(_focusRow, _focusCol).isGiven &&
        !_hasCorrectAnswer();
    final canSingleHint = focusReady && (freeHintsLeft > 0 || hintCount > 0);
    final canIdiomHint = focusReady && !_idiomHintUsed;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarButton(icon: Icons.undo, label: '撤销', onTap: _undo),
          _ToolbarButton(
            icon: Icons.lightbulb_outline,
            label: freeHintsLeft > 0 ? '一字×$freeHintsLeft' : '提示卡×$hintCount',
            onTap: canSingleHint ? _showHint : null,
          ),
          _ToolbarButton(
            icon: Icons.auto_awesome,
            label: '成语',
            onTap: canIdiomHint ? _showIdiomHint : null,
          ),
          _ToolbarButton(
            icon: Icons.delete_outline,
            label: '清除',
            onTap: _clearCell,
          ),
        ],
      ),
    );
  }

  bool _hasCorrectAnswer() {
    if (_focusRow < 0 || _focusCol < 0) return false;
    return _playerAnswers[(_focusRow, _focusCol)] ==
        _correctCharForCell(_focusRow, _focusCol);
  }

  void _undo() {
    if (_fillHistory.isEmpty) return;
    final entry = _fillHistory.last;
    if (_completedCells.contains((entry.row, entry.col))) return;
    _fillHistory.removeLast();
    setState(() {
      _playerAnswers.remove((entry.row, entry.col));
      _usedCandidateSlots.remove((entry.candRow, entry.candCol));
      _errorCells.remove((entry.row, entry.col));
      _cellToCandidateSlot.remove((entry.row, entry.col));
    });
    _focusRow = entry.row;
    _focusCol = entry.col;
    _currentDirection = null;
    _saveState();
  }

  /// 一字提示：前 3 次免费，之后消耗提示卡
  Future<void> _showHint() async {
    if (_focusRow < 0 || _focusCol < 0) return;
    if (_completedCells.contains((_focusRow, _focusCol))) return;
    final cell = _grid.cellAt(_focusRow, _focusCol);
    if (cell.isGiven) return;

    // 找到焦点格子的正确字
    final correctChar = _correctCharForCell(_focusRow, _focusCol);
    if (correctChar == null ||
        _playerAnswers[(_focusRow, _focusCol)] == correctChar) {
      return;
    }

    final freeLeft = 3 - _hintUsesThisLevel;
    final hintCards =
        ref.read(playerProvider).functionalItems['hint_card'] ?? 0;
    if (freeLeft <= 0 && hintCards <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本关一字提示次数已用完，且没有提示卡')));
      return;
    }
    if (freeLeft <= 0) {
      await ref.read(playerProvider.notifier).useHintCard();
    }
    _hintUsesThisLevel++;

    setState(() {
      _applyAnswer(_focusRow, _focusCol, correctChar);
      _checkCompletionForCurrentIdiom();
    });

    HapticFeedback.lightImpact();
    GameAudio.instance.play('fill.wav');
    _saveState();
  }

  /// 成语提示：揭示当前焦点所在成语的全部空格（每关一次，免费）
  void _showIdiomHint() {
    if (_focusRow < 0 || _focusCol < 0 || _idiomHintUsed) return;
    final placements = _placementsContaining(_focusRow, _focusCol);
    if (placements.isEmpty) return;

    final placement = placements.first;
    if (_isPlacementComplete(placement)) return;

    _idiomHintUsed = true;
    setState(() {
      for (int k = 0; k < placement.idiom.text.length; k++) {
        final (r, c) = placement.cellAt(k);
        if (_grid.cellAt(r, c).isGiven || _playerAnswers.containsKey((r, c))) {
          continue;
        }
        _applyAnswer(r, c, placement.idiom.text[k]);
      }
      _checkIdiomCompletion(placement);
    });
    HapticFeedback.mediumImpact();
    _saveState();
  }

  /// 全图揭示：填满全部答案，视为放弃本关（不计入通关）
  void _revealAll() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('揭示全部答案？'),
        content: const Text('将直接显示全部答案，并视为放弃本关，不计入通关。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('揭示'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true || !mounted) return;
      setState(() {
        _revealedAll = true;
        for (final placement in widget.level.placements) {
          for (int k = 0; k < placement.idiom.text.length; k++) {
            final (r, c) = placement.cellAt(k);
            if (_grid.cellAt(r, c).isGiven ||
                _playerAnswers.containsKey((r, c))) {
              continue;
            }
            _applyAnswer(r, c, placement.idiom.text[k]);
          }
        }
      });
      _focusRow = -1;
      _focusCol = -1;
      HapticFeedback.mediumImpact();
      try {
        await ref.read(databaseProvider).clearLevelState(widget.level.levelId);
      } catch (_) {}
      _levelFinished = true;
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('已揭示全部答案'),
          content: const Text('本关视为放弃，不计入通关。'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (mounted) Navigator.of(context).pop();
              },
              child: const Text('返回'),
            ),
          ],
        ),
      );
    });
  }

  /// 找候选字盘中未被使用的正确答案槽位
  (int, int)? _findFreeCandidateSlot(String char) {
    for (int r = 0; r < _candidateBoard.length; r++) {
      for (int c = 0; c < _candidateBoard[r].length; c++) {
        if (_candidateBoard[r][c] == char &&
            !_usedCandidateSlots.contains((r, c))) {
          return (r, c);
        }
      }
    }
    return null;
  }

  /// 在格子里填入答案并记录候选槽位占用（需在 setState 内调用）
  void _applyAnswer(int row, int col, String char) {
    _playerAnswers[(row, col)] = char;
    _errorCells.remove((row, col));
    final slot = _findFreeCandidateSlot(char);
    if (slot != null) {
      _usedCandidateSlots.add(slot);
      _fillHistory.add((
        row: row,
        col: col,
        candRow: slot.$1,
        candCol: slot.$2,
      ));
      _cellToCandidateSlot[(row, col)] = slot;
    }
  }

  /// 一个成语的所有空格是否已正确填满
  bool _isPlacementComplete(Placement placement) {
    for (int k = 0; k < placement.idiom.text.length; k++) {
      final (r, c) = placement.cellAt(k);
      if (_grid.cellAt(r, c).isGiven) continue;
      if (_playerAnswers[(r, c)] != placement.idiom.text[k]) return false;
    }
    return true;
  }

  void _clearCell() {
    if (_focusRow < 0 || _focusCol < 0) return;
    if (_completedCells.contains((_focusRow, _focusCol))) return;
    setState(() {
      _playerAnswers.remove((_focusRow, _focusCol));
      _errorCells.remove((_focusRow, _focusCol));
      final candSlot = _cellToCandidateSlot.remove((_focusRow, _focusCol));
      if (candSlot != null) {
        _usedCandidateSlots.remove(candSlot);
      }
    });
    _saveState();
  }
}

/// 底部工具栏按钮
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ToolbarButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: enabled ? Colors.brown.shade700 : Colors.brown.shade300,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: enabled ? Colors.brown.shade600 : Colors.brown.shade300,
            ),
          ),
        ],
      ),
    );
  }
}

/// 填字网格绘制器
class GridPainter extends CustomPainter {
  final CrosswordGrid grid;
  final Map<(int, int), String> playerAnswers;
  final int focusRow;
  final int focusCol;
  final Set<(int, int)> errorCells;
  final Set<(int, int)> completedCells;
  final (int, int)? flashCell;
  final double cellSize;

  GridPainter({
    required this.grid,
    required this.playerAnswers,
    required this.focusRow,
    required this.focusCol,
    required this.errorCells,
    required this.completedCells,
    required this.flashCell,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const cellPadding = 2.0;
    final s = cellSize;
    final fontSize = 26.0 * (s / 48.0);

    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        final cell = grid.cellAt(r, c);
        if (cell.state == CellState.blocked) continue;

        final x = c * s;
        final y = r * s;
        final rect = Rect.fromLTWH(
          x + cellPadding,
          y + cellPadding,
          s - cellPadding * 2,
          s - cellPadding * 2,
        );

        // 背景色
        Color bgColor;
        if (cell.isGiven) {
          bgColor = const Color(0xFFD4C5B0);
        } else if (completedCells.contains((r, c))) {
          bgColor = const Color(0xFFC8E6C9);
        } else if (errorCells.contains((r, c))) {
          bgColor = const Color(0xFFFFCDD2);
        } else if (flashCell == (r, c)) {
          bgColor = const Color(0xFFA5D6A7);
        } else if (focusRow == r && focusCol == c) {
          bgColor = const Color(0xFFFFF9C4);
        } else {
          bgColor = const Color(0xFFFFF8F0);
        }

        // 交叉点底色加深约 10%（PRD 6.2）
        if (cell.isIntersection) {
          bgColor = Color.lerp(bgColor, Colors.black, 0.08)!;
        }

        final paint = Paint()
          ..color = bgColor
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          paint,
        );

        // 边框
        final borderPaint = Paint()
          ..color = (focusRow == r && focusCol == c)
              ? Colors.brown.shade700
              : Colors.brown.shade300
          ..style = PaintingStyle.stroke
          ..strokeWidth = (focusRow == r && focusCol == c) ? 2.5 : 1.0;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          borderPaint,
        );

        // 文字
        final displayChar = cell.isGiven
            ? cell.character
            : (playerAnswers[(r, c)] ?? '');
        // 已填但所属成语尚未完成 → 半透明（"暂定"状态，PRD 6.2）
        final tentative =
            !cell.isGiven &&
            playerAnswers.containsKey((r, c)) &&
            !completedCells.contains((r, c));
        final textColor = cell.isGiven
            ? Colors.brown.shade900
            : playerAnswers.containsKey((r, c))
            ? Colors.brown.shade800
            : Colors.brown.shade400;
        final textPainter = TextPainter(
          text: TextSpan(
            text: displayChar,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: cell.isGiven ? FontWeight.w700 : FontWeight.w500,
              color: tentative ? textColor.withValues(alpha: 0.5) : textColor,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            x + (s - textPainter.width) / 2,
            y + (s - textPainter.height) / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => true;

  @override
  bool hitTest(Offset position) => true;
}

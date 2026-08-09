import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/grid_engine.dart';
import '../../engine/distractor_engine.dart';
import '../../state/database_provider.dart';
import '../../state/player_state.dart';
import '../../state/level_generation.dart';
import '../../state/level_state_codec.dart';
import '../../state/collection_provider.dart';
import '../../state/level_progress_providers.dart';
import '../../state/leaderboard_service.dart';
import '../../data/growth_manager.dart';
import '../../data/achievement_manager.dart';
import '../../audio/game_audio.dart';
import '../widgets/level_loading_dialog.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/win_card_dialog.dart';
import '../widgets/xp_track.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/grid_skins.dart';
import '../theme/decoration_catalog.dart';
import '../../utils/ad_manager.dart';
import 'learning_screen.dart';

/// 游戏主界面
///
/// 布局：
///   ┌──────────────────┐
///   │  顶栏（返回/关卡/声音）│
///   ├──────────────────┤
///   │  本关进度 + XpTrack │
///   ├──────────────────┤
///   │  已完成成语 tags    │
///   ├──────────────────┤
///   │  填字网格区域        │  ← CustomPainter 绘制
///   ├──────────────────┤
///   │  候选字盘 (4行)     │  ← 点击填入
///   ├──────────────────┤
///   │  提示/撤销/清空     │
///   └──────────────────┘

class GameScreen extends ConsumerStatefulWidget {
  final CrosswordLevel level;
  final bool noReward;

  const GameScreen({super.key, required this.level, this.noReward = false});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  static const int _initialLives = 3;
  static const int _dailyTimeLimitSeconds = 120;
  static const double _interstitialAdChance = 0.4;

  late CrosswordGrid _grid;
  final DistractorEngine _distractorEngine = DistractorEngine();

  int _lives = _initialLives;
  int _remainingSeconds = _dailyTimeLimitSeconds;
  Timer? _dailyTimer;
  bool _failed = false;
  bool _revived = false;

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
  final Set<String> _wrongIdiomWords = {};
  int? _selectedCompletedIndex;

  // 本关提示使用情况
  int _hintUsesThisLevel = 0; // 本关使用提示次数（消耗提示卡）
  int _errorsMade = 0; // 错误填写次数（统计用）
  int _correctStreak = 0; // 连续答对字数（成就）
  int _totalFills = 0; // 本关填字尝试次数（正确率统计用）
  final Set<AchievementId> _streakHandled = {}; // 本会话已触发的连击成就
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
    _correctStreak = ref.read(playerProvider).currentCorrectStreak;
    if (_isDaily) _startDailyTimer();
    _restoreSavedState();
    // 提前预加载插屏广告，确保通关结算时有较高概率已就绪
    if (AdManager.isSupportedPlatform) {
      unawaited(AdManager().loadInterstitialAd());
    }
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
      rows: 4,
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
        _errorsMade = state.errorsMade;
        _correctStreak = state.correctStreak;
        _totalFills = state.totalFills;
        _lives = state.lives;
        _remainingSeconds = state.remainingSeconds;
        _revived = state.revived;
        if (state.focusRow != null && state.focusCol != null) {
          _focusRow = state.focusRow!;
          _focusCol = state.focusCol!;
          _currentDirection = state.direction;
        }
        _recomputeDerivedState();
        _restoring = false;
      });
      ref.read(playerProvider.notifier).setCorrectStreak(_correctStreak);
      _rebuildWrongIdiomsFromHistory();
    } catch (_) {
      if (mounted) setState(() => _restoring = false);
    }
  }

  /// 从填字历史重建本局填错过的成语（断点续玩后仍能统计）
  void _rebuildWrongIdiomsFromHistory() {
    _wrongIdiomWords.clear();
    for (final entry in _fillHistory) {
      if (entry.candRow < 0 ||
          entry.candCol < 0 ||
          entry.candRow >= _candidateBoard.length ||
          entry.candCol >= _candidateBoard[entry.candRow].length) {
        continue;
      }
      final filledChar = _candidateBoard[entry.candRow][entry.candCol];
      final correctChar = _correctCharForCell(entry.row, entry.col);
      if (filledChar != correctChar) {
        _wrongIdiomWords.addAll(
          _placementsContaining(entry.row, entry.col).map((p) => p.idiom.text),
        );
      }
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
    if (_levelFinished || _failed || widget.level.levelId <= 0) return;
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
            errorsMade: _errorsMade,
            correctStreak: _correctStreak,
            totalFills: _totalFills,
            lives: _lives,
            remainingSeconds: _remainingSeconds,
            revived: _revived,
            focusRow: _focusRow < 0 ? null : _focusRow,
            focusCol: _focusCol < 0 ? null : _focusCol,
            direction: _currentDirection,
          ),
        ),
      );
      ref.invalidate(nextMainLevelResumableProvider);
    } catch (_) {
      // 存档失败不影响游戏进行
    }
  }

  /// 解锁成就并提示（幂等）
  Future<void> _unlockAndNotify(AchievementId id) async {
    final db = ref.read(databaseProvider);
    try {
      final unlocked = await db.getUnlockedAchievementIds();
      if (unlocked.contains(id.name)) return; // 已解锁过，不再重复提示
      await db.unlockAchievement(id.name);
    } catch (_) {}
    if (!mounted) return;
    final def = achievementDefs.firstWhere((d) => d.id == id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('解锁成就：${def.title}'),
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
    _dailyTimer?.cancel();
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
    _totalFills++; // 本关填字尝试次数（含错误字），提示填入不计
    if (isCorrect) {
      _correctStreak++;
      ref.read(playerProvider.notifier).recordCorrectFill();
      const streakThresholds = [
        (AchievementId.streak10, 10),
        (AchievementId.streak20, 20),
        (AchievementId.streak30, 30),
      ];
      for (final (id, threshold) in streakThresholds) {
        if (_correctStreak >= threshold && !_streakHandled.contains(id)) {
          _streakHandled.add(id);
          _unlockAndNotify(id);
        }
      }
    } else {
      _errorsMade++;
      _lives--;
      _correctStreak = 0;
      _wrongIdiomWords.addAll(
        _placementsContaining(filledRow, filledCol).map((p) => p.idiom.text),
      );
      ref.read(playerProvider.notifier).recordWrongFill();
    }

    var idiomCompleted = false;
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
      idiomCompleted = _checkCompletionForCurrentIdiom();
    });

    if (!isCorrect && _lives <= 0) {
      unawaited(_failLevel());
      return;
    }

    if (isCorrect && idiomCompleted) {
      HapticFeedback.mediumImpact();
      GameAudio.instance.play('idiom.wav');
    } else {
      HapticFeedback.lightImpact();
      GameAudio.instance.play(isCorrect ? 'correct.wav' : 'wrong.wav');
    }
    _moveToNextEmptyCell();
    if (isCorrect) _flashCellAt(filledRow, filledCol);
    _saveState();
  }

  /// 检查当前焦点所在成语的完成状态；返回是否新完成了至少一个成语
  bool _checkCompletionForCurrentIdiom() {
    // 焦点格可能同时属于横、纵两个成语，需要都检查
    var completed = false;
    for (final placement in _placementsContaining(_focusRow, _focusCol)) {
      completed = _checkIdiomCompletion(placement) || completed;
    }
    return completed;
  }

  /// 检查一个成语是否已被完整且正确地填入
  bool _checkIdiomCompletion(Placement placement) {
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

    if (!allFilled || !allCorrect) return false;

    // 成语完成
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('√ ${placement.idiom.text}'),
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
    return true;
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

    // 重玩已通关的关卡不重复发放奖励
    if (await db.isLevelCompleted(widget.level.levelId)) {
      await db.clearLevelState(widget.level.levelId);
      _levelFinished = true;
      _showReplayCompleteDialog();
      return;
    }

    final player = ref.read(playerProvider.notifier);
    final failedBefore =
        _isDaily && await db.getSetting(_dailyNoRewardKey()) == 'true';
    final noReward = widget.noReward || (failedBefore && !_revived);
    final result = noReward
        ? ExperienceResult(
            xpGained: 0,
            leveledUp: false,
            newLevel: ref.read(playerProvider).level,
            reward: null,
          )
        : await player.completeLevel(
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
      totalFills: _totalFills,
      levelJson: encodeLevel(widget.level),
    );
    if (!noReward && failedBefore) {
      await db.setSetting(_dailyNoRewardKey(), 'false');
    }
    ref.invalidate(nextMainLevelProvider);
    ref.invalidate(nextMainLevelResumableProvider);
    ref.invalidate(collectionProvider);
    ref.invalidate(completedLevelsProvider);
    ref.invalidate(levelWordsProvider);

    // 成就判定
    final alreadyUnlocked = <AchievementId>{};
    for (final s in await db.getUnlockedAchievementIds()) {
      for (final id in AchievementId.values) {
        if (id.name == s) alreadyUnlocked.add(id);
      }
    }
    // 从通关历史统计计数类成就的进度（含本次通关）
    var noHintCompletions = 0;
    var flawlessCompletions = 0;
    var speedrunCompletions = 0;
    var dailyCompletions = 0;
    for (final h in await db.getLevelHistory()) {
      if (h.hintsUsed == 0) noHintCompletions++;
      if (h.errorsMade == 0) flawlessCompletions++;
      if (h.timeSpentMs != null && h.timeSpentMs! < 60000) {
        speedrunCompletions++;
      }
      if (h.levelNumber >= dailyLevelOffset) dailyCompletions++;
    }
    final newly = AchievementManager.evaluateOnLevelComplete(
      alreadyUnlocked: alreadyUnlocked,
      levelNumber: widget.level.levelId,
      totalCompleted: ref.read(playerProvider).completedLevels,
      noHintCompletions: noHintCompletions,
      flawlessCompletions: flawlessCompletions,
      speedrunCompletions: speedrunCompletions,
      dailyCompletions: dailyCompletions,
      totalXp: ref.read(playerProvider).totalXp,
      collectionCount: await db.getCollectionCount(),
      isDaily: _isDaily,
      hintsUsed: _hintUsesThisLevel,
      errorsMade: _errorsMade,
      timeSpentMs: timeSpentMs,
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

    await _maybeShowInterstitial(() {
      if (!mounted) return;
      _showSettlement(result, newDefs, timeSpentMs);
    });
  }

  /// 胜利结算弹框前，40% 概率展示插屏广告
  Future<void> _maybeShowInterstitial(VoidCallback onDone) async {
    if (widget.level.levelId <= 5 || // 教学关 1-5 不展示插屏
        !AdManager.isSupportedPlatform ||
        Random().nextDouble() >= _interstitialAdChance) {
      onDone();
      return;
    }
    if (!mounted) return;
    final shownAt = DateTime.now();
    final shown = AdManager().showInterstitialAd(
      onAdClosed: () {
        // 观看超过 10 秒才奖励积分
        if (DateTime.now().difference(shownAt).inSeconds >=
            kInterstitialAdMinViewSeconds) {
          unawaited(
            ref
                .read(playerProvider.notifier)
                .addPoints(kInterstitialAdPointsReward),
          );
        }
        onDone();
      },
    );
    if (!shown) {
      // 未就绪时不阻塞结算弹框，并预加载下一次插屏
      unawaited(AdManager().loadInterstitialAd());
      onDone();
    }
  }

  /// 统一展示升级奖励弹框或通关弹框
  void _showSettlement(
    ExperienceResult result,
    List<AchievementDef> newAchievements,
    int timeSpentMs,
  ) {
    if (result.leveledUp && result.reward != null) {
      _showRewardDialog(
        result.newLevel,
        result.reward!,
        result,
        newAchievements,
        timeSpentMs,
      );
    } else {
      _showCompletionDialog(result, newAchievements, timeSpentMs);
    }
  }

  /// 显示升级奖励 win-card
  void _showRewardDialog(
    int newLevel,
    LevelReward reward,
    ExperienceResult result,
    List<AchievementDef> newAchievements,
    int timeSpentMs,
  ) {
    final title = GrowthManager.titleForLevel(newLevel);
    final rewardText = reward.type == RewardType.functional
        ? '${reward.item == "hint_card" ? "提示卡" : "复活卡"} ×${reward.quantity}'
        : decorationName(reward.item);

    showWinCardDialog(
      context,
      seal: '升',
      title: '晋升 ${GrowthManager.levelLabel(newLevel)} $title',
      subtitle: '获得奖励：$rewardText',
      xpText: '${result.xpGained > 0 ? '+' : ''}${result.xpGained}',
      actions: [
        WinCardAction(
          label: '继续',
          primary: true,
          onTap: () {
            Navigator.of(context).pop();
            _showCompletionDialog(result, newAchievements, timeSpentMs);
          },
        ),
      ],
    );
  }

  /// 显示过关 win-card（可进入下一关）
  void _showCompletionDialog(
    ExperienceResult result,
    List<AchievementDef> newAchievements,
    int timeSpentMs,
  ) {
    final xpText = '${result.xpGained > 0 ? '+' : ''}${result.xpGained}';
    final wrongIdioms = _completedIdiomList
        .where((i) => _wrongIdiomWords.contains(i.word))
        .take(3)
        .map((i) => (word: i.word, meaning: i.meaning))
        .toList();
    showWinCardDialog(
      context,
      seal: '通',
      title: _isDaily ? '每日挑战 · 完成' : '恭喜通过 · ${widget.level.title}',
      subtitle:
          '用时 ${_formatDuration(timeSpentMs)}${(_errorsMade <= 0) ? '' : ' · 填错 $_errorsMade'}',
      xpText: xpText,
      idioms: wrongIdioms,
      actions: [
        if (!_isDaily)
          WinCardAction(
            label: '下一关',
            primary: true,
            onTap: () {
              Navigator.of(context).pop();
              _startNextLevel();
            },
          ),
        WinCardAction(
          label: '学习本关成语',
          ghost: true,
          onTap: () => _showLearning(context),
        ),
        WinCardAction(
          label: '返回主页',
          ghost: true,
          onTap: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ],
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

  String get _countdownText {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatDuration(int ms) {
    if (ms <= 0) return '—';
    final seconds = (ms / 1000).round();
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '$m分$s秒' : '$s秒';
  }

  /// 重玩已通关关卡：不再发放奖励
  void _showReplayCompleteDialog() {
    showWinCardDialog(
      context,
      seal: '通',
      title: '本关已完成',
      subtitle: '重玩关卡不重复发放经验与收藏。',
      xpText: '+0',
      actions: [
        WinCardAction(
          label: '返回',
          ghost: true,
          onTap: () {
            Navigator.of(context).pop();
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ],
    );
  }

  void _startDailyTimer() {
    _dailyTimer?.cancel();
    _dailyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _failed || _levelFinished) return;
      setState(() {
        if (_remainingSeconds > 0) _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        unawaited(_failLevel(timeUp: true));
      }
    });
  }

  Future<void> _failLevel({bool timeUp = false}) async {
    if (_failed || _levelFinished) return;
    _failed = true;
    _dailyTimer?.cancel();
    // 失败后清掉旧存档，避免返回主页再进入时恢复为失败前的低生命值
    try {
      await ref.read(databaseProvider).clearLevelState(widget.level.levelId);
    } catch (_) {}
    if (!mounted) return;
    if (_isDaily) {
      ref.read(databaseProvider).setSetting(_dailyNoRewardKey(), 'true');
    }
    final reviveCount =
        ref.read(playerProvider).functionalItems['revive_card'] ?? 0;
    showWinCardDialog(
      context,
      seal: '败',
      title: '挑战失败',
      subtitle: _isDaily ? (timeUp ? '倒计时结束' : '生命值耗尽') : '生命值耗尽',
      xpText: '+0',
      actions: [
        WinCardAction(
          label: '复活(剩余 $reviveCount)',
          primary: true,
          onTap: _handleRevive,
        ),
        WinCardAction(
          label: _isDaily ? '重玩本关（无经验）' : '重玩本关',
          ghost: true,
          onTap: _replayLevel,
        ),
        WinCardAction(
          label: '返回主页',
          ghost: true,
          onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
        ),
      ],
    );
  }

  Future<void> _handleRevive() async {
    final reviveCount =
        ref.read(playerProvider).functionalItems['revive_card'] ?? 0;
    if (reviveCount <= 0) {
      _showRevivePurchaseDialog();
      return;
    }
    await ref.read(playerProvider.notifier).useReviveCard();
    if (!mounted) return;
    Navigator.of(context).pop(); // 关闭失败弹框
    setState(() {
      _lives = _initialLives;
      _remainingSeconds = _dailyTimeLimitSeconds;
      _failed = false;
      _revived = true;
      _clearWrongAnswers();
    });
    if (_isDaily) _startDailyTimer();
    _saveState();
  }

  Future<void> _replayLevel() async {
    try {
      await ref.read(databaseProvider).clearLevelState(widget.level.levelId);
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pop(); // 关闭失败弹框
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => GameScreen(level: widget.level, noReward: _isDaily),
      ),
    );
  }

  void _clearWrongAnswers() {
    final wrongCells = <(int, int)>{};
    for (final entry in _playerAnswers.entries) {
      final correct = _correctCharForCell(entry.key.$1, entry.key.$2);
      if (entry.value != correct) wrongCells.add(entry.key);
    }
    for (final cell in wrongCells) {
      _playerAnswers.remove(cell);
      final slot = _cellToCandidateSlot.remove(cell);
      if (slot != null) _usedCandidateSlots.remove(slot);
      _errorCells.remove(cell);
    }
    _fillHistory.removeWhere((e) => wrongCells.contains((e.row, e.col)));
    _recomputeDerivedState();
  }

  String _dailyNoRewardKey() => 'daily_no_reward_${widget.level.levelId}';

  void _showRevivePurchaseDialog() {
    final points = ref.read(playerProvider).points;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.accentPale,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: AppIcon(
                        'revive',
                        size: 28,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '复活卡 ×1',
                          style: bodyStyle(size: 15, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '恢复所有生命值，保留已填正确字',
                          style: bodyStyle(size: 11.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$kReviveCardPoints 积分',
                    style: displayStyle(
                      size: 15,
                      weight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '当前积分：$points',
                style: bodyStyle(size: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: () async {
                  final notifier = ref.read(playerProvider.notifier);
                  final ok = await notifier.spendPoints(kReviveCardPoints);
                  if (!ok) {
                    if (!ctx.mounted || !mounted) return;
                    Navigator.of(ctx).pop();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('积分不足，可观看广告赚取积分')),
                    );
                    return;
                  }
                  await notifier.addReviveCards(1);
                  if (!ctx.mounted || !mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  await _handleRevive();
                },
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '购买',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFF6EC),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 直接进入下一关
  Future<void> _startNextLevel() async {
    showLevelLoadingDialog(context);
    try {
      final db = ref.read(databaseProvider);
      final level = await loadOrGenerateLevel(
        db,
        widget.level.levelId + 1,
        globalRange: ref.read(playerProvider).level >= 20,
        playerLevel: ref.read(playerProvider).level,
      );
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

  /// 由手势坐标换算网格格子（网格居中布局，需扣除偏移）
  (int, int)? _cellFromOffset(
    Offset local,
    double availableWidth,
    double availableHeight,
    double gridWidth,
    double gridHeight,
    double cellSize,
  ) {
    final offsetX = (availableWidth - gridWidth) / 2;
    final offsetY = (availableHeight - gridHeight) / 2;
    // 绘制时整体上移/左移 1 格裁掉隐形边框，命中映射需补回这一格
    final col = ((local.dx + cellSize - offsetX) / cellSize).floor();
    final row = ((local.dy + cellSize - offsetY) / cellSize).floor();
    if (row >= 0 && row < _grid.rows && col >= 0 && col < _grid.cols) {
      return (row, col);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _restoring
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildTopBar(),
                  _buildProgress(),
                  _buildCompletedIdiomsSection(),
                  Expanded(flex: 6, child: _buildGrid()),
                  _buildStatusLine(),
                  Expanded(flex: 4, child: _buildCandidateBoardWidget()),
                  _buildToolbar(),
                ],
              ),
      ),
    );
  }

  /// 顶栏：返回 + 关卡标题 + 徽章 + 声音开关
  Widget _buildTopBar() {
    final muted = GameAudio.instance.muted;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: AppIcon('back', size: 20)),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.level.title,
                  style: displayStyle(size: 19, weight: FontWeight.w900),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => GameAudio.instance.muted = !muted),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Opacity(
                  opacity: muted ? 0.4 : 1,
                  child: const AppIcon('sound', size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 本关进度：N/总字数 + XpTrack
  Widget _buildProgress() {
    final total = _blankCount();
    final filled = _completedCells.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '本关进度',
                style: bodyStyle(size: 11.5, color: AppColors.muted),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$filled',
                      style: displayStyle(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                    TextSpan(
                      text: '/$total 字',
                      style: bodyStyle(size: 11.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          XpTrack(progress: total == 0 ? 0 : filled / total),
        ],
      ),
    );
  }

  /// 非 given 的 filled 格总数
  int _blankCount() {
    var count = 0;
    for (int r = 0; r < _grid.rows; r++) {
      for (int c = 0; c < _grid.cols; c++) {
        final cell = _grid.cellAt(r, c);
        if (cell.state == CellState.filled && !cell.isGiven) count++;
      }
    }
    return count;
  }

  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final skin =
              gridSkinById(ref.watch(playerProvider).activeGridSkin) ??
              gridSkins.first;
          final availableWidth = constraints.maxWidth;
          final availableHeight = constraints.maxHeight;

          // 生成器会在内容四周各留 1 格 blocked 边框（不绘制），
          // 按“实际使用区域”而不是整个矩阵计算，避免隐形边距占用显示空间
          final (usedRows, usedCols) = usedGridBounds(_grid);
          if (usedRows <= 0 || usedCols <= 0) {
            return const SizedBox.shrink();
          }
          final actualCellSize = gridCellSize(
            availableWidth: availableWidth,
            availableHeight: availableHeight,
            rows: usedRows,
            cols: usedCols,
          );

          final gridWidth = usedCols * actualCellSize;
          final gridHeight = usedRows * actualCellSize;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final cell = _cellFromOffset(
                details.localPosition,
                availableWidth,
                availableHeight,
                gridWidth,
                gridHeight,
                actualCellSize,
              );
              if (cell != null) _onGridTap(cell.$1, cell.$2);
            },
            child: Center(
              child: SizedBox(
                width: gridWidth,
                height: gridHeight,
                child: ClipRect(
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
                      skin: skin,
                      // 把整个矩阵上移/左移 1 格，裁掉不绘制的边框
                      offset: Offset(-actualCellSize, -actualCellSize),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCompletedIdiomsSection() {
    // 固定高度区域：出现完成词条/释义时不再挤压网格布局（避免抖动）
    return Container(
      height: 116,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: _completedIdiomList.isEmpty
          ? const SizedBox.shrink()
          : SizedBox(
              width: double.infinity,
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 30,
                      child: SizedBox(
                        width: double.infinity,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: _completedIdiomList.asMap().entries.map((
                              entry,
                            ) {
                              final i = entry.key;
                              final item = entry.value;
                              final isSelected = _selectedCompletedIndex == i;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedCompletedIndex = isSelected
                                          ? null
                                          : i;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.accentSoft
                                          : AppColors.surface,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.accent
                                            : AppColors.borderStrong,
                                      ),
                                    ),
                                    child: Text(
                                      item.word,
                                      style: displayStyle(
                                        size: 13,
                                        weight: FontWeight.w600,
                                        color: isSelected
                                            ? AppColors.accent
                                            : AppColors.fg,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    if (_selectedCompletedIndex != null)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '释义：'
                              '${_completedIdiomList[_selectedCompletedIndex!].meaning}',
                              style: bodyStyle(
                                size: 11.5,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildCandidateBoardWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _candidateBoard.asMap().entries.map((entry) {
            final rowIndex = entry.key;
            final row = entry.value;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: row.asMap().entries.map((cellEntry) {
                  final colIndex = cellEntry.key;
                  final char = cellEntry.value;
                  final isUsed = _usedCandidateSlots.contains((
                    rowIndex,
                    colIndex,
                  ));
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isUsed
                          ? null
                          : () => _onCandidateTap(rowIndex, colIndex, char),
                      child: Container(
                        width: 36,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isUsed
                              ? AppColors.surface2
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: isUsed
                                ? AppColors.borderStrong
                                : AppColors.border,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          char,
                          style: displayStyle(
                            size: 19,
                            weight: FontWeight.w600,
                            color: isUsed ? AppColors.faint : AppColors.fg,
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
      ),
    );
  }

  Widget _buildStatusLine() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '生命值：$_lives',
            style: bodyStyle(size: 11.5, color: AppColors.muted),
          ),
          if (_isDaily) ...[
            const SizedBox(width: 16),
            Text(
              '倒计时：$_countdownText',
              style: bodyStyle(size: 11.5, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final playerState = ref.watch(playerProvider);
    final hintCount = playerState.functionalItems['hint_card'] ?? 0;
    final focusReady =
        _focusRow >= 0 &&
        _focusCol >= 0 &&
        !_completedCells.contains((_focusRow, _focusCol)) &&
        !_grid.cellAt(_focusRow, _focusCol).isGiven &&
        !_hasCorrectAnswer();
    final canSingleHint = focusReady && hintCount > 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarButton(icon: 'undo', label: '撤销', onTap: _undo),
          _ToolbarButton(
            icon: 'hint',
            label: '提示',
            sub: '剩 $hintCount',
            onTap: canSingleHint ? _showHint : null,
          ),
          _ToolbarButton(icon: 'clear', label: '清空', onTap: _clearCell),
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

  /// 一字提示：消耗玩家库存提示卡
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

    final hintCards =
        ref.read(playerProvider).functionalItems['hint_card'] ?? 0;
    if (hintCards <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('提示卡不足')));
      return;
    }
    await ref.read(playerProvider.notifier).useHintCard();
    _hintUsesThisLevel++;

    var idiomCompleted = false;
    setState(() {
      _applyAnswer(_focusRow, _focusCol, correctChar);
      idiomCompleted = _checkCompletionForCurrentIdiom();
    });

    if (idiomCompleted) {
      HapticFeedback.mediumImpact();
      GameAudio.instance.play('idiom.wav');
    } else {
      HapticFeedback.lightImpact();
      GameAudio.instance.play('fill.wav');
    }
    _moveToNextEmptyCell();
    _saveState();
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
  final String icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 88,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  icon,
                  size: 22,
                  color: enabled ? AppColors.fg : AppColors.faint,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: bodyStyle(
                    size: 11,
                    weight: FontWeight.w600,
                    color: enabled ? AppColors.fg : AppColors.faint,
                  ),
                ),
              ],
            ),
            if (sub != null)
              Positioned(
                top: 4,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: enabled ? AppColors.accentPale : AppColors.surface2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    sub!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: enabled ? AppColors.accent : AppColors.faint,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 网格单元尺寸：在可用区域内取最大的正方形单元格
double gridCellSize({
  required double availableWidth,
  required double availableHeight,
  required int rows,
  required int cols,
}) {
  if (rows <= 0 || cols <= 0) return 0;
  return min(availableWidth / cols, availableHeight / rows);
}

/// 网格实际使用区域（非 blocked 单元格的包围盒，不含生成器留下的隐形边框）
(int, int) usedGridBounds(CrosswordGrid grid) {
  int minRow = grid.rows, maxRow = -1;
  int minCol = grid.cols, maxCol = -1;
  for (int r = 0; r < grid.rows; r++) {
    for (int c = 0; c < grid.cols; c++) {
      if (grid.cellAt(r, c).state == CellState.blocked) continue;
      if (r < minRow) minRow = r;
      if (r > maxRow) maxRow = r;
      if (c < minCol) minCol = c;
      if (c > maxCol) maxCol = c;
    }
  }
  if (maxRow < minRow || maxCol < minCol) return (0, 0);
  return (maxRow - minRow + 1, maxCol - minCol + 1);
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
  final GridSkin skin;
  final Offset offset;

  GridPainter({
    required this.grid,
    required this.playerAnswers,
    required this.focusRow,
    required this.focusCol,
    required this.errorCells,
    required this.completedCells,
    required this.flashCell,
    required this.cellSize,
    required this.skin,
    required this.offset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(offset.dx, offset.dy);
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

        // 背景色（按设计配色）
        Color bgColor;
        if (cell.isGiven) {
          bgColor = skin.surface2;
        } else if (completedCells.contains((r, c))) {
          bgColor = skin.leafSoft;
        } else if (errorCells.contains((r, c))) {
          bgColor = skin.accent;
        } else if (flashCell == (r, c)) {
          bgColor = skin.leafSoft;
        } else if (focusRow == r && focusCol == c) {
          bgColor = skin.accentPale;
        } else {
          bgColor = skin.surface;
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

        // given 格右上角朱砂小圆点
        if (cell.isGiven) {
          canvas.drawCircle(
            Offset(x + s - 6, y + 6),
            2.5,
            Paint()..color = skin.accent,
          );
        }

        // 边框（focus 格朱砂描边 + 外光晕）
        final isFocus = focusRow == r && focusCol == c;
        if (isFocus) {
          final glow = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = skin.accent.withValues(alpha: 0.25);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)),
            glow,
          );
        }
        final borderPaint = Paint()
          ..color = isFocus ? skin.accent : skin.borderStrong
          ..style = PaintingStyle.stroke
          ..strokeWidth = isFocus ? 2.5 : 1.0;
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

        Color textColor;
        if (cell.isGiven) {
          textColor = skin.foreground;
        } else if (completedCells.contains((r, c))) {
          textColor = skin.leaf;
        } else if (errorCells.contains((r, c))) {
          textColor = const Color(0xFFFFF6EC);
        } else {
          textColor = skin.accentDeep;
        }

        final textPainter = TextPainter(
          text: TextSpan(
            text: displayChar,
            style: TextStyle(
              fontFamily: kSerif,
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

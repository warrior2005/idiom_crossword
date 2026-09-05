import 'dart:async';
import 'dart:math';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../app_page_route.dart';
import '../../engine/grid_engine.dart';
import '../../engine/candidate_ambiguity.dart';
import '../../engine/distractor_engine.dart';
import '../../state/database_provider.dart';
import '../../state/daily_challenge.dart';
import '../../state/daily_reminder.dart';
import '../../state/player_state.dart';
import '../../state/level_generation.dart';
import '../../state/level_state_codec.dart';
import '../../state/collection_provider.dart';
import '../../state/level_progress_providers.dart';
import '../../state/leaderboard_service.dart';
import '../../data/growth_manager.dart';
import '../../data/achievement_manager.dart';
import '../../reviews/app_review.dart';
import '../../audio/music_manager.dart';
import '../../audio/audio_route_observer.dart';
import '../../audio/sound_manager.dart';
import '../widgets/level_loading_dialog.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/win_card_dialog.dart';
import '../widgets/xp_track.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/grid_skins.dart';
import '../theme/decoration_catalog.dart';
import '../../utils/ad_manager.dart';
import '../../utils/level_share_image.dart';
import 'learning_screen.dart';
import 'settings_screen.dart';

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
  final bool dailyTimerEnabled;

  const GameScreen({
    super.key,
    required this.level,
    this.noReward = false,
    this.dailyTimerEnabled = true,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen>
    with RouteAware, WidgetsBindingObserver {
  static const int _initialLives = 3;
  static const int _dailyTimeLimitSeconds = 180;
  static const double _rewardedInterstitialAdChance = 0.4;

  late CrosswordGrid _grid;
  late final Map<(int, int), String> _pinyinByCell;
  final DistractorEngine _distractorEngine = DistractorEngine();

  int _lives = _initialLives;
  int _remainingSeconds = _dailyTimeLimitSeconds;
  Timer? _dailyTimer;
  bool _dailyRetryWithoutTimer = false;
  bool _failed = false;
  bool _revived = false;
  bool _reviveActionInProgress = false;
  bool _appIsActive = true;
  bool _routeIsVisible = true;
  Future<void> Function()? _terminalDialog;
  bool _terminalDialogVisible = false;

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

  /// 本关成语的“前后两半可交换”倒装对（word -> 交换后的词）
  final Map<String, String> _reversiblePairs = {};
  PageRoute<dynamic>? _subscribedRoute;

  // 成语释义区滚动条
  final ScrollController _completedScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appIsActive =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    MusicManager.instance.enterGame(this);
    _grid = widget.level.grid;
    _pinyinByCell = pinyinByCell(widget.level);
    _findFirstEmptyCell();
    _levelStartTime = DateTime.now();
    _correctStreak = ref.read(playerProvider).currentCorrectStreak;
    unawaited(_initializeLevel());
    // 提前预加载插页式激励广告，避免在通关后等待加载。
    if (AdManager.isSupportedPlatform) {
      unawaited(AdManager().loadRewardedInterstitialAd());
      unawaited(AdManager().loadRewardedAd());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    _routeIsVisible = true;
    _syncDailyTimer();
    MusicManager.instance.revealGame(this);
  }

  @override
  void didPushNext() {
    _routeIsVisible = false;
    _syncDailyTimer();
    unawaited(_saveState());
    MusicManager.instance.coverGame(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    if (_appIsActive == isActive) return;
    _appIsActive = isActive;
    _syncDailyTimer();
    if (!isActive) unawaited(_saveState());
  }

  /// 从数据库读取本关成语的倒装对（仅保留 ABCD ↔ CDAB 这种半句交换）
  Future<void> _loadReversiblePairs() async {
    try {
      final db = ref.read(databaseProvider);
      for (final placement in widget.level.placements) {
        final word = placement.idiom.text;
        final id = await db.findIdiomIdByWord(word);
        if (id == null) continue;
        final pair = await db.findReversibleForm(id);
        if (pair != null &&
            pair.word == _swapHalves(word) &&
            !_reversiblePairs.containsKey(word)) {
          _reversiblePairs[word] = pair.word;
        }
      }
    } catch (_) {
      // 倒装信息加载失败时按普通成语处理
    }
  }

  String _swapHalves(String word) =>
      word.length == 4 ? word.substring(2) + word.substring(0, 2) : word;

  Future<void> _initializeLevel() async {
    await ref.read(hapticEnabledProvider.future);
    await _buildCandidateBoard();
    if (!mounted) return;
    await _loadReversiblePairs();
    await _restoreSavedState();
    await _configureDailyTimer();
  }

  /// 构建候选字盘
  Future<void> _buildCandidateBoard() async {
    // 按格子收集正确答案，交叉格只计一次，避免候选字数量超过实际需填字数
    final correctCells = <(int, int), String>{};
    for (final placement in widget.level.placements) {
      for (int k = 0; k < placement.idiom.text.length; k++) {
        final (r, c) = placement.cellAt(k);
        if (!widget.level.grid.cellAt(r, c).isGiven) {
          correctCells[(r, c)] = placement.idiom.text[k];
        }
      }
    }
    final correctAnswers = correctCells.values.toList();
    Map<String, List<String>> databaseCandidates = {};
    List<String> dictionaryWords = const [];
    Map<String, Set<String>> allowedAlternatives = const {};
    final db = ref.read(databaseProvider);
    try {
      databaseCandidates = await db.findSimilarCharsFor(correctAnswers);
    } catch (_) {
      // 相关字数据不可用时仍可使用内置候选表生成关卡。
    }
    try {
      dictionaryWords = await db.findIdiomWordsMatchingPatterns(
        candidatePatternsForLevel(widget.level),
      );
      allowedAlternatives = await db.findReversibleWordsFor(
        widget.level.idioms.map((idiom) => idiom.text),
      );
    } catch (_) {
      // 成语查询失败时不阻塞候选盘构建。
    }
    if (!mounted) return;

    final excludedDistractors = <String>{};
    while (true) {
      _candidateBoard = _distractorEngine.generateCandidateBoard(
        correctAnswers: correctAnswers,
        rows: 4,
        countPerRow: 10,
        randomRotationKey: widget.level.levelId,
        databaseRelatedCandidates: databaseCandidates,
        excludeDistractorChars: excludedDistractors,
      );
      final ambiguities = findCandidateAmbiguities(
        level: widget.level,
        dictionaryWords: dictionaryWords,
        availableChars: _candidateBoard.expand((row) => row),
        allowedAlternatives: allowedAlternatives,
      );
      final newlyExcluded = distractorCharsToExclude(
        ambiguities,
        correctAnswers.toSet(),
      )..removeAll(excludedDistractors);
      if (ambiguities.isEmpty || newlyExcluded.isEmpty) break;
      excludedDistractors.addAll(newlyExcluded);
    }
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
        _wrongIdiomWords.addAll(state.wrongIdiomWords);
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
    if (_wrongIdiomWords.isNotEmpty) return;
    _wrongIdiomWords.clear();
    for (final entry in _fillHistory) {
      if (entry.candRow < 0 ||
          entry.candCol < 0 ||
          entry.candRow >= _candidateBoard.length ||
          entry.candCol >= _candidateBoard[entry.candRow].length) {
        continue;
      }
      final filledChar = _candidateBoard[entry.candRow][entry.candCol];
      if (!_isCharCorrectForCell(entry.row, entry.col, filledChar)) {
        final placement = _placementsContaining(
          entry.row,
          entry.col,
        ).firstOrNull;
        if (placement != null) _wrongIdiomWords.add(placement.idiom.text);
      }
    }
  }

  /// 根据当前答案重建派生状态（错误格、完成格、完成成语列表）
  void _recomputeDerivedState() {
    _errorCells.clear();
    _completedCells.clear();
    _completedIdiomList.clear();
    _selectedCompletedIndex = null;
    final usedAnswers = <String>{};

    for (final placement in widget.level.placements) {
      var allFilled = true;
      for (int k = 0; k < placement.idiom.text.length; k++) {
        final (r, c) = placement.cellAt(k);
        if (_grid.cellAt(r, c).isGiven) continue;
        final filled = _playerAnswers[(r, c)];
        if (filled == null) {
          allFilled = false;
        }
      }
      final completedIdiom = allFilled
          ? widget.level.completedIdiomFor(placement, _playerAnswers)
          : null;
      if (completedIdiom != null && usedAnswers.add(completedIdiom.text)) {
        for (int k = 0; k < placement.idiom.text.length; k++) {
          final (r, c) = placement.cellAt(k);
          if (!_grid.cellAt(r, c).isGiven) {
            _completedCells.add((r, c));
          }
        }
        _completedIdiomList.add((
          word: completedIdiom.text,
          meaning: completedIdiom.meaning,
        ));
      } else if (allFilled) {
        for (int k = 0; k < placement.idiom.text.length; k++) {
          final (r, c) = placement.cellAt(k);
          if (!_grid.cellAt(r, c).isGiven) _errorCells.add((r, c));
        }
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
            wrongIdiomWords: Set.from(_wrongIdiomWords),
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
    var isNew = false;
    try {
      isNew = await ref.read(playerProvider.notifier).unlockAchievement(id);
    } catch (_) {
      return;
    }
    if (!mounted || !isNew) return;
    final def = achievementDefFor(id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('解锁成就：${def.title}，获得 ${def.points} 积分'),
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
    WidgetsBinding.instance.removeObserver(this);
    appRouteObserver.unsubscribe(this);
    _subscribedRoute = null;
    MusicManager.instance.exitGame(this);
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

  Placement? _activePlacementForCell(int row, int col) {
    final placements = _placementsContaining(row, col);
    if (placements.isEmpty) return null;
    for (final placement in placements) {
      if (placement.direction == _currentDirection) return placement;
    }
    return placements.first;
  }

  void _markActiveIdiomWrong(int row, int col) {
    final placement = _activePlacementForCell(row, col);
    if (placement != null) _wrongIdiomWords.add(placement.idiom.text);
  }

  /// 该成语是否属于“ABCD ↔ CDAB”半句交换，且当前提示/交叉条件允许两种顺序
  bool _isHalfSwapAmbiguous(Placement p) {
    final pair = _reversiblePairs[p.idiom.text];
    if (pair == null) return false;
    final swapPositions = <int>[];
    for (var k = 0; k < 4; k++) {
      final (r, c) = p.cellAt(k);
      final cell = _grid.cellAt(r, c);
      if (p.idiom.text[k] != pair[k]) {
        swapPositions.add(k);
        // 交换位不能是交叉点，也不能已被提示
        if (cell.isIntersection || cell.isGiven) return false;
      }
    }
    // 只有 ABAC / BACA 这种“一对共享位 + 一对交换位”才成立
    if (swapPositions.length != 2) return false;
    // 必须至少有一个共享位提示字（如 A），否则纯 ABCD ↔ CDAB 不适用
    var hasSharedClue = false;
    for (var k = 0; k < 4; k++) {
      if (p.idiom.text[k] == pair[k]) {
        final (r, c) = p.cellAt(k);
        if (_grid.cellAt(r, c).isGiven) hasSharedClue = true;
      }
    }
    return hasSharedClue;
  }

  /// 某格当前允许的字符集合；半句交换时随已填的另一格动态收窄
  Set<String> _allowedCharsForCell(int row, int col) {
    final placements = _placementsContaining(row, col);
    if (placements.any(widget.level.isInterchangeablePlacement)) {
      return widget.level.allowedCharactersAt(row, col, _playerAnswers);
    }

    final allowed = <String>{};
    for (final p in placements) {
      if (!_isHalfSwapAmbiguous(p)) continue;
      final k = p.cells.indexOf((row, col));
      final word = p.idiom.text;
      final pair = _reversiblePairs[word]!;
      final swapPositions = <int>[
        for (var i = 0; i < 4; i++)
          if (word[i] != pair[i]) i,
      ];
      if (swapPositions.length != 2 ||
          (k != swapPositions[0] && k != swapPositions[1])) {
        continue;
      }
      final s0 = swapPositions[0];
      final s1 = swapPositions[1];
      final cell0 = p.cellAt(s0);
      final cell1 = p.cellAt(s1);
      final ans0 = _playerAnswers[cell0];
      final ans1 = _playerAnswers[cell1];

      // 先填了其中一个交换位：另一个必须是对应顺序的字
      if ((row, col) == cell1) {
        if (ans0 == word[s0]) return {word[s1]};
        if (ans0 == pair[s0]) return {pair[s1]};
      }
      if ((row, col) == cell0) {
        if (ans1 == word[s1]) return {word[s0]};
        if (ans1 == pair[s1]) return {pair[s0]};
      }
      allowed.add(word[k]);
      allowed.add(pair[k]);
    }
    if (allowed.isNotEmpty) return allowed;
    final exact = _correctCharForCell(row, col);
    return exact == null ? <String>{} : {exact};
  }

  bool _isCharCorrectForCell(int row, int col, String char) {
    return _allowedCharsForCell(row, col).contains(char);
  }

  /// (row, col) 的正确字（该格可能属于多个成语，答案一致）
  String? _correctCharForCell(int row, int col) {
    for (final placement in _placementsContaining(row, col)) {
      return placement.idiom.text[placement.cells.indexOf((row, col))];
    }
    return null;
  }

  void _triggerHaptic(Future<void> Function() feedback) {
    if (ref.read(hapticEnabledProvider).value == true) {
      unawaited(feedback());
    }
  }

  /// 玩家点击候选字
  void _onCandidateTap(int row, int col, String char) {
    if (_focusRow < 0 || _focusCol < 0) return;
    if (_completedCells.contains((_focusRow, _focusCol))) return;

    final cell = _grid.cellAt(_focusRow, _focusCol);
    if (cell.isGiven) return;

    final filledRow = _focusRow;
    final filledCol = _focusCol;
    final isCorrect = _isCharCorrectForCell(filledRow, filledCol, char);
    final shouldFail = !isCorrect && _lives == 0;
    _totalFills++; // 本关填字尝试次数（含错误字），提示填入不计
    if (isCorrect) {
      _correctStreak++;
      ref.read(playerProvider.notifier).recordCorrectFill();
      for (final id in AchievementManager.evaluateStreak(
        alreadyUnlocked: _streakHandled,
        streak: _correctStreak,
      )) {
        if (!_streakHandled.contains(id)) {
          _streakHandled.add(id);
          _unlockAndNotify(id);
        }
      }
    } else {
      _errorsMade++;
      _lives = max(0, _lives - 1);
      _correctStreak = 0;
      _markActiveIdiomWrong(filledRow, filledCol);
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

    if (shouldFail) {
      unawaited(_failLevel());
      return;
    }

    if (isCorrect && idiomCompleted) {
      _triggerHaptic(HapticFeedback.mediumImpact);
      SoundManager.instance.playIdiom();
      _scrollCompletedIdiomsToEnd();
    } else {
      _triggerHaptic(HapticFeedback.lightImpact);
      if (isCorrect) {
        SoundManager.instance.playCorrect();
      } else {
        SoundManager.instance.playWrong();
      }
    }
    _moveToNextEmptyCell();
    if (isCorrect) _flashCellAt(filledRow, filledCol);
    _saveState();
  }

  void _scrollCompletedIdiomsToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_completedScrollController.hasClients) return;
      _completedScrollController.animateTo(
        _completedScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
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
      } else if (!_isCharCorrectForCell(r, c, filled)) {
        allCorrect = false;
        _errorCells.add((r, c));
      }
    }

    var completedIdiom = allFilled && allCorrect
        ? widget.level.completedIdiomFor(placement, _playerAnswers)
        : null;
    // 保留数据库登记的“半句互换”旧规则。
    if (completedIdiom == null && allFilled && allCorrect) {
      completedIdiom = placement.idiom;
    }
    if (completedIdiom == null) return false;
    final resolvedIdiom = completedIdiom;
    if (_completedIdiomList.any((item) => item.word == resolvedIdiom.text)) {
      return false;
    }

    // 成语完成
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('√ ${resolvedIdiom.text}'),
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
      word: resolvedIdiom.text,
      meaning: resolvedIdiom.meaning,
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
    final preferredDirection =
        _directionFromFilledPrefix(
          containingPlacements.map((item) => item.$1),
        ) ??
        _currentDirection;

    // 交叉点优先沿前方已有字的方向，否则沿当前方向继续
    if (preferredDirection != null) {
      for (final (placement, k) in containingPlacements) {
        if (placement.direction == preferredDirection) {
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
                _currentDirection = placement.direction;
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
      if (placement.direction == preferredDirection) continue;

      for (int next = 0; next < placement.idiom.text.length; next++) {
        if (next == k) continue;
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

  Direction? _directionFromFilledPrefix(Iterable<Placement> placements) {
    final crossingPlacements = placements.toList();
    if (crossingPlacements.length < 2) return null;

    Direction? preferred;
    var mostFilled = 0;
    var tied = false;
    for (final placement in crossingPlacements) {
      final current = placement.cells.indexOf((_focusRow, _focusCol));
      final hasEmptyAfter = placement.cells.skip(current + 1).any((position) {
        final cell = _grid.cellAt(position.$1, position.$2);
        return !cell.isGiven && !_playerAnswers.containsKey(position);
      });
      if (!hasEmptyAfter) continue;

      var filledBefore = 0;
      for (var previous = current - 1; previous >= 0; previous--) {
        final position = placement.cellAt(previous);
        final cell = _grid.cellAt(position.$1, position.$2);
        if (!cell.isGiven && !_playerAnswers.containsKey(position)) break;
        filledBefore++;
      }

      if (filledBefore > mostFilled) {
        preferred = placement.direction;
        mostFilled = filledBefore;
        tied = false;
      } else if (filledBefore == mostFilled && filledBefore > 0) {
        tied = true;
      }
    }
    return tied ? null : preferred;
  }

  /// 检查整关是否完成
  void _checkLevelComplete() {
    final hasInterchangeableAnswers = widget.level.hasInterchangeableAnswers;
    var allDone = hasInterchangeableAnswers
        ? widget.level.matchesAnswers(_playerAnswers)
        : true;
    if (!hasInterchangeableAnswers) {
      for (final placement in widget.level.placements) {
        for (int k = 0; k < placement.idiom.text.length; k++) {
          final (r, c) = placement.cellAt(k);
          if (!_grid.cellAt(r, c).isGiven) {
            final filled = _playerAnswers[(r, c)];
            if (filled == null || !_isCharCorrectForCell(r, c, filled)) {
              allDone = false;
              break;
            }
          }
        }
      }
    }
    if (allDone) {
      _triggerHaptic(HapticFeedback.heavyImpact);
      SoundManager.instance.playComplete();
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
    if (_isDaily) ref.invalidate(dailyDoneProvider);
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
    var dailyCompletions = 0;
    for (final h in await db.getLevelHistory()) {
      if (h.hintsUsed == 0) noHintCompletions++;
      if (h.errorsMade == 0) flawlessCompletions++;
      if (h.levelNumber >= dailyLevelOffset) dailyCompletions++;
    }
    final newly = AchievementManager.evaluateOnLevelComplete(
      alreadyUnlocked: alreadyUnlocked,
      totalCompleted: ref.read(playerProvider).completedLevels,
      noHintCompletions: noHintCompletions,
      flawlessCompletions: flawlessCompletions,
      dailyCompletions: dailyCompletions,
      totalXp: ref.read(playerProvider).totalXp,
      collectionCount: await db.getCollectionCount(),
    );
    final unlockedNow = <AchievementId>[];
    for (final id in newly) {
      if (await ref.read(playerProvider.notifier).unlockAchievement(id)) {
        unlockedNow.add(id);
      }
    }
    final newDefs = achievementDefs
        .where((definition) => unlockedNow.contains(definition.id))
        .toList();

    await db.clearLevelState(widget.level.levelId);
    _levelFinished = true;
    if (_isDaily) await _promptDailyReminderIfNeeded();
    if (!mounted) return;
    // Game Center 网络调用不能阻塞本地通关结算。
    unawaited(
      LeaderboardService.submitScores(db, ref.read(playerProvider).totalXp),
    );

    await _promptForReviewIfNeeded();
    if (!mounted) return;

    await _maybeShowRewardedInterstitial(() {
      if (!mounted) return;
      _showSettlement(result, newDefs, timeSpentMs);
    });
  }

  Future<void> _promptForReviewIfNeeded() async {
    final manager = AppReviewPromptManager(ref.read(databaseProvider));
    if (!await manager.shouldPrompt(
          completedLevels: ref.read(playerProvider).completedLevels,
        ) ||
        !mounted) {
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ThemeDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '喜欢《成语接龙》吗？',
              style: displayStyle(size: 20, weight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              '您的评价对我们至关重要，会帮助我们把游戏做得更好。',
              style: bodyStyle(size: 13.5, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: '暂不评价',
                    small: true,
                    ghost: true,
                    onTap: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: '去评价',
                    small: true,
                    onTap: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (accepted == true) {
      await manager.markReviewRequested();
      try {
        await ref.read(appReviewPlatformProvider).requestReview();
      } catch (_) {
        // 系统评分服务不可用时不应阻断通关结算。
      }
    } else {
      await manager.markDeclined();
    }
  }

  Future<void> _promptDailyReminderIfNeeded() async {
    await ref.read(dailyReminderProvider.future);
    final notifier = ref.read(dailyReminderProvider.notifier);
    if (!await notifier.unlockAndMarkPrompted() || !mounted) return;
    final requestPermission = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ThemeDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '开启每日挑战提醒',
              style: displayStyle(size: 20, weight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              '允许通知后，会默认在每天中午 12:00 提醒您。您可以随时在“我的 → 设置”中修改时间或关闭提醒。',
              style: bodyStyle(size: 13.5, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: '暂不开启',
                    small: true,
                    ghost: true,
                    onTap: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: '继续',
                    small: true,
                    onTap: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (requestPermission == true) {
      try {
        await notifier.requestPermissionAndEnable();
      } catch (_) {
        // 通知授权或调度失败不应阻断每日挑战结算。
      }
    }
  }

  /// 胜利结算前有 40% 概率询问是否观看插页式激励广告。
  Future<void> _maybeShowRewardedInterstitial(VoidCallback onDone) async {
    final adManager = AdManager();
    if (widget.level.levelId <= 5 || // 教学关 1-5 不提供插页式激励广告
        !AdManager.isSupportedPlatform ||
        Random().nextDouble() >= _rewardedInterstitialAdChance) {
      onDone();
      return;
    }
    if (!adManager.isRewardedInterstitialAdReady) {
      unawaited(adManager.loadRewardedInterstitialAd());
      onDone();
      return;
    }
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ThemeDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '观看广告领奖励',
              style: displayStyle(size: 20, weight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(
              '观看完整的插页式激励广告，可获得 '
              '$kRewardedInterstitialAdPointsReward 积分。你也可以跳过，通关结算不受影响。',
              style: bodyStyle(size: 13.5, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: '跳过',
                    small: true,
                    ghost: true,
                    onTap: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: '观看广告',
                    small: true,
                    onTap: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (accepted != true) {
      onDone();
      return;
    }

    var rewardGranted = false;
    final shown = adManager.showRewardedInterstitialAd(
      onRewardEarned: (_, _) {
        if (rewardGranted) return;
        rewardGranted = true;
        unawaited(
          ref
              .read(playerProvider.notifier)
              .addPoints(kRewardedInterstitialAdPointsReward),
        );
      },
      onAdClosed: () {
        onDone();
      },
    );
    if (!shown) {
      // 广告状态在确认期间发生变化时，直接继续结算且不发奖励。
      unawaited(adManager.loadRewardedInterstitialAd());
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
    final wrongIdiomCount = _wrongIdiomWords.length;
    final wrongIdioms = _completedIdiomList
        .where((i) => _wrongIdiomWords.contains(i.word))
        .take(3)
        .map((i) => (word: i.word, meaning: i.meaning))
        .toList();
    _showTerminalDialog(
      () => showWinCardDialog(
        context,
        seal: '通',
        title: _isDaily ? '每日挑战 · 完成' : '恭喜通过 · ${widget.level.title}',
        subtitle:
            '用时 ${_formatDuration(timeSpentMs)}${wrongIdiomCount == 0 ? '' : ' · 填错 $wrongIdiomCount'}',
        xpText: xpText,
        idioms: wrongIdioms,
        dismissible: true,
        actions: [
          if (!_isDaily)
            WinCardAction(
              label: '下一关',
              primary: true,
              onTap: () {
                _clearTerminalDialog();
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
              _clearTerminalDialog();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }

  /// 打开本关成语学习页（释义/出处/例句）
  void _showLearning(BuildContext dialogContext) {
    Navigator.of(dialogContext).push(
      AppPageRoute<void>(
        builder: (_) => LearningScreen(
          words: widget.level.idioms.map((i) => i.text).toList(),
          wrongWords: Set.from(_wrongIdiomWords),
        ),
      ),
    );
  }

  /// 每日挑战关卡（专用关卡号段）
  bool get _isDaily => widget.level.levelId >= dailyLevelOffset;

  bool get _usesDailyTimer =>
      _isDaily && widget.dailyTimerEnabled && !_dailyRetryWithoutTimer;

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
    _showTerminalDialog(
      () => showWinCardDialog(
        context,
        seal: '通',
        title: '本关已完成',
        subtitle: '重玩关卡不重复发放经验与收藏。',
        xpText: '+0',
        dismissible: true,
        actions: [
          WinCardAction(
            label: '返回',
            ghost: true,
            onTap: () {
              _clearTerminalDialog();
              Navigator.of(context).pop();
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showTerminalDialog(Future<void> Function() dialog) async {
    _terminalDialog = dialog;
    if (_terminalDialogVisible || !mounted) return;
    setState(() => _terminalDialogVisible = true);
    await dialog();
    if (mounted && _terminalDialog != null) {
      setState(() => _terminalDialogVisible = false);
    }
  }

  void _clearTerminalDialog() {
    _terminalDialog = null;
    _terminalDialogVisible = false;
  }

  void _reopenTerminalDialog() {
    final dialog = _terminalDialog;
    if (dialog != null) unawaited(_showTerminalDialog(dialog));
  }

  void _startDailyTimer() {
    if (_dailyTimer?.isActive == true) return;
    _dailyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_shouldRunDailyTimer) {
        timer.cancel();
        _dailyTimer = null;
        return;
      }
      setState(() {
        if (_remainingSeconds > 0) _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        unawaited(_failLevel(timeUp: true));
      }
    });
  }

  bool get _shouldRunDailyTimer =>
      _usesDailyTimer &&
      _appIsActive &&
      _routeIsVisible &&
      !_restoring &&
      !_failed &&
      !_levelFinished &&
      _remainingSeconds > 0;

  void _syncDailyTimer() {
    if (_shouldRunDailyTimer) {
      _startDailyTimer();
    } else {
      _dailyTimer?.cancel();
      _dailyTimer = null;
    }
  }

  Future<void> _configureDailyTimer() async {
    if (!_isDaily || !widget.dailyTimerEnabled) return;
    var failedBefore = false;
    try {
      failedBefore =
          await ref.read(databaseProvider).getSetting(_dailyNoRewardKey()) ==
          'true';
    } catch (_) {}
    if (!mounted) return;
    if (failedBefore && !_revived) {
      setState(() => _dailyRetryWithoutTimer = true);
    } else {
      _syncDailyTimer();
    }
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
      await ref.read(databaseProvider).setSetting(_dailyNoRewardKey(), 'true');
      if (!mounted) return;
    }
    _showTerminalDialog(() => _showFailureDialog(timeUp: timeUp));
  }

  Future<void> _showFailureDialog({required bool timeUp}) async {
    final quota = await ref.read(playerProvider.notifier).dailyReviveQuota();
    if (!mounted) return;
    final reviveCount =
        ref.read(playerProvider).functionalItems['revive_card'] ?? 0;
    final adManager = AdManager();
    if (quota.adRemaining > 0 &&
        !adManager.isRewardedAdReadyNotifier.value &&
        AdManager.isSupportedPlatform) {
      unawaited(adManager.loadRewardedAd());
    }
    return showWinCardDialog(
      context,
      seal: '败',
      title: '挑战失败',
      subtitle: _isDaily ? (timeUp ? '倒计时结束' : '生命值耗尽') : '生命值耗尽',
      xpText: null,
      dismissible: true,
      actions: [
        WinCardAction(
          label: '看广告复活(${quota.adRemaining})',
          primary: true,
          onTap: quota.adRemaining > 0 ? _handleAdRevive : null,
          enabledListenable: quota.adRemaining > 0
              ? adManager.isRewardedAdReadyNotifier
              : null,
          disabledLabel: '看广告复活(加载中)',
        ),
        WinCardAction(
          label: '分享后复活(${quota.shareRemaining})',
          primary: true,
          onTap: quota.shareRemaining > 0 ? _handleShareRevive : null,
        ),
        WinCardAction(
          label: '使用复活卡($reviveCount)',
          primary: true,
          onTap: _handleCardRevive,
        ),
      ],
      inlineActions: [
        WinCardAction(
          label: _isDaily ? '重玩本关（无经验）' : '重玩本关',
          ghost: true,
          onTap: _replayLevel,
        ),
        WinCardAction(
          label: '返回主页',
          ghost: true,
          onTap: () {
            _clearTerminalDialog();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ],
    );
  }

  Future<void> _handleAdRevive() async {
    if (_reviveActionInProgress) return;
    final notifier = ref.read(playerProvider.notifier);
    final quota = await notifier.dailyReviveQuota();
    if (quota.adRemaining <= 0 || !mounted) return;
    _reviveActionInProgress = true;
    final adManager = AdManager();
    final ready =
        adManager.isRewardedAdReadyNotifier.value ||
        await adManager.loadRewardedAd();
    if (!mounted) return;
    if (!ready) {
      _reviveActionInProgress = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('广告暂未就绪，请稍后重试'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    var rewarded = false;
    var adClosed = false;
    var reviveConsumed = false;
    var resumeStarted = false;
    void resumeIfReady() {
      if (!adClosed || !reviveConsumed || resumeStarted || !mounted) return;
      resumeStarted = true;
      unawaited(_resumeAfterRevive());
    }

    final shown = adManager.showRewardedAd(
      onAdClosed: () {
        adClosed = true;
        if (!rewarded) _reviveActionInProgress = false;
        resumeIfReady();
      },
      onRewardEarned: (_, _) {
        if (rewarded) return;
        rewarded = true;
        unawaited(() async {
          final consumed = await notifier.consumeDailyRevive(
            DailyReviveMethod.ad,
          );
          if (!mounted) return;
          reviveConsumed = consumed;
          if (!consumed) _reviveActionInProgress = false;
          resumeIfReady();
        }());
      },
    );
    if (!shown && mounted) {
      _reviveActionInProgress = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('广告暂未就绪，请稍后重试'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleShareRevive() async {
    if (_reviveActionInProgress) return;
    final notifier = ref.read(playerProvider.notifier);
    final quota = await notifier.dailyReviveQuota();
    if (quota.shareRemaining <= 0 || !mounted) return;
    _reviveActionInProgress = true;
    try {
      final qrData = await rootBundle.load('assets/images/qrcode.png');
      final imageBytes = await buildLevelShareImage(
        level: widget.level,
        qrCodeBytes: qrData.buffer.asUint8List(
          qrData.offsetInBytes,
          qrData.lengthInBytes,
        ),
      );
      if (!mounted) return;
      final result = await SharePlus.instance.share(
        ShareParams(
          title: kLevelShareTitle,
          subject: kLevelShareTitle,
          text: kLevelShareTitle,
          files: [XFile.fromData(imageBytes, mimeType: 'image/png')],
          fileNameOverrides: [
            'idiom-crossword-level-${widget.level.levelId}.png',
          ],
          sharePositionOrigin: Offset.zero & MediaQuery.sizeOf(context),
        ),
      );
      if (!mounted) return;
      if (result.status == ShareResultStatus.success) {
        final consumed = await notifier.consumeDailyRevive(
          DailyReviveMethod.share,
        );
        if (mounted && consumed) await _resumeAfterRevive();
      } else if (result.status == ShareResultStatus.unavailable && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('当前平台无法确认分享结果'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('分享失败，请稍后重试'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _reviveActionInProgress = false;
    }
  }

  Future<void> _handleCardRevive() async {
    final reviveCount =
        ref.read(playerProvider).functionalItems['revive_card'] ?? 0;
    if (reviveCount <= 0) {
      _showRevivePurchaseDialog();
      return;
    }
    await ref.read(playerProvider.notifier).useReviveCard();
    if (!mounted) return;
    await _resumeAfterRevive();
  }

  Future<void> _resumeAfterRevive() async {
    if (!mounted) return;
    _reviveActionInProgress = false;
    _clearTerminalDialog();
    Navigator.of(context).pop(); // 关闭失败弹框
    setState(() {
      _lives = _initialLives;
      _remainingSeconds = _dailyTimeLimitSeconds;
      _failed = false;
      _revived = true;
      _clearWrongAnswers();
    });
    _syncDailyTimer();
    await _saveState();
    if (_isDaily) {
      try {
        await ref
            .read(databaseProvider)
            .setSetting(_dailyNoRewardKey(), 'false');
      } catch (_) {}
    }
  }

  Future<void> _replayLevel() async {
    try {
      await ref.read(databaseProvider).clearLevelState(widget.level.levelId);
    } catch (_) {}
    if (!mounted) return;
    _clearTerminalDialog();
    Navigator.of(context).pop(); // 关闭失败弹框
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      AppPageRoute<void>(
        builder: (_) => GameScreen(
          level: widget.level,
          noReward: _isDaily,
          dailyTimerEnabled: !_isDaily,
        ),
      ),
    );
  }

  void _clearWrongAnswers() {
    final wrongCells = <(int, int)>{};
    for (final entry in _playerAnswers.entries) {
      if (!_isCharCorrectForCell(entry.key.$1, entry.key.$2, entry.value)) {
        wrongCells.add(entry.key);
      }
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

  void _showHintPurchaseDialog() {
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
                      child: AppIcon('hint', size: 28, color: AppColors.accent),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '提示卡 ×1',
                          style: bodyStyle(size: 15, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '揭示当前选中格子的正确答案',
                          style: bodyStyle(size: 11.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$kHintCardPoints 积分',
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
                  final ok = await notifier.spendPoints(kHintCardPoints);
                  if (!ok) {
                    if (!ctx.mounted || !mounted) return;
                    Navigator.of(ctx).pop();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('积分不足，可观看广告赚取积分'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                    return;
                  }
                  await notifier.addHintCards(1);
                  if (!ctx.mounted || !mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  await _showHint();
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
                      const SnackBar(
                        content: Text('积分不足，可观看广告赚取积分'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                    return;
                  }
                  await notifier.addReviveCards(1);
                  if (!ctx.mounted || !mounted) return;
                  Navigator.of(ctx).pop();
                  if (!mounted) return;
                  await _handleCardRevive();
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
    var loadingOpen = true;
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
      loadingOpen = false;
      if (level == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('下一关生成失败，请重试'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
      Navigator.pushReplacement(
        context,
        AppPageRoute<void>(builder: (_) => GameScreen(level: level)),
      );
    } catch (e) {
      if (mounted) {
        if (loadingOpen) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('错误: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
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
    _triggerHaptic(HapticFeedback.selectionClick);
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
    final activeBackground = ref.watch(playerProvider).activeBackground;
    final terminal = _failed || _levelFinished;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              backgroundAsset(activeBackground),
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: _restoring
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _buildTopBar(),
                      Expanded(
                        child: Column(
                          children: [
                            _terminalTapRegion(
                              terminal: terminal,
                              child: _buildProgress(),
                            ),
                            _buildCompletedIdiomsSection(),
                            Expanded(
                              flex: 7,
                              child: _terminalTapRegion(
                                terminal: terminal,
                                child: _buildGrid(),
                              ),
                            ),
                            _terminalTapRegion(
                              terminal: terminal,
                              child: _buildStatusLine(),
                            ),
                            Expanded(
                              flex: 3,
                              child: _terminalTapRegion(
                                terminal: terminal,
                                child: _buildCandidateBoardWidget(),
                              ),
                            ),
                            _terminalTapRegion(
                              terminal: terminal,
                              child: _buildToolbar(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _terminalTapRegion({required bool terminal, required Widget child}) {
    if (!terminal) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _reopenTerminalDialog,
      child: IgnorePointer(child: child),
    );
  }

  /// 顶栏：返回 + 关卡标题 + 徽章 + 声音开关
  Widget _buildTopBar() {
    final soundEnabled =
        ref.watch(soundEnabledProvider).value ?? SoundManager.instance.enabled;
    final musicEnabled =
        ref.watch(musicEnabledProvider).value ??
        MusicManager.instance.musicEnabled;
    final audioEnabled = soundEnabled && musicEnabled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          _buildExitButton(),
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
            onTap: () async {
              final enabled = !audioEnabled;
              await Future.wait([
                ref.read(soundEnabledProvider.notifier).setEnabled(enabled),
                ref.read(musicEnabledProvider.notifier).setEnabled(enabled),
              ]);
            },
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
                  opacity: audioEnabled ? 1 : 0.4,
                  child: const AppIcon('sound', size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExitButton() {
    return GestureDetector(
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
    );
  }

  /// 本关进度：N/总字数 + XpTrack
  Widget _buildProgress() {
    final total = _blankCount();
    final filled = _playerAnswers.entries.where((entry) {
      final (row, col) = entry.key;
      return _isCharCorrectForCell(row, col, entry.value);
    }).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
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
          final showPinyin = ref.watch(showPinyinProvider).value ?? true;
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
                      showPinyin: showPinyin,
                      pinyinByCell: _pinyinByCell,
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
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: _completedIdiomList.isEmpty
          ? const SizedBox.shrink()
          : SizedBox(
              width: double.infinity,
              child: AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 30,
                      child: SizedBox(
                        width: double.infinity,
                        child: SingleChildScrollView(
                          controller: _completedScrollController,
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
                                      horizontal: 6,
                                      vertical: 2,
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
                                        size: 15,
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
                            padding: const EdgeInsets.only(top: 2),
                            child: AutoSizeText(
                              '释义：'
                              '${_completedIdiomList[_selectedCompletedIndex!].meaning}',
                              maxLines: 2,
                              minFontSize: 8,
                              overflow: TextOverflow.ellipsis,
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
              padding: const EdgeInsets.symmetric(vertical: 1),
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
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: isUsed
                          ? null
                          : () => _onCandidateTap(rowIndex, colIndex, char),
                      child: Container(
                        width: 36,
                        height: 36,
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
                            size: 21,
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
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _initialLives; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    i < _lives ? Icons.favorite : Icons.favorite_border,
                    key: ValueKey('life-heart-$i'),
                    size: 22,
                    color: i < _lives ? AppColors.accent : AppColors.faint,
                  ),
                ),
            ],
          ),
          if (_usesDailyTimer) ...[
            const SizedBox(width: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.goldSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.gold),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 20,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _countdownText,
                    style: bodyStyle(
                      size: 17,
                      weight: FontWeight.w900,
                      color: AppColors.fg,
                    ),
                  ),
                ],
              ),
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
    final canSingleHint = focusReady;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 0),
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
          _ToolbarButton(
            icon: 'clear',
            label: '清空',
            onTap: _clearIncompleteAnswers,
          ),
        ],
      ),
    );
  }

  bool _hasCorrectAnswer() {
    if (_focusRow < 0 || _focusCol < 0) return false;
    final answer = _playerAnswers[(_focusRow, _focusCol)];
    return answer != null &&
        _isCharCorrectForCell(_focusRow, _focusCol, answer);
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
    final allowed = _allowedCharsForCell(_focusRow, _focusCol);
    final correctChar = allowed.length == 1
        ? allowed.first
        : _correctCharForCell(_focusRow, _focusCol);
    if (correctChar == null ||
        _playerAnswers[(_focusRow, _focusCol)] == correctChar) {
      return;
    }

    final hintCards =
        ref.read(playerProvider).functionalItems['hint_card'] ?? 0;
    if (hintCards <= 0) {
      _showHintPurchaseDialog();
      return;
    }
    await ref.read(playerProvider.notifier).useHintCard();
    _hintUsesThisLevel++;
    _markActiveIdiomWrong(_focusRow, _focusCol);

    var idiomCompleted = false;
    setState(() {
      _applyAnswer(_focusRow, _focusCol, correctChar);
      idiomCompleted = _checkCompletionForCurrentIdiom();
    });

    if (idiomCompleted) {
      _triggerHaptic(HapticFeedback.mediumImpact);
      SoundManager.instance.playIdiom();
    } else {
      _triggerHaptic(HapticFeedback.lightImpact);
      SoundManager.instance.playFill();
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

  void _clearIncompleteAnswers() {
    final cellsToClear = _playerAnswers.keys
        .where((cell) => !_completedCells.contains(cell))
        .toSet();
    if (cellsToClear.isEmpty) return;

    setState(() {
      for (final cell in cellsToClear) {
        _playerAnswers.remove(cell);
        _errorCells.remove(cell);
        final candidateSlot = _cellToCandidateSlot.remove(cell);
        if (candidateSlot != null) {
          _usedCandidateSlots.remove(candidateSlot);
        }
      }
      _fillHistory.removeWhere(
        (entry) => cellsToClear.contains((entry.row, entry.col)),
      );
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
        height: 60,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  icon,
                  size: 24,
                  color: enabled ? AppColors.fg : AppColors.faint,
                ),
                Text(
                  label,
                  style: bodyStyle(
                    size: 12,
                    weight: FontWeight.w600,
                    color: enabled ? AppColors.fg : AppColors.faint,
                  ),
                ),
              ],
            ),
            if (sub != null)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
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
  final bool showPinyin;
  final Map<(int, int), String> pinyinByCell;
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
    required this.showPinyin,
    required this.pinyinByCell,
    required this.offset,
  });

  String? pinyinAt(int row, int col) {
    final cell = grid.cellAt(row, col);
    final displayChar = cell.isGiven
        ? cell.character
        : (playerAnswers[(row, col)] ?? '');
    if (!showPinyin || displayChar.isEmpty || displayChar != cell.character) {
      return null;
    }
    return pinyinByCell[(row, col)];
  }

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

        // 交叉格右上角朱砂小圆点，与当前是否已填字无关
        if (cell.isIntersection) {
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

        final characterPainter = TextPainter(
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
        characterPainter.layout();
        final pinyin = pinyinAt(r, c);
        final pinyinPainter = pinyin == null
            ? null
            : (TextPainter(
                text: TextSpan(
                  text: pinyin,
                  style: TextStyle(
                    fontFamily: kSans,
                    fontSize: 8.0 * (s / 48.0),
                    fontWeight: FontWeight.w500,
                    color: tentative
                        ? textColor.withValues(alpha: 0.45)
                        : textColor.withValues(alpha: 0.72),
                  ),
                ),
                textDirection: TextDirection.ltr,
              )..layout(maxWidth: s - 8));
        characterPainter.paint(
          canvas,
          Offset(
            x + (s - characterPainter.width) / 2,
            y +
                (s - characterPainter.height) / 2 -
                (pinyinPainter?.height ?? 0) * 0.35,
          ),
        );
        pinyinPainter?.paint(
          canvas,
          Offset(
            x + (s - pinyinPainter.width) / 2,
            y + s - pinyinPainter.height - 4 * (s / 48.0),
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

Map<(int, int), String> pinyinByCell(CrosswordLevel level) {
  final result = <(int, int), String>{};
  for (final placement in level.placements) {
    final syllables = placement.idiom.pinyin.trim().split(RegExp(r'\s+'));
    if (syllables.length != placement.idiom.text.length) continue;
    for (var index = 0; index < syllables.length; index++) {
      result.putIfAbsent(placement.cellAt(index), () => syllables[index]);
    }
  }
  return result;
}

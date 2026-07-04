import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/grid_engine.dart';
import '../../engine/distractor_engine.dart';
import '../widgets/level_display.dart';
import '../../state/player_state.dart';
import '../../data/growth_manager.dart';

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

  const GameScreen({super.key, required this.level});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  late CrosswordGrid _grid;
  final DistractorEngine _distractorEngine = DistractorEngine();

  // 当前焦点格子
  int _focusRow = -1;
  int _focusCol = -1;

  // 玩家填入的字（row, col) → char
  final Map<(int, int), String> _playerAnswers = {};

  // 候选字盘
  List<List<String>> _candidateBoard = [];

  // 错误提示（闪烁效果用）
  final Set<(int, int)> _errorCells = {};

  @override
  void initState() {
    super.initState();
    _grid = widget.level.grid;
    _buildCandidateBoard();
    _findFirstEmptyCell();
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
      countPerRow: 8, // iPhone 宽度可以放下 8 个
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
          return;
        }
      }
    }
  }

  /// 玩家点击候选字
  void _onCandidateTap(String char) {
    if (_focusRow < 0 || _focusCol < 0) return;

    final cell = _grid.cellAt(_focusRow, _focusCol);
    if (cell.isGiven) return;

    // 填入
    setState(() {
      _playerAnswers[(_focusRow, _focusCol)] = char;
    });

    // 检查当前成语是否完整
    _checkCompletionForCurrentIdiom();

    // 震动反馈
    HapticFeedback.lightImpact();

    // 移到下一个空白格
    _moveToNextEmptyCell();
  }

  /// 检查当前焦点所在成语的完成状态
  void _checkCompletionForCurrentIdiom() {
    // 找到包含当前格子的所有成语放置
    for (final placement in widget.level.placements) {
      for (int k = 0; k < placement.idiom.text.length; k++) {
        if (placement.cellAt(k) == (_focusRow, _focusCol)) {
          _checkIdiomCompletion(placement);
          return;
        }
      }
    }
  }

  /// 检查一个成语是否已被完整且正确地填入
  void _checkIdiomCompletion(Placement placement) {
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

    if (allFilled && allCorrect) {
      // 成语完成！
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ ${placement.idiom.text}'),
          duration: const Duration(milliseconds: 800),
        ),
      );
    } else if (allFilled && !allCorrect) {
      // 全部填了但有错（延迟清除错误标记）
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            for (final cell in _errorCells.toList()) {
              _errorCells.remove(cell);
            }
          });
        }
      });
    }
  }

  /// 自动移到下一个空白格
  void _moveToNextEmptyCell() {
    // 简单的从左到右、从上到下扫描
    for (int r = 0; r < _grid.rows; r++) {
      for (int c = 0; c < _grid.cols; c++) {
        final cell = _grid.cellAt(r, c);
        if (cell.state == CellState.filled &&
            !cell.isGiven &&
            !_playerAnswers.containsKey((r, c))) {
          setState(() {
            _focusRow = r;
            _focusCol = c;
          });
          return;
        }
      }
    }
    // 全部填完
    _focusRow = -1;
    _focusCol = -1;
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
      _onLevelComplete();
    }
  }

  /// 处理关卡完成，计算经验值并更新玩家状态
  void _onLevelComplete() async {
    final player = ref.read(playerProvider.notifier);
    final result = await player.completeLevel(
      widget.level.levelId,
      widget.level.idioms.map((i) => i.difficulty).toList(),
    );
    
    if (result.leveledUp && result.reward != null) {
      _showRewardDialog(result.newLevel, result.reward!);
    } else {
      _showCompletionDialog();
    }
  }

  /// 显示升级奖励对话框
  void _showRewardDialog(int newLevel, LevelReward reward) {
    final title = GrowthManager.titleForLevel(newLevel);
    final rewardText = reward.type == RewardType.functional
        ? '${reward.item == "hint_card" ? "提示卡" : "复活卡"} x${reward.quantity}'
        : '装饰: ${reward.item}';
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('恭喜升级！'),
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
              _showCompletionDialog();
            },
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  /// 显示过关对话框
  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('恭喜过关！'),
        content: Text('你完成了 "${widget.level.title}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('继续'),
          ),
        ],
      ),
    );
  }

  /// 点击网格中的格子切换焦点
  void _onGridTap(int row, int col) {
    final cell = _grid.cellAt(row, col);
    if (cell.state != CellState.filled || cell.isGiven) return;

    setState(() {
      _focusRow = row;
      _focusCol = col;
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
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: LevelDisplay(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 进度条
            _buildProgressBar(),

            // 填字网格（占据上半部分）
            Expanded(
              flex: 5,
              child: _buildGrid(),
            ),

            // 当前成语提示
            _buildCurrentIdiomHint(),

            // 候选字盘（下半部分）
            Expanded(
              flex: 3,
              child: _buildCandidateBoardWidget(),
            ),

            // 底部工具栏
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    int totalCells = 0;
    int filledCells = 0;
    for (int r = 0; r < _grid.rows; r++) {
      for (int c = 0; c < _grid.cols; c++) {
        final cell = _grid.cellAt(r, c);
        if (cell.state == CellState.filled && !cell.isGiven) {
          totalCells++;
          if (_playerAnswers.containsKey((r, c))) filledCells++;
        }
      }
    }
    final progress = totalCells > 0 ? filledCells / totalCells : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.brown.shade100,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.brown.shade700),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GestureDetector(
      onTapDown: (details) {
        // 计算点击在哪个格子上
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        // ... 简化处理，实际需要配合 InteractiveViewer 做坐标变换
      },
      child: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 2.0,
          child: CustomPaint(
            size: Size(
              _grid.cols * 48.0,
              _grid.rows * 48.0,
            ),
            painter: GridPainter(
              grid: _grid,
              playerAnswers: _playerAnswers,
              focusRow: _focusRow,
              focusCol: _focusCol,
              errorCells: _errorCells,
              onCellTap: _onGridTap,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentIdiomHint() {
    // 找到当前焦点所属成语的释义
    String? hint;
    if (_focusRow >= 0 && _focusCol >= 0) {
      for (final placement in widget.level.placements) {
        for (int k = 0; k < placement.idiom.text.length; k++) {
          if (placement.cellAt(k) == (_focusRow, _focusCol)) {
            hint = placement.idiom.meaning;
            break;
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        hint ?? '点击格子查看提示',
        style: TextStyle(
          fontSize: 14,
          color: Colors.brown.shade600,
          fontStyle: hint != null ? FontStyle.normal : FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildCandidateBoardWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _candidateBoard.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final row = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.asMap().entries.map((cellEntry) {
                final char = cellEntry.value;
                final isUsed = _playerAnswers.containsValue(char);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: SizedBox(
                    width: 40,
                    height: 44,
                    child: Material(
                      color: isUsed
                          ? Colors.brown.shade100
                          : Colors.brown.shade50,
                      borderRadius: BorderRadius.circular(8),
                      elevation: isUsed ? 0 : 1,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: isUsed ? null : () => _onCandidateTap(char),
                        child: Center(
                          child: Text(
                            char,
                            style: TextStyle(
                              fontSize: 22,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarButton(
            icon: Icons.undo,
            label: '撤销',
            onTap: _undo,
          ),
          _ToolbarButton(
            icon: Icons.lightbulb_outline,
            label: '提示',
            onTap: _showHint,
          ),
          _ToolbarButton(
            icon: Icons.delete_outline,
            label: '清除',
            onTap: _clearCell,
          ),
          _ToolbarButton(
            icon: Icons.refresh,
            label: '重置',
            onTap: _resetLevel,
          ),
        ],
      ),
    );
  }

  void _undo() {
    // 找到最后填入的格子并清除
    // 简化实现
    setState(() {});
  }

  void _showHint() {
    if (_focusRow < 0 || _focusCol < 0) return;
    // TODO: 逐步提示系统
  }

  void _clearCell() {
    if (_focusRow < 0 || _focusCol < 0) return;
    setState(() {
      _playerAnswers.remove((_focusRow, _focusCol));
    });
  }

  void _resetLevel() {
    setState(() {
      _playerAnswers.clear();
      _errorCells.clear();
      _findFirstEmptyCell();
    });
  }
}

/// 底部工具栏按钮
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.brown.shade700),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.brown.shade600)),
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
  final void Function(int row, int col) onCellTap;

  GridPainter({
    required this.grid,
    required this.playerAnswers,
    required this.focusRow,
    required this.focusCol,
    required this.errorCells,
    required this.onCellTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = 48.0;
    final cellPadding = 2.0;

    for (int r = 0; r < grid.rows; r++) {
      for (int c = 0; c < grid.cols; c++) {
        final cell = grid.cellAt(r, c);
        if (cell.state == CellState.blocked) continue;

        final x = c * cellSize;
        final y = r * cellSize;
        final rect = Rect.fromLTWH(
            x + cellPadding, y + cellPadding,
            cellSize - cellPadding * 2, cellSize - cellPadding * 2);

        // 背景色
        Color bgColor;
        if (cell.isGiven) {
          bgColor = const Color(0xFFD4C5B0); // 已给出的字：深米色
        } else if (errorCells.contains((r, c))) {
          bgColor = const Color(0xFFFFCDD2); // 错误：浅红
        } else if (focusRow == r && focusCol == c) {
          bgColor = const Color(0xFFFFF9C4); // 焦点：浅黄
        } else {
          bgColor = const Color(0xFFFFF8F0); // 普通：象牙白
        }

        final paint = Paint()
          ..color = bgColor
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);

        // 边框
        final borderPaint = Paint()
          ..color = (focusRow == r && focusCol == c)
              ? Colors.brown.shade700
              : Colors.brown.shade300
          ..style = PaintingStyle.stroke
          ..strokeWidth = (focusRow == r && focusCol == c) ? 2.5 : 1.0;
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(4)), borderPaint);

        // 交叉点标记
        if (cell.isIntersection) {
          final dotPaint = Paint()
            ..color = Colors.brown.shade400
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
            Offset(x + cellSize / 2, y + cellSize / 2 - 14),
            2.5,
            dotPaint,
          );
        }

        // 文字
        final displayChar = cell.isGiven 
            ? cell.character 
            : (playerAnswers[(r, c)] ?? '');
        final textPainter = TextPainter(
          text: TextSpan(
            text: displayChar,
            style: TextStyle(
              fontSize: 26,
              fontWeight: cell.isGiven ? FontWeight.w700 : FontWeight.w500,
              color: cell.isGiven
                  ? Colors.brown.shade900
                  : playerAnswers.containsKey((r, c))
                      ? Colors.brown.shade800
                      : Colors.brown.shade400,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            x + (cellSize - textPainter.width) / 2,
            y + (cellSize - textPainter.height) / 2,
          ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => true;

  @override
  bool hitTest(Offset position) {
    // 触发 onTapDown 回调需要配合 GestureDetector
    return super.hitTest(position) ?? false;
  }
}

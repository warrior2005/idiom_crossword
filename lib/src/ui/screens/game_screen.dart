import 'dart:math';

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
  Direction? _currentDirection; // 当前填字方向

  // 玩家填入的字（row, col) → char
  final Map<(int, int), String> _playerAnswers = {};

  // 候选字盘
  List<List<String>> _candidateBoard = [];

  // 已使用的候选字位置（row, col）
  final Set<(int, int)> _usedCandidateSlots = {};

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
          // 根据格子所属成语确定初始方向
          _currentDirection = _getDirectionForCell(r, c);
          return;
        }
      }
    }
  }

  /// 获取格子所属成语的方向
  Direction? _getDirectionForCell(int row, int col) {
    for (final placement in widget.level.placements) {
      for (int k = 0; k < placement.idiom.text.length; k++) {
        if (placement.cellAt(k) == (row, col)) {
          return placement.direction;
        }
      }
    }
    return null;
  }

  /// 玩家点击候选字
  void _onCandidateTap(int row, int col, String char) {
    if (_focusRow < 0 || _focusCol < 0) return;

    final cell = _grid.cellAt(_focusRow, _focusCol);
    if (cell.isGiven) return;

    // 填入
    setState(() {
      _playerAnswers[(_focusRow, _focusCol)] = char;
      _usedCandidateSlots.add((row, col));
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

  /// 自动移到下一个空白格（沿当前成语方向移动）
  void _moveToNextEmptyCell() {
    // 找到包含当前格子的所有成语
    final List<(Placement, int)> containingPlacements = [];
    for (final placement in widget.level.placements) {
      for (int k = 0; k < placement.idiom.text.length; k++) {
        if (placement.cellAt(k) == (_focusRow, _focusCol)) {
          containingPlacements.add((placement, k));
        }
      }
    }

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
    // 只能点击非 given 的格子（包括已填入和未填入的）
    if (cell.state == CellState.blocked || cell.isGiven) return;

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
                  onCellTap: _onGridTap,
                  cellSize: actualCellSize,
                ),
              ),
            ),
          ),
        );
      },
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
                final colIndex = cellEntry.key;
                final char = cellEntry.value;
                final isUsed = _usedCandidateSlots.contains((rowIndex, colIndex));
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
                        onTap: isUsed ? null : () => _onCandidateTap(rowIndex, colIndex, char),
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
  final double cellSize;

  GridPainter({
    required this.grid,
    required this.playerAnswers,
    required this.focusRow,
    required this.focusCol,
    required this.errorCells,
    required this.onCellTap,
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
            x + cellPadding, y + cellPadding,
            s - cellPadding * 2, s - cellPadding * 2);

        // 背景色
        Color bgColor;
        if (cell.isGiven) {
          bgColor = const Color(0xFFD4C5B0);
        } else if (errorCells.contains((r, c))) {
          bgColor = const Color(0xFFFFCDD2);
        } else if (focusRow == r && focusCol == c) {
          bgColor = const Color(0xFFFFF9C4);
        } else {
          bgColor = const Color(0xFFFFF8F0);
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
            Offset(x + s / 2, y + s / 2 - 14 * s / 48),
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
              fontSize: fontSize,
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

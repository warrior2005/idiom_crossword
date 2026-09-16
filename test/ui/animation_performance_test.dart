import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart';
import 'package:idiom_crossword/src/ui/app_page_route.dart';
import 'package:idiom_crossword/src/ui/screens/game_screen.dart';
import 'package:idiom_crossword/src/ui/theme/grid_skins.dart';

void main() {
  testWidgets('页面入场后隐藏底层，退出时恢复底层且保留缩放转场', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('首页')),
      ),
    );
    navigator.currentState!.push(
      AppPageRoute<void>(builder: (_) => const Scaffold(body: Text('游戏'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('首页'), findsOneWidget);
    expect(find.byType(ScaleTransition), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('首页'), findsNothing);
    expect(find.text('游戏'), findsOneWidget);
    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('首页'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('游戏'), findsNothing);
  });

  test('棋盘忽略无关刷新，但原地修改答案和完成状态仍重绘', () {
    final grid = CrosswordGrid(rows: 1, cols: 1);
    final answers = <(int, int), String>{};
    final completed = <(int, int)>{};
    GridPainter painter() => GridPainter(
      grid: grid,
      playerAnswers: answers,
      focusRow: 0,
      focusCol: 0,
      errorCells: {},
      completedCells: completed,
      flashCell: null,
      cellSize: 40,
      skin: gridSkins.first,
      showPinyin: false,
      pinyinByCell: {},
      offset: Offset.zero,
    );
    final initial = painter();
    expect(painter().shouldRepaint(initial), isFalse);
    answers[(0, 0)] = '一';
    final filled = painter();
    expect(filled.shouldRepaint(initial), isTrue);
    expect(painter().shouldRepaint(filled), isFalse);
    completed.add((0, 0));
    expect(painter().shouldRepaint(filled), isTrue);
    final completedPainter = painter();
    grid.cellAt(0, 0).isGiven = true;
    expect(painter().shouldRepaint(completedPainter), isTrue);
  });
}

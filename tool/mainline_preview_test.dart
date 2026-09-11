// flutter test tool/mainline_preview_test.dart
// 输出 build/mainline-previews/ 下的真实字体界面截图，供人工检查。
import 'dart:io';
import 'dart:convert';
import 'package:idiom_crossword/src/data/mainline_learning.dart';
import 'dart:ui' as ui;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';
import 'package:idiom_crossword/src/ui/screens/game_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('主线界面截图', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers.global/events',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (_) async => null,
      );
    }
    messenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['playerId'];
          messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null,
          );
        }
        return null;
      },
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final setup = await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('mainline_preview_');
      final file = await File(
        'assets/data/idiom_crossword.db',
      ).copy('${dir.path}/preview.db');
      final db = AppDatabase(NativeDatabase(file));
      for (final (family, asset) in [
        ('Noto Sans SC', 'assets/fonts/NotoSansSC-Regular.ttf'),
        ('Noto Serif SC', 'assets/fonts/NotoSerifSC-Medium.ttf'),
      ]) {
        await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
      }
      return (db, dir);
    });
    final (db, dir) = setup!;
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    for (final (number, ability, size) in [
      (1, 0, const Size(390, 844)),
      (51, 30, const Size(390, 844)),
      (52, 30, const Size(375, 667)),
    ]) {
      tester.view.physicalSize = size;
      final level = await tester.runAsync(() async {
        await db.setSetting(
          MainlineLearning.key,
          jsonEncode({
            'sessions': [],
            'words': {},
            'adaptive': {'step': ability},
          }),
        );
        return generateLevel(db, number, seed: 17);
      });
      expect(level, isNotNull);
      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: GameScreen(level: level!),
            ),
          ),
        ),
      );
      for (var attempt = 0; attempt < 40; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File('build/mainline-previews/level-$number.png');
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      if (number == 52) {
        expect(find.byType(InteractiveViewer), findsOneWidget);
        final center = tester.getCenter(find.byType(InteractiveViewer));
        final a = await tester.startGesture(
          center - const Offset(20, 0),
          pointer: 1,
        );
        final b = await tester.startGesture(
          center + const Offset(20, 0),
          pointer: 2,
        );
        await a.moveTo(center - const Offset(50, 0));
        await b.moveTo(center + const Offset(50, 0));
        await tester.pump();
        await a.moveTo(center - const Offset(90, 0));
        await b.moveTo(center + const Offset(90, 0));
        await tester.pump();
        final transforms = tester.widgetList<Transform>(
          find.descendant(
            of: find.byType(InteractiveViewer),
            matching: find.byType(Transform),
          ),
        );
        expect(
          transforms.any((w) => w.transform.getMaxScaleOnAxis() > 1.5),
          isTrue,
        );
        await a.up();
        await b.up();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}

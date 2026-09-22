import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/engine/grid_engine.dart';
import 'package:idiom_crossword/src/ui/theme/app_text.dart';
import 'package:idiom_crossword/src/utils/level_share_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader(kSerif)
      ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-Bold.ttf'));
    await loader.load();
  });

  test('分享图包含初始网格并生成 PNG', () async {
    final grid = CrosswordGrid(rows: 3, cols: 4);
    const idiom = Idiom(text: '画蛇添足');
    for (var col = 0; col < 4; col++) {
      final cell = grid.cellAt(1, col);
      cell.state = CellState.filled;
      cell.character = idiom.text[col];
      cell.isGiven = col == 0;
    }
    final level = CrosswordLevel(
      levelId: 8,
      grid: grid,
      placements: [
        const Placement(
          idiom: idiom,
          startRow: 1,
          startCol: 0,
          direction: Direction.horizontal,
        ),
      ],
      givenCharacters: const {'画'},
      title: '第 8 关',
    );
    final qrData = await rootBundle.load('assets/images/qrcode.png');

    final bytes = await buildLevelShareImage(
      level: level,
      qrCodeBytes: qrData.buffer.asUint8List(
        qrData.offsetInBytes,
        qrData.lengthInBytes,
      ),
    );

    expect(bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 1080);
    expect(frame.image.height, greaterThan(800));
    final pixels = (await frame.image.toByteData())!;
    // 首个格子为 (284, 300, 128, 128)，只统计深色文字像素。
    var top = 428;
    var bottom = 300;
    var left = 412;
    var right = 284;
    for (var y = 304; y < 424; y++) {
      for (var x = 288; x < 408; x++) {
        final offset = (y * frame.image.width + x) * 4;
        if (pixels.getUint8(offset) < 100 &&
            pixels.getUint8(offset + 1) < 100 &&
            pixels.getUint8(offset + 2) < 100) {
          if (y < top) top = y;
          if (y > bottom) bottom = y;
          if (x < left) left = x;
          if (x > right) right = x;
        }
      }
    }
    expect(bottom, greaterThan(top));
    expect((left + right + 1) / 2, closeTo(348, 4));
    expect((top + bottom + 1) / 2, closeTo(364, 4));
    frame.image.dispose();
    codec.dispose();
  });
}

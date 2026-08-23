import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../engine/grid_engine.dart';
import '../ui/theme/app_colors.dart';
import '../ui/theme/app_text.dart';

const String kLevelShareTitle = '阁下请留步！你敢应战嘛？';

/// 生成“关卡初始网格 + 下载二维码”分享图。
Future<Uint8List> buildLevelShareImage({
  required CrosswordLevel level,
  required Uint8List qrCodeBytes,
}) async {
  const imageWidth = 1080.0;
  const horizontalPadding = 110.0;
  const gridTop = 300.0;
  const qrSize = 300.0;

  final bounds = _usedBounds(level.grid);
  final usedRows = bounds == null ? 0 : bounds.maxRow - bounds.minRow + 1;
  final usedCols = bounds == null ? 0 : bounds.maxCol - bounds.minCol + 1;
  final maxCellSize = min(
    (imageWidth - horizontalPadding * 2) / max(usedCols, 1),
    128.0,
  );
  final gridWidth = usedCols * maxCellSize;
  final gridHeight = usedRows * maxCellSize;
  final qrTop = gridTop + gridHeight + 110;
  final imageHeight = qrTop + qrSize + 150;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, imageWidth, imageHeight),
    Paint()..color = AppColors.bg,
  );

  _paintCenteredText(
    canvas,
    text: kLevelShareTitle,
    y: 82,
    width: imageWidth,
    style: const TextStyle(
      fontFamily: kSerif,
      fontSize: 54,
      fontWeight: FontWeight.w900,
      color: AppColors.fg,
    ),
  );
  _paintCenteredText(
    canvas,
    text: '${level.title} · 成语接龙挑战',
    y: 174,
    width: imageWidth,
    style: const TextStyle(
      fontFamily: kSans,
      fontSize: 30,
      fontWeight: FontWeight.w600,
      color: AppColors.muted,
    ),
  );

  if (bounds != null) {
    final gridLeft = (imageWidth - gridWidth) / 2;
    const cellPadding = 4.0;
    for (var row = bounds.minRow; row <= bounds.maxRow; row++) {
      for (var col = bounds.minCol; col <= bounds.maxCol; col++) {
        final cell = level.grid.cellAt(row, col);
        if (cell.state == CellState.blocked) continue;
        final x = gridLeft + (col - bounds.minCol) * maxCellSize;
        final y = gridTop + (row - bounds.minRow) * maxCellSize;
        final rect = Rect.fromLTWH(
          x + cellPadding,
          y + cellPadding,
          maxCellSize - cellPadding * 2,
          maxCellSize - cellPadding * 2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          Paint()
            ..color = cell.isGiven ? AppColors.surface2 : AppColors.surface,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(10)),
          Paint()
            ..color = AppColors.borderStrong
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        if (cell.isIntersection) {
          canvas.drawCircle(
            Offset(x + maxCellSize - 14, y + 14),
            6,
            Paint()..color = AppColors.accent,
          );
        }
        if (cell.isGiven) {
          _paintCenteredText(
            canvas,
            text: cell.character,
            y: y + (maxCellSize - maxCellSize * 0.58) / 2 - 5,
            width: maxCellSize,
            x: x,
            style: TextStyle(
              fontFamily: kSerif,
              fontSize: maxCellSize * 0.58,
              fontWeight: FontWeight.w700,
              color: AppColors.fg,
            ),
          );
        }
      }
    }
  }

  final codec = await ui.instantiateImageCodec(qrCodeBytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  final qrRect = Rect.fromLTWH(
    (imageWidth - qrSize) / 2,
    qrTop,
    qrSize,
    qrSize,
  );
  canvas.drawRect(qrRect.inflate(16), Paint()..color = Colors.white);
  canvas.drawImageRect(
    frame.image,
    Rect.fromLTWH(
      0,
      0,
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    ),
    qrRect,
    Paint()..filterQuality = FilterQuality.high,
  );
  frame.image.dispose();
  _paintCenteredText(
    canvas,
    text: 'App Store应用商店，扫码下载，一起来挑战',
    y: qrTop + qrSize + 48,
    width: imageWidth,
    style: const TextStyle(
      fontFamily: kSans,
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: AppColors.accentDeep,
    ),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(imageWidth.round(), imageHeight.round());
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('分享图生成失败');
  return data.buffer.asUint8List();
}

void _paintCenteredText(
  Canvas canvas, {
  required String text,
  required double y,
  required double width,
  required TextStyle style,
  double x = 0,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: width);
  painter.paint(canvas, Offset(x + (width - painter.width) / 2, y));
}

({int minRow, int maxRow, int minCol, int maxCol})? _usedBounds(
  CrosswordGrid grid,
) {
  var minRow = grid.rows;
  var maxRow = -1;
  var minCol = grid.cols;
  var maxCol = -1;
  for (var row = 0; row < grid.rows; row++) {
    for (var col = 0; col < grid.cols; col++) {
      if (grid.cellAt(row, col).state == CellState.blocked) continue;
      minRow = min(minRow, row);
      maxRow = max(maxRow, row);
      minCol = min(minCol, col);
      maxCol = max(maxCol, col);
    }
  }
  if (maxRow < minRow || maxCol < minCol) return null;
  return (minRow: minRow, maxRow: maxRow, minCol: minCol, maxCol: maxCol);
}

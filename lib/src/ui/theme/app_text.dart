import 'package:flutter/material.dart';
import 'app_colors.dart';

/// iOS 系统宋体（展示/成语/大数字用）；回退由系统处理
const String kSerif = 'Songti SC';

/// 展示样式：衬线、CJK 行高 ≥1.3、无负字距
TextStyle displayStyle({
  double size = 22,
  FontWeight weight = FontWeight.w700,
  Color color = AppColors.fg,
  double height = 1.3,
}) {
  return TextStyle(
    fontFamily: kSerif,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: 0,
  );
}

/// kicker：小号青灰、宽字距（近似 0.28em @ 11px）
TextStyle kickerStyle({Color color = AppColors.muted}) {
  return TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.8,
    color: color,
    height: 1.3,
  );
}

/// 正文样式：行高 1.7
TextStyle bodyStyle({
  double size = 14,
  Color color = AppColors.fg,
  FontWeight weight = FontWeight.w400,
}) {
  return TextStyle(fontSize: size, fontWeight: weight, color: color, height: 1.7);
}

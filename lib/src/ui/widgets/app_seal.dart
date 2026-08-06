import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

enum AppSealStyle { solid, hollow, gray }

/// 朱砂印章：实底 / 空心描边 / 灰底三态
class AppSeal extends StatelessWidget {
  final String text;
  final double size;
  final double fontSize;
  final AppSealStyle style;
  final bool vertical;

  const AppSeal(
    this.text, {
    super.key,
    this.size = 48,
    this.fontSize = 16,
    this.style = AppSealStyle.solid,
    this.vertical = true,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Border? border) = switch (style) {
      AppSealStyle.solid => (AppColors.accent, const Color(0xFFFFF6EC), null),
      AppSealStyle.hollow => (
        Colors.transparent,
        AppColors.accent,
        Border.all(color: AppColors.accent, width: 1.5),
      ),
      AppSealStyle.gray => (
        AppColors.surface2,
        AppColors.faint,
        Border.all(color: AppColors.borderStrong, width: 1.5, style: BorderStyle.solid),
      ),
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: border,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontFamily: kSerif,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: fg,
          height: 1.0,
        ),
      ),
    );
  }
}

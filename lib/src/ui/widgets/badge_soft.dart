import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum BadgeSoftColor { red, gold, leaf }

/// 软色胶囊徽章
class BadgeSoft extends StatelessWidget {
  final String text;
  final BadgeSoftColor color;

  const BadgeSoft(this.text, {super.key, this.color = BadgeSoftColor.red});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (color) {
      BadgeSoftColor.red => (AppColors.accentPale, AppColors.accent),
      BadgeSoftColor.gold => (AppColors.goldSoft, const Color(0xFF7A5D14)),
      BadgeSoftColor.leaf => (AppColors.leafSoft, AppColors.leaf),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: fg,
        ),
      ),
    );
  }
}

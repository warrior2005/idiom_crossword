import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 主按钮：朱砂底 + 深红下压阴影，按压缩回；ghost 为 surface 底朱砂字
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool ghost;
  final bool small;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.ghost = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final height = small ? 46.0 : 56.0;
    final radius = small ? 13.0 : 16.0;
    final baseColor = ghost ? AppColors.surface : AppColors.accent;
    final shadowColor = ghost ? AppColors.border : AppColors.accentDeep;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(radius),
          border: ghost ? Border.all(color: AppColors.accentSoft) : null,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              offset: const Offset(0, 6),
              blurRadius: 0,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: small ? 15 : 17,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: ghost ? AppColors.accent : const Color(0xFFFFF8EF),
          ),
        ),
      ),
    );
  }
}

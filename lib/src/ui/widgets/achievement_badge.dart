import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class AchievementBadge extends StatelessWidget {
  final String assetPath;
  final bool unlocked;
  final double size;

  const AchievementBadge({
    super.key,
    required this.assetPath,
    required this.unlocked,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderStrong, width: 1.5),
      ),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface2,
      ),
      child: unlocked
          ? Image.asset(assetPath, fit: BoxFit.cover)
          : Center(
              child: Text(
                '?',
                style: TextStyle(
                  fontFamily: kSerif,
                  fontSize: size * 0.33,
                  fontWeight: FontWeight.w700,
                  color: AppColors.faint,
                  height: 1,
                ),
              ),
            ),
    );
  }
}

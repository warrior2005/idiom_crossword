import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// 经验/进度条：surface2 底 + 朱砂渐增满
class XpTrack extends StatelessWidget {
  final double progress;
  final double height;

  const XpTrack({super.key, required this.progress, this.height = 8});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: AppColors.surface2,
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
      ),
    );
  }
}

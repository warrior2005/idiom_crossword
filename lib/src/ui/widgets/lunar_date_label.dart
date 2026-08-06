import 'package:flutter/material.dart';
import '../../utils/lunar_calendar.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// 首页日期：农历月日 + 当日节气（对齐设计稿 .hello / .hello .date）
class LunarDateLabel extends StatelessWidget {
  final DateTime? date;

  const LunarDateLabel({super.key, this.date});

  @override
  Widget build(BuildContext context) {
    final now = date ?? DateTime.now();
    final lunar = solarToLunar(now);
    final term = currentSolarTerm(now);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '农历${lunar.monthName}${lunar.dayName}',
            style: bodyStyle(size: 13, color: AppColors.muted),
          ),
          if (term != null)
            TextSpan(
              text: ' · $term',
              style: bodyStyle(size: 13, color: AppColors.fg, weight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}

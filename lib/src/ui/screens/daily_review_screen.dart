import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class DailyReviewScreen extends StatelessWidget {
  const DailyReviewScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(child: Text('每日回顾')),
    );
  }
}

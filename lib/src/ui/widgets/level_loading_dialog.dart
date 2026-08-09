import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'theme_dialog.dart';

/// 关卡生成中的加载对话框（首页/关卡选择/下一关共用）
Future<void> showLevelLoadingDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(
      child: ThemeDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.accent,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '正在生成关卡...',
              style: bodyStyle(size: 13, color: AppColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

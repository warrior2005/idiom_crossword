import 'package:flutter/material.dart';

/// 关卡生成中的加载对话框（首页/关卡选择/下一关共用）
Future<void> showLevelLoadingDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在生成关卡...'),
            ],
          ),
        ),
      ),
    ),
  );
}

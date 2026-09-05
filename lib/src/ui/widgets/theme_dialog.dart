import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 古典文人风通用弹框容器
class ThemeDialog extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ThemeDialog({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 28, 24, 24),
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          key: const ValueKey('theme-dialog-content'),
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66140A00),
                blurRadius: 60,
                offset: Offset(0, 24),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

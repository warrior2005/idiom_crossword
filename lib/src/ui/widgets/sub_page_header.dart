import 'package:flutter/material.dart';
import 'app_icons.dart';
import '../theme/app_text.dart';

/// 子页面顶栏：返回箭头 + 居中衬线标题
class SubPageHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SubPageHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _RoundIconButton(
            onTap: () => Navigator.of(context).maybePop(),
            icon: AppIcon('back', size: 20),
          ),
          Expanded(
            child: Center(child: Text(title, style: displayStyle(size: 20, weight: FontWeight.w700))),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: trailing ?? const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// 圆形图标按钮（返回/声音等）
class _RoundIconButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget icon;

  const _RoundIconButton({this.onTap, required this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFFBF7EE),
          border: Border.all(color: const Color(0xFFE2D8BE)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: icon),
      ),
    );
  }
}

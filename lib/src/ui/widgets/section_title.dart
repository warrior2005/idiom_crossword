import 'package:flutter/material.dart';
import '../theme/app_text.dart';

/// 区块标题：衬线标题 + 可选右侧链接
class SectionTitle extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;

  const SectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: displayStyle(size: 17, weight: FontWeight.w700)),
          ),
          if (trailing != null)
            GestureDetector(
              onTap: onTrailing,
              child: Text(
                trailing!,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF857C68)),
              ),
            ),
        ],
      ),
    );
  }
}

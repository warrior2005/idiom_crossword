import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// 圆形用户头像：默认科举印章或自定义相册图片
class UserAvatar extends StatelessWidget {
  final String seal;
  final String? customAvatarPath;
  final double size;
  final double fontSize;
  final FontWeight fontWeight;

  const UserAvatar({
    super.key,
    required this.seal,
    required this.customAvatarPath,
    required this.size,
    required this.fontSize,
    this.fontWeight = FontWeight.w700,
  });

  @override
  Widget build(BuildContext context) {
    final hasCustom = customAvatarPath != null && customAvatarPath!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: seal == '龙' ? null : AppColors.surface2,
        gradient: seal == '龙'
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2E2A20), Color(0xFF191610)],
              )
            : null,
      ),
      child: hasCustom
          ? ClipOval(
              child: Image.file(
                File(customAvatarPath!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _seal(),
              ),
            )
          : _seal(),
    );
  }

  Widget _seal() {
    return Center(
      child: Text(
        seal,
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontFamily: kSerif,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: seal == '龙' ? const Color(0xFFE8C87A) : AppColors.accent,
          height: 1.0,
        ),
      ),
    );
  }
}

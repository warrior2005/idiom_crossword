import 'package:flutter/material.dart';
import '../theme/decoration_catalog.dart';

/// 头像框：在印章/头像上叠加放大的头像框图片
const double kAvatarFrameImageScale = 1.9;

/// 头像框图片相对头像的垂直偏移（头像高度比例，负值向上）
const double kAvatarFrameVerticalOffset = -0.16;

class DecoratedSeal extends StatelessWidget {
  final String? frameId;
  final Widget child;

  const DecoratedSeal({super.key, this.frameId, required this.child});

  @override
  Widget build(BuildContext context) {
    if (frameId == null) return child;
    final def = avatarFrameById(frameId!);
    if (def == null) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (def.asset != null)
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) => Transform.translate(
                  offset: Offset(
                    0,
                    constraints.maxHeight * kAvatarFrameVerticalOffset,
                  ),
                  child: Transform.scale(
                    scale: kAvatarFrameImageScale,
                    child: Image.asset(def.asset!, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

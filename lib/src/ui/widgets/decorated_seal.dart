import 'package:flutter/material.dart';
import '../theme/decoration_catalog.dart';

/// 头像框：在印章/头像上叠加放大的头像框图片
const double kAvatarFrameImageScale = 2.1;

class DecoratedSeal extends StatelessWidget {
  final String? frameId;
  final Widget child;
  final EdgeInsets padding;

  const DecoratedSeal({
    super.key,
    this.frameId,
    required this.child,
    this.padding = const EdgeInsets.all(3),
  });

  @override
  Widget build(BuildContext context) {
    if (frameId == null) return child;
    final def = avatarFrameById(frameId!);
    if (def == null) return child;
    return Container(
      padding: padding,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (def.asset != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.scale(
                  scale: kAvatarFrameImageScale,
                  child: Image.asset(def.asset!, fit: BoxFit.contain),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/decoration_catalog.dart';

/// 头像框：为印章/头像套一层描边与光晕
class DecoratedSeal extends StatelessWidget {
  final String? frameId;
  final Widget child;
  final bool circle;
  final EdgeInsets padding;

  const DecoratedSeal({
    super.key,
    this.frameId,
    required this.child,
    this.circle = false,
    this.padding = const EdgeInsets.all(3),
  });

  @override
  Widget build(BuildContext context) {
    if (frameId == null) return child;
    final def = avatarFrameById(frameId!);
    if (def == null) return child;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(14),
        border: Border.all(color: def.color, width: def.width),
        boxShadow: [
          BoxShadow(color: def.glow, blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (def.asset != null)
            Positioned.fill(
              child: IgnorePointer(
                child: Image.asset(def.asset!, fit: BoxFit.contain),
              ),
            ),
        ],
      ),
    );
  }
}

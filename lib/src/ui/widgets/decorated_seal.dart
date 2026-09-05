import 'package:flutter/material.dart';
import '../theme/decoration_catalog.dart';

/// 头像框：在印章/头像上叠加放大的头像框图片
const double kAvatarFrameImageScale = 1.9;

/// 头像框图片相对头像的垂直偏移（头像高度比例，负值向上）
/// 乌纱帽、东坡巾、翼善冠、獬豸冠 = -0.24
/// 忠靖冠 = -0.22
/// 四方平定巾= -0.17
/// 天子冕冠 = -0.19
const double kAvatarFrameVerticalOffset = -0.24;

class DecoratedSeal extends StatelessWidget {
  final String? frameId;
  final Widget child;

  const DecoratedSeal({super.key, this.frameId, required this.child});

  @override
  Widget build(BuildContext context) {
    if (frameId == null) return child;
    final def = avatarFrameById(frameId!);
    if (def == null) return child;
    double avatarFrameVerticalOffset = kAvatarFrameVerticalOffset;
    if (frameId!.contains('zhongjing')) {
      avatarFrameVerticalOffset = -0.22;
    } else if (frameId!.contains('sifang')) {
      avatarFrameVerticalOffset = -0.17;
    } else if (frameId!.contains('tianzi')) {
      avatarFrameVerticalOffset = -0.19;
    }
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
                    constraints.maxHeight * avatarFrameVerticalOffset,
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

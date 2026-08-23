import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/decoration_catalog.dart';

/// 带称号特效的文字。未装备特效时保持普通 [Text] 渲染。
class AnimatedTitleText extends StatefulWidget {
  final String text;
  final String? effectId;
  final TextStyle style;
  final TextAlign? textAlign;

  const AnimatedTitleText({
    super.key,
    required this.text,
    required this.effectId,
    required this.style,
    this.textAlign,
  });

  @override
  State<AnimatedTitleText> createState() => _AnimatedTitleTextState();
}

class _AnimatedTitleTextState extends State<AnimatedTitleText>
    with TickerProviderStateMixin {
  static const _entranceDuration = Duration(milliseconds: 800);
  static const _ambientDuration = Duration(milliseconds: 1600);

  late final AnimationController _entranceController;
  late final AnimationController _ambientController;
  late final Listenable _animation;
  Timer? _ambientTimer;
  bool _animationsEnabled = false;

  bool get _hasEffect => titleEffectById(widget.effectId ?? '') != null;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: _entranceDuration,
      value: 1,
    )..addStatusListener(_handleEntranceStatus);
    _ambientController = AnimationController(
      vsync: this,
      duration: _ambientDuration,
    )..addStatusListener(_handleAmbientStatus);
    _animation = Listenable.merge([_entranceController, _ambientController]);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final enabled = !reduceMotion && TickerMode.valuesOf(context).enabled;
    if (enabled == _animationsEnabled) return;
    _animationsEnabled = enabled;
    _restartAnimations();
  }

  @override
  void didUpdateWidget(covariant AnimatedTitleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.effectId != widget.effectId ||
        oldWidget.text != widget.text) {
      _restartAnimations();
    }
  }

  void _handleEntranceStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _scheduleAmbient();
  }

  void _handleAmbientStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _ambientController.value = 0;
    _scheduleAmbient();
  }

  void _restartAnimations() {
    _ambientTimer?.cancel();
    _entranceController.stop();
    _ambientController.stop();
    _ambientController.value = 0;
    if (!_animationsEnabled || !_hasEffect) {
      _entranceController.value = 1;
      return;
    }
    _entranceController.forward(from: 0);
  }

  void _scheduleAmbient() {
    _ambientTimer?.cancel();
    if (!_animationsEnabled || !_hasEffect) return;
    final delay = widget.effectId == 'tianzi'
        ? const Duration(milliseconds: 2400)
        : const Duration(milliseconds: 3400);
    _ambientTimer = Timer(delay, () {
      if (!mounted || !_animationsEnabled || !_hasEffect) return;
      _ambientController.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _ambientTimer?.cancel();
    _entranceController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = titleEffectById(widget.effectId ?? '');
    if (def == null) {
      return Text(
        widget.text,
        textAlign: widget.textAlign,
        style: widget.style,
      );
    }

    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) => _TitleEffectVisual(
              text: widget.text,
              def: def,
              style: widget.style,
              textAlign: widget.textAlign,
              entrance: _animationsEnabled ? _entranceController.value : 1,
              ambient: _animationsEnabled ? _ambientController.value : 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleEffectVisual extends StatelessWidget {
  final String text;
  final TitleEffectDef def;
  final TextStyle style;
  final TextAlign? textAlign;
  final double entrance;
  final double ambient;

  const _TitleEffectVisual({
    required this.text,
    required this.def,
    required this.style,
    required this.textAlign,
    required this.entrance,
    required this.ambient,
  });

  @override
  Widget build(BuildContext context) {
    return switch (def.id) {
      'jinbang' => _buildJinbang(),
      'tianzi' => _buildGongqing(),
      _ => Text(
        text,
        textAlign: textAlign,
        style: applyTitleEffect(def.id, style),
      ),
    };
  }

  Widget _buildJinbang() {
    final reveal = _interval(entrance, 0, 0.65, curve: Curves.easeOutCubic);
    final phase = ambient > 0
        ? ambient
        : _interval(entrance, 0.25, 1, curve: Curves.easeInOut);
    final shimmerOpacity = math.sin(math.pi * phase).clamp(0.0, 1.0);
    final shadowStyle = style.copyWith(
      color: def.textColor,
      shadows: [
        Shadow(color: def.glow.withValues(alpha: 0.7), blurRadius: 10),
        Shadow(color: def.glow.withValues(alpha: 0.32), blurRadius: 22),
      ],
    );

    return ClipRect(
      clipper: _CenterRevealClipper(reveal),
      child: CustomPaint(
        key: const ValueKey('title-effect-jinbang-accents'),
        foregroundPainter: _TitleAccentPainter(
          effectId: def.id,
          entrance: entrance,
          phase: phase,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 3, 7, 5),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Text(text, textAlign: textAlign, style: shadowStyle),
              _GradientText(
                text: text,
                textAlign: textAlign,
                style: style,
                colors: const [
                  Color(0xFF75440A),
                  Color(0xFFF4D77E),
                  Color(0xFF9A6211),
                ],
              ),
              if (shimmerOpacity > 0.001)
                Opacity(
                  opacity: shimmerOpacity,
                  child: _SweepText(
                    text: text,
                    textAlign: textAlign,
                    style: style,
                    progress: phase,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGongqing() {
    final appearance = _interval(entrance, 0, 0.55, curve: Curves.easeOutCubic);
    final phase = ambient > 0
        ? ambient
        : _interval(entrance, 0.3, 1, curve: Curves.easeInOut);
    final outline = def.glow.withValues(alpha: 0.62);
    final shadowStyle = style.copyWith(
      color: def.textColor,
      shadows: [
        Shadow(color: outline, offset: const Offset(-0.7, 0)),
        Shadow(color: outline, offset: const Offset(0.7, 0)),
        Shadow(color: outline, offset: const Offset(0, -0.7)),
        Shadow(color: outline, offset: const Offset(0, 0.7)),
        Shadow(color: def.glow.withValues(alpha: 0.36), blurRadius: 18),
      ],
    );

    return Opacity(
      opacity: 0.35 + 0.65 * appearance,
      child: Transform.scale(
        scale: 0.97 + 0.03 * appearance,
        alignment: Alignment.centerLeft,
        child: CustomPaint(
          key: const ValueKey('title-effect-tianzi-accents'),
          painter: _TitleAccentPainter(
            effectId: def.id,
            entrance: appearance,
            phase: phase,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Text(text, textAlign: textAlign, style: shadowStyle),
                _GradientText(
                  text: text,
                  textAlign: textAlign,
                  style: style,
                  colors: const [
                    Color(0xFF731C14),
                    Color(0xFFD05B35),
                    Color(0xFF8F2418),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final List<Color> colors;

  const _GradientText({
    required this.text,
    required this.style,
    required this.textAlign,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          LinearGradient(colors: colors).createShader(bounds),
      child: Text(
        text,
        textAlign: textAlign,
        style: style.copyWith(color: Colors.white, shadows: const []),
      ),
    );
  }
}

class _SweepText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;
  final double progress;

  const _SweepText({
    required this.text,
    required this.style,
    required this.textAlign,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      key: const ValueKey('title-effect-jinbang-sweep'),
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        final center = -0.18 + progress * 1.36;
        return LinearGradient(
          colors: const [
            Colors.transparent,
            Colors.transparent,
            Color(0xFFFFF4C4),
            Colors.transparent,
            Colors.transparent,
          ],
          stops: [
            0,
            (center - 0.15).clamp(0.0, 1.0),
            center.clamp(0.0, 1.0),
            (center + 0.15).clamp(0.0, 1.0),
            1,
          ],
        ).createShader(bounds);
      },
      child: Text(
        text,
        textAlign: textAlign,
        style: style.copyWith(color: Colors.white, shadows: const []),
      ),
    );
  }
}

class _CenterRevealClipper extends CustomClipper<Rect> {
  final double progress;

  const _CenterRevealClipper(this.progress);

  @override
  Rect getClip(Size size) {
    final width = size.width * progress.clamp(0.0, 1.0);
    return Rect.fromLTWH((size.width - width) / 2, 0, width, size.height);
  }

  @override
  bool shouldReclip(_CenterRevealClipper oldClipper) =>
      oldClipper.progress != progress;
}

class _TitleAccentPainter extends CustomPainter {
  final String effectId;
  final double entrance;
  final double phase;

  const _TitleAccentPainter({
    required this.effectId,
    required this.entrance,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (effectId == 'jinbang') {
      _paintJinbang(canvas, size);
    } else if (effectId == 'tianzi') {
      _paintGongqing(canvas, size);
    }
  }

  void _paintJinbang(Canvas canvas, Size size) {
    final reveal = _interval(entrance, 0, 0.7, curve: Curves.easeOutCubic);
    final center = size.width / 2;
    final halfWidth = math.max(0.0, (size.width - 14) * reveal / 2);
    final lineRect = Rect.fromLTRB(
      center - halfWidth,
      size.height - 2.5,
      center + halfWidth,
      size.height - 1.2,
    );
    canvas.drawRect(
      lineRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x0075440A), Color(0xFFEAC75E), Color(0x0075440A)],
        ).createShader(lineRect),
    );

    final sparkle = math.sin(math.pi * phase).clamp(0.0, 1.0);
    if (sparkle <= 0.01) return;
    const points = [
      Offset(0.10, 0.28),
      Offset(0.28, 0.08),
      Offset(0.52, 0.2),
      Offset(0.73, 0.05),
      Offset(0.91, 0.32),
    ];
    final paint = Paint()..color = const Color(0xFFF8DD7B);
    for (var i = 0; i < points.length; i++) {
      final local = math.sin(math.pi * (phase + i * 0.09).clamp(0, 1));
      paint.color = const Color(
        0xFFF8DD7B,
      ).withValues(alpha: sparkle * local * 0.9);
      canvas.drawCircle(
        Offset(points[i].dx * size.width, points[i].dy * size.height),
        i.isEven ? 1.7 : 1.2,
        paint,
      );
    }
  }

  void _paintGongqing(Canvas canvas, Size size) {
    final pulse = math.sin(math.pi * phase).clamp(0.0, 1.0);
    final glowScale = 0.78 + pulse * 0.18;
    final glowPaint = Paint()
      ..color = const Color(
        0xFFE0B83E,
      ).withValues(alpha: (0.16 + pulse * 0.18) * entrance)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.48, size.height / 2),
        width: size.width * glowScale,
        height: (size.height - 14) * (0.7 + pulse * 0.12),
      ),
      glowPaint,
    );

    final cloudPaint = Paint()
      ..color = const Color(
        0xFFD9B23C,
      ).withValues(alpha: (0.48 + pulse * 0.35) * entrance)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35
      ..strokeCap = StrokeCap.round;
    final cloudWidth = math.min(42.0, math.max(28.0, size.width * 0.23));
    const cloudHeight = 8.5;
    final cloud = Path()
      ..moveTo(3, cloudHeight + 0.5)
      ..lineTo(3 + cloudWidth * 0.15, cloudHeight + 0.5)
      ..cubicTo(
        3 + cloudWidth * 0.1,
        cloudHeight * 0.45,
        3 + cloudWidth * 0.28,
        cloudHeight * 0.35,
        3 + cloudWidth * 0.33,
        cloudHeight * 0.68,
      )
      ..cubicTo(
        3 + cloudWidth * 0.34,
        cloudHeight * 0.12,
        3 + cloudWidth * 0.58,
        cloudHeight * 0.05,
        3 + cloudWidth * 0.61,
        cloudHeight * 0.62,
      )
      ..cubicTo(
        3 + cloudWidth * 0.7,
        cloudHeight * 0.28,
        3 + cloudWidth * 0.85,
        cloudHeight * 0.38,
        3 + cloudWidth * 0.82,
        cloudHeight * 0.72,
      )
      ..lineTo(3 + cloudWidth, cloudHeight * 0.72)
      ..moveTo(3 + cloudWidth * 0.24, cloudHeight + 2)
      ..cubicTo(
        3 + cloudWidth * 0.38,
        cloudHeight + 3,
        3 + cloudWidth * 0.51,
        cloudHeight + 2.8,
        3 + cloudWidth * 0.59,
        cloudHeight + 1,
      );
    canvas.drawPath(cloud, cloudPaint);
    canvas.save();
    canvas.translate(size.width, size.height);
    canvas.scale(-1, -1);
    canvas.drawPath(cloud, cloudPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TitleAccentPainter oldDelegate) =>
      oldDelegate.effectId != effectId ||
      oldDelegate.entrance != entrance ||
      oldDelegate.phase != phase;
}

double _interval(
  double value,
  double begin,
  double end, {
  Curve curve = Curves.linear,
}) {
  if (value <= begin) return 0;
  if (value >= end) return 1;
  return curve.transform((value - begin) / (end - begin));
}

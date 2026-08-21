import 'package:flutter/material.dart';

/// 从屏幕中心展开、退出时收回中心的页面路由。
class AppPageRoute<T> extends PageRoute<T> {
  AppPageRoute({required this.builder, super.settings});

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations;
    if (disableAnimations ?? false) return child;
    return ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Curves.linearToEaseOut),
      child: child,
    );
  }
}

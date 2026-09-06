import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Owns one native banner. Removing this widget releases its SDK resources.
class DirichletBannerView extends StatefulWidget {
  const DirichletBannerView({
    super.key,
    required this.onShown,
    required this.onFailed,
    required this.onClosed,
  });

  final VoidCallback onShown;
  final VoidCallback onFailed;
  final VoidCallback onClosed;

  @override
  State<DirichletBannerView> createState() => _DirichletBannerViewState();
}

class _DirichletBannerViewState extends State<DirichletBannerView> {
  MethodChannel? _channel;

  Future<void> _onCreated(int id) async {
    final channel = MethodChannel('idiom_crossword/dirichlet/banner/$id');
    if (!mounted) {
      await channel.invokeMethod<void>('dispose');
      return;
    }
    _channel = channel;
    channel.setMethodCallHandler((call) async {
      if (!mounted) return;
      switch (call.method) {
        case 'shown':
          widget.onShown();
        case 'failed':
          widget.onFailed();
        case 'closed':
          widget.onClosed();
      }
    });
    try {
      await channel.invokeMethod<void>('load');
    } on PlatformException {
      if (mounted) widget.onFailed();
    }
  }

  @override
  void dispose() {
    final channel = _channel;
    if (channel != null) {
      channel.setMethodCallHandler(null);
      unawaited(
        channel.invokeMethod<void>('dispose').catchError((Object _) {}),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    height: 50,
    child: UiKitView(
      viewType: 'idiom_crossword/dirichlet/banner',
      onPlatformViewCreated: _onCreated,
    ),
  );
}

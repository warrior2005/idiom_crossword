import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS SDK owns the cached ad and checks isReady again immediately before show.
class DirichletAds {
  DirichletAds({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('idiom_crossword/dirichlet');

  final MethodChannel _channel;
  final ValueNotifier<bool> rewardReady = ValueNotifier(false);
  Future<bool>? _loading;
  bool _showing = false;
  int _generation = 0;

  Future<String?> systemRegion() =>
      _channel.invokeMethod<String>('systemRegion');

  Future<bool> requestConsent({bool force = false}) async =>
      await _channel.invokeMethod<bool>('requestConsent', {'force': force}) ??
      false;

  Future<bool> initialize() async =>
      await _channel.invokeMethod<bool>('initialize', {'debug': kDebugMode}) ??
      false;

  Future<bool> loadRewarded() {
    if (_showing) return Future.value(false);
    return _loading ??= _loadRewarded();
  }

  Future<bool> _loadRewarded() async {
    final generation = _generation;
    try {
      final loaded = await _channel.invokeMethod<bool>('loadRewarded') ?? false;
      if (generation != _generation) return false;
      rewardReady.value = loaded;
      return loaded;
    } on PlatformException {
      if (generation == _generation) rewardReady.value = false;
      return false;
    } finally {
      if (generation == _generation) _loading = null;
    }
  }

  bool showRewarded({
    required void Function(String, int) onRewardEarned,
    VoidCallback? onAdClosed,
  }) {
    if (_showing || !rewardReady.value) return false;
    _showing = true;
    rewardReady.value = false;
    unawaited(_showRewarded(onRewardEarned, onAdClosed));
    return true;
  }

  Future<void> _showRewarded(
    void Function(String, int) onRewardEarned,
    VoidCallback? onAdClosed,
  ) async {
    final generation = _generation;
    try {
      // Native returns true only after the SDK reward callback AND ad close.
      final earned = await _channel.invokeMethod<bool>('showRewarded') ?? false;
      if (earned && generation == _generation) onRewardEarned('积分', 1);
    } on PlatformException catch (error) {
      debugPrint('Dirichlet show failed: ${error.code}');
    } finally {
      _showing = false;
      onAdClosed?.call();
    }
  }

  Future<void> disposeAds() async {
    _generation++;
    _loading = null;
    rewardReady.value = false;
    try {
      await _channel.invokeMethod<void>('disposeAds');
    } on PlatformException catch (error) {
      debugPrint('Dirichlet dispose failed: ${error.code}');
    }
  }
}

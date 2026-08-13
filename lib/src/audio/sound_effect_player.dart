import 'dart:async';

import 'package:flutter/foundation.dart';

typedef SoundEffectStart = Future<void> Function();
typedef SoundEffectDispose = Future<void> Function();

/// 为预加载音效提供简单的并发和播放频率限制。
class SoundEffectPlayer {
  SoundEffectPlayer({
    required SoundEffectStart start,
    required SoundEffectDispose disposePool,
    this.minInterval = Duration.zero,
    this.maxConcurrent = 1,
    this.activeHoldDuration = Duration.zero,
    required this.debugLabel,
  }) : _start = start,
       _disposePool = disposePool,
       assert(maxConcurrent > 0);

  final SoundEffectStart _start;
  final SoundEffectDispose _disposePool;
  final Duration minInterval;
  final int maxConcurrent;
  final Duration activeHoldDuration;
  final String debugLabel;

  final List<Timer> _releaseTimers = [];
  DateTime? _lastStartedAt;
  int _activeStarts = 0;
  bool _disposed = false;

  Future<void> play() async {
    final now = DateTime.now();
    if (_disposed ||
        _activeStarts >= maxConcurrent ||
        (_lastStartedAt != null &&
            now.difference(_lastStartedAt!) < minInterval)) {
      return;
    }

    _lastStartedAt = now;
    _activeStarts++;
    var started = false;
    try {
      await _start();
      started = true;
    } catch (error) {
      if (kDebugMode) debugPrint('Failed to play $debugLabel: $error');
    } finally {
      _release(started ? activeHoldDuration : Duration.zero);
    }
  }

  void _release(Duration delay) {
    if (_disposed || delay <= Duration.zero) {
      if (_activeStarts > 0) _activeStarts--;
      return;
    }

    late final Timer timer;
    timer = Timer(delay, () {
      _releaseTimers.remove(timer);
      if (_activeStarts > 0) _activeStarts--;
    });
    _releaseTimers.add(timer);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final timer in _releaseTimers) {
      timer.cancel();
    }
    _releaseTimers.clear();
    await _disposePool();
  }
}

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'music_manager.dart';
import 'sound_effect_player.dart';

/// 预加载并独立播放游戏音效。
class SoundManager {
  SoundManager._();

  static final SoundManager instance = SoundManager._();

  bool _initialized = false;
  bool _enabled = true;
  SoundEffectPlayer? _correct;
  SoundEffectPlayer? _wrong;
  SoundEffectPlayer? _fill;
  SoundEffectPlayer? _idiom;
  SoundEffectPlayer? _complete;

  bool get enabled => _enabled;

  Future<void> init({required bool enabled}) async {
    if (_initialized) return;
    _enabled = enabled;
    try {
      _correct = await _create(
        'correct.wav',
        maxPlayers: 4,
        minInterval: const Duration(milliseconds: 35),
        hold: const Duration(milliseconds: 100),
      );
      _wrong = await _create(
        'wrong.wav',
        maxPlayers: 2,
        minInterval: const Duration(milliseconds: 50),
        hold: const Duration(milliseconds: 180),
      );
      _fill = await _create(
        'fill.wav',
        maxPlayers: 4,
        minInterval: const Duration(milliseconds: 35),
        hold: const Duration(milliseconds: 100),
      );
      _idiom = await _create(
        'idiom.wav',
        maxPlayers: 2,
        minInterval: const Duration(milliseconds: 70),
        hold: const Duration(milliseconds: 350),
      );
      _complete = await _create(
        'complete.wav',
        hold: const Duration(milliseconds: 1000),
      );
      _initialized = true;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('SoundManager initialization failed: $error');
      }
      await dispose();
    }
  }

  void setEnabled(bool enabled) {
    _enabled = enabled;
    MusicManager.instance.setSoundEnabled(enabled);
  }

  Future<SoundEffectPlayer> _create(
    String asset, {
    int maxPlayers = 1,
    Duration minInterval = Duration.zero,
    Duration hold = Duration.zero,
  }) async {
    final pool = await _SoundPool.create(asset, maxPlayers: maxPlayers);
    return SoundEffectPlayer(
      start: pool.play,
      disposePool: pool.dispose,
      minInterval: minInterval,
      maxConcurrent: maxPlayers,
      activeHoldDuration: hold,
      debugLabel: asset,
    );
  }

  bool get _canPlay =>
      _initialized && _enabled && !MusicManager.instance.isSilentMode;

  Future<void> _play(SoundEffectPlayer? effect) async {
    if (!_canPlay || effect == null) return;
    await effect.play();
  }

  Future<void> playCorrect() => _play(_correct);
  Future<void> playWrong() => _play(_wrong);
  Future<void> playFill() => _play(_fill);
  Future<void> playIdiom() => _play(_idiom);
  Future<void> playComplete() => _play(_complete);

  Future<void> dispose() async {
    await Future.wait([
      if (_correct != null) _correct!.dispose(),
      if (_wrong != null) _wrong!.dispose(),
      if (_fill != null) _fill!.dispose(),
      if (_idiom != null) _idiom!.dispose(),
      if (_complete != null) _complete!.dispose(),
    ]);
    _correct = null;
    _wrong = null;
    _fill = null;
    _idiom = null;
    _complete = null;
    _initialized = false;
  }
}

class _SoundPool {
  _SoundPool(this._available, this._subscriptions);

  final List<AudioPlayer> _available;
  final List<StreamSubscription<void>> _subscriptions;
  final Set<AudioPlayer> _active = {};
  bool _disposed = false;

  static Future<_SoundPool> create(
    String asset, {
    required int maxPlayers,
  }) async {
    final available = <AudioPlayer>[];
    final subscriptions = <StreamSubscription<void>>[];
    late final _SoundPool pool;
    pool = _SoundPool(available, subscriptions);

    final context = AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.game,
      ),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    );
    for (var i = 0; i < maxPlayers; i++) {
      final player = AudioPlayer();
      player.positionUpdater = null;
      await player.setAudioContext(context);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(AssetSource('audio/$asset'));
      available.add(player);
      subscriptions.add(
        player.onPlayerComplete.listen((_) => pool._return(player)),
      );
    }
    return pool;
  }

  Future<void> play() async {
    if (_disposed || _available.isEmpty) return;
    final player = _available.removeLast();
    _active.add(player);
    try {
      await player.stop();
      await player.resume();
    } catch (_) {
      _return(player);
      rethrow;
    }
  }

  void _return(AudioPlayer player) {
    if (_disposed || !_active.remove(player)) return;
    _available.add(player);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait(_subscriptions.map((item) => item.cancel()));
    final players = {..._available, ..._active};
    _available.clear();
    _active.clear();
    await Future.wait(players.map((player) => player.dispose()));
  }
}

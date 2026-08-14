import 'dart:async';

import 'package:audio_session/audio_session.dart' as audio_session;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sound_mode_advanced/sound_mode_advanced.dart';

/// 管理页面背景音乐、系统音频中断和物理静音状态。
class MusicManager with WidgetsBindingObserver {
  MusicManager._();

  static final MusicManager instance = MusicManager._();

  static const _menuMusic = 'audio/menu.mp3';
  static const _gameMusic = 'audio/game.mp3';
  static const _muteCheckInterval = Duration(seconds: 8);

  final AudioPlayer _player = AudioPlayer();
  Timer? _muteCheckTimer;
  StreamSubscription<audio_session.AudioInterruptionEvent>?
  _interruptionSubscription;
  StreamSubscription<void>? _becomingNoisySubscription;

  bool _initialized = false;
  bool _musicEnabled = true;
  bool _soundEnabled = true;
  bool _isPhysicalMuted = false;
  bool _isForeground = true;
  bool _pausedByNoisy = false;
  bool _checkingMuteStatus = false;
  String _desiredMusic = _menuMusic;
  String? _loadedMusic;
  final Set<Object> _visibleGames = {};

  bool get musicEnabled => _musicEnabled;
  bool get isSilentMode => _isPhysicalMuted;

  Future<void> init({
    required bool musicEnabled,
    required bool soundEnabled,
  }) async {
    if (_initialized) return;

    _musicEnabled = musicEnabled;
    _soundEnabled = soundEnabled;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.game,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );

      final session = await audio_session.AudioSession.instance;
      await session.configure(
        const audio_session.AudioSessionConfiguration(
          avAudioSessionCategory: audio_session.AVAudioSessionCategory.ambient,
          avAudioSessionMode: audio_session.AVAudioSessionMode.defaultMode,
          androidAudioAttributes: audio_session.AndroidAudioAttributes(
            contentType: audio_session.AndroidAudioContentType.music,
            usage: audio_session.AndroidAudioUsage.game,
          ),
          androidAudioFocusGainType:
              audio_session.AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );
      _interruptionSubscription = session.interruptionEventStream.listen(
        _handleInterruption,
      );
      _becomingNoisySubscription = session.becomingNoisyEventStream.listen((_) {
        _pausedByNoisy = true;
        unawaited(_player.pause());
      });

      await _checkMuteStatus();
      _syncMuteChecker();
      await _playCurrentMusic();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('MusicManager initialization failed: $error');
      }
    }
  }

  void enterGame(Object owner) {
    _visibleGames.add(owner);
    _syncPageMusic();
  }

  void coverGame(Object owner) {
    _visibleGames.remove(owner);
    _syncPageMusic();
  }

  void revealGame(Object owner) {
    _visibleGames.add(owner);
    _syncPageMusic();
  }

  void exitGame(Object owner) {
    _visibleGames.remove(owner);
    _syncPageMusic();
  }

  void _syncPageMusic() {
    unawaited(_switchMusic(_visibleGames.isEmpty ? _menuMusic : _gameMusic));
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    _syncMuteChecker();
    if (!_initialized) return;
    if (!enabled) {
      await _player.pause();
      return;
    }

    _pausedByNoisy = false;
    await _checkMuteStatus();
    await _playCurrentMusic();
  }

  void setSoundEnabled(bool enabled) {
    _soundEnabled = enabled;
    _syncMuteChecker();
  }

  Future<void> _switchMusic(String asset) async {
    _desiredMusic = asset;
    if (!_initialized ||
        !_musicEnabled ||
        _isPhysicalMuted ||
        !_isForeground ||
        _pausedByNoisy) {
      return;
    }
    if (_loadedMusic == asset && _player.state == PlayerState.playing) return;

    try {
      await _player.stop();
      if (_desiredMusic != asset) return;
      await _player.play(AssetSource(asset));
      if (_desiredMusic == asset) _loadedMusic = asset;
    } catch (error) {
      if (kDebugMode) debugPrint('Failed to play $asset: $error');
    }
  }

  Future<void> _playCurrentMusic() async {
    if (!_initialized ||
        !_musicEnabled ||
        _isPhysicalMuted ||
        !_isForeground ||
        _pausedByNoisy) {
      return;
    }

    try {
      if (_loadedMusic != _desiredMusic) {
        await _switchMusic(_desiredMusic);
      } else if (_player.state == PlayerState.paused) {
        await _player.resume();
      } else if (_player.state != PlayerState.playing) {
        await _player.play(AssetSource(_desiredMusic));
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to resume $_desiredMusic: $error');
      }
    }
  }

  void _handleInterruption(audio_session.AudioInterruptionEvent event) {
    if (event.begin) {
      unawaited(_player.pause());
      return;
    }

    if (event.type == audio_session.AudioInterruptionType.pause ||
        event.type == audio_session.AudioInterruptionType.unknown) {
      unawaited(_resumeAfterInterruption());
    }
  }

  Future<void> _resumeAfterInterruption() async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await _playCurrentMusic();
  }

  bool get _shouldCheckMute =>
      _initialized && _isForeground && (_musicEnabled || _soundEnabled);

  void _syncMuteChecker() {
    if (_shouldCheckMute) {
      _muteCheckTimer ??= Timer.periodic(_muteCheckInterval, (_) async {
        await _checkMuteStatus();
        if (_isPhysicalMuted) {
          await _player.pause();
        } else {
          await _playCurrentMusic();
        }
      });
    } else {
      _muteCheckTimer?.cancel();
      _muteCheckTimer = null;
    }
  }

  Future<void> _checkMuteStatus() async {
    if (_checkingMuteStatus) return;
    _checkingMuteStatus = true;
    try {
      final status = await SoundMode.ringerModeStatus;
      _isPhysicalMuted =
          status == RingerModeStatus.silent ||
          status == RingerModeStatus.vibrate;
    } catch (_) {
      _isPhysicalMuted = false;
    } finally {
      _checkingMuteStatus = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.inactive:
        _isForeground = false;
        _syncMuteChecker();
        unawaited(_player.pause());
        break;
      case AppLifecycleState.resumed:
        _isForeground = true;
        _syncMuteChecker();
        unawaited(_resumeFromForeground());
        break;
      case AppLifecycleState.detached:
        unawaited(dispose());
        break;
    }
  }

  Future<void> _resumeFromForeground() async {
    await _checkMuteStatus();
    await _playCurrentMusic();
  }

  Future<void> dispose() async {
    if (!_initialized) return;
    _initialized = false;
    _muteCheckTimer?.cancel();
    _muteCheckTimer = null;
    await _interruptionSubscription?.cancel();
    await _becomingNoisySubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _player.dispose();
  }
}

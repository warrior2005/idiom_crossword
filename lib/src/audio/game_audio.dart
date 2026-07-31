import 'package:audioplayers/audioplayers.dart';

/// 游戏音效（全局单例，播放失败静默忽略）
class GameAudio {
  GameAudio._();

  static final GameAudio instance = GameAudio._();

  final AudioPlayer _player = AudioPlayer();

  /// 全局静音开关
  bool muted = false;

  Future<void> play(String assetName) async {
    if (muted) return;
    try {
      await _player.stop();
      await _player.setVolume(0.5);
      await _player.play(AssetSource('audio/$assetName'));
    } catch (_) {
      // 音频不可用时静默降级（测试环境/无音频设备）
    }
  }

  Future<void> dispose() => _player.dispose();
}

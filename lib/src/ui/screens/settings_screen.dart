import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../audio/game_audio.dart';
import '../../state/database_provider.dart';

/// 音效开关设置项键名
const String soundEnabledKey = 'sound_enabled';

/// 音效开关（持久化到 settings 表）
final soundEnabledProvider =
    AsyncNotifierProvider<SoundSettingNotifier, bool>(SoundSettingNotifier.new);

class SoundSettingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final db = ref.watch(databaseProvider);
    final value = await db.getSetting(soundEnabledKey);
    final enabled = value != 'false';
    GameAudio.instance.muted = !enabled;
    return enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    GameAudio.instance.muted = !enabled;
    await ref
        .read(databaseProvider)
        .setSetting(soundEnabledKey, enabled.toString());
    state = AsyncData(enabled);
  }
}

/// 设置界面
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundAsync = ref.watch(soundEnabledProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        children: [
          soundAsync.when(
            loading: () => const ListTile(title: Text('加载中...')),
            error: (e, _) => ListTile(title: Text('加载失败: $e')),
            data: (enabled) => SwitchListTile(
              title: const Text('音效'),
              subtitle: const Text('填字、成语完成与过关音效'),
              value: enabled,
              onChanged: (v) =>
                  ref.read(soundEnabledProvider.notifier).setEnabled(v),
            ),
          ),
        ],
      ),
    );
  }
}

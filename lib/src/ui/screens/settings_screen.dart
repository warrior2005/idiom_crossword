import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../audio/music_manager.dart';
import '../../audio/sound_manager.dart';
import '../../state/daily_reminder.dart';
import '../../state/database_provider.dart';
import '../app_page_route.dart';
import '../widgets/sub_page_header.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'legal_screen.dart';

const String soundEnabledKey = 'sound_enabled';
const String musicEnabledKey = 'music_enabled';
const String hapticEnabledKey = 'haptic_enabled';
const String showPinyinKey = 'show_pinyin';

/// 音效开关（持久化到 settings 表）
final soundEnabledProvider = AsyncNotifierProvider<SoundSettingNotifier, bool>(
  SoundSettingNotifier.new,
);

class SoundSettingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final db = ref.watch(databaseProvider);
    final value = await db.getSetting(soundEnabledKey);
    final enabled = value != 'false';
    SoundManager.instance.setEnabled(enabled);
    return enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    SoundManager.instance.setEnabled(enabled);
    await ref
        .read(databaseProvider)
        .setSetting(soundEnabledKey, enabled.toString());
    state = AsyncData(enabled);
  }
}

/// 背景音乐开关（持久化到 settings 表）
final musicEnabledProvider = AsyncNotifierProvider<MusicSettingNotifier, bool>(
  MusicSettingNotifier.new,
);

class MusicSettingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final db = ref.watch(databaseProvider);
    final value = await db.getSetting(musicEnabledKey);
    final enabled = value != 'false';
    await MusicManager.instance.setMusicEnabled(enabled);
    return enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    await MusicManager.instance.setMusicEnabled(enabled);
    await ref
        .read(databaseProvider)
        .setSetting(musicEnabledKey, enabled.toString());
    state = AsyncData(enabled);
  }
}

/// 触感反馈开关
final hapticEnabledProvider =
    AsyncNotifierProvider<HapticSettingNotifier, bool>(
      HapticSettingNotifier.new,
    );

class HapticSettingNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final db = ref.watch(databaseProvider);
    final value = await db.getSetting(hapticEnabledKey);
    return value != 'false';
  }

  Future<void> setEnabled(bool enabled) async {
    await ref
        .read(databaseProvider)
        .setSetting(hapticEnabledKey, enabled.toString());
    state = AsyncData(enabled);
  }
}

/// 通用布尔设置（仅持久化）
class PrefSettingNotifier extends AsyncNotifier<bool> {
  final String key;
  final bool defaultValue;
  PrefSettingNotifier(this.key, {this.defaultValue = true});

  @override
  Future<bool> build() async {
    final db = ref.watch(databaseProvider);
    final value = await db.getSetting(key);
    return value == null ? defaultValue : value == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(databaseProvider).setSetting(key, enabled.toString());
    state = AsyncData(enabled);
  }
}

final showPinyinProvider = AsyncNotifierProvider<PrefSettingNotifier, bool>(
  () => PrefSettingNotifier(showPinyinKey),
);

final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.version;
});

/// 设置界面
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: SubPageHeader(title: '设置'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  _Group(
                    children: const [_MusicRow(), _SoundRow(), _HapticRow()],
                  ),
                  _Group(
                    children: const [
                      _PinyinRow(),
                      _ReminderRow(),
                      _ReminderTimeRow(),
                    ],
                  ),
                  _Group(
                    children: [
                      _ValueRow(
                        title: '当前版本',
                        value: version == null ? '—' : 'v$version',
                      ),
                      _TapRow(
                        title: '用户协议与隐私',
                        onTap: () => Navigator.of(context).push(
                          AppPageRoute<void>(
                            builder: (_) => const LegalScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicRow extends ConsumerWidget {
  const _MusicRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(musicEnabledProvider).value ?? true;
    return _SwitchRow(
      title: '音乐',
      sub: '页面与填字游戏背景音乐',
      value: enabled,
      onChanged: (value) =>
          ref.read(musicEnabledProvider.notifier).setEnabled(value),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(children: children),
    );
  }
}

class _SoundRow extends ConsumerWidget {
  const _SoundRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(soundEnabledProvider).value ?? true;
    return _SwitchRow(
      title: '音效',
      sub: '填字、成语完成与过关音效',
      value: enabled,
      onChanged: (v) => ref.read(soundEnabledProvider.notifier).setEnabled(v),
    );
  }
}

class _HapticRow extends ConsumerWidget {
  const _HapticRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(hapticEnabledProvider).value ?? true;
    return _SwitchRow(
      title: '触感反馈',
      sub: '填入正确字时的轻震动',
      value: enabled,
      onChanged: (v) => ref.read(hapticEnabledProvider.notifier).setEnabled(v),
    );
  }
}

class _PinyinRow extends ConsumerWidget {
  const _PinyinRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(showPinyinProvider).value ?? true;
    return _SwitchRow(
      title: '显示拼音',
      sub: '网格下方小字标注',
      value: enabled,
      onChanged: (v) => ref.read(showPinyinProvider.notifier).setEnabled(v),
    );
  }
}

class _ReminderRow extends ConsumerWidget {
  const _ReminderRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminder = ref.watch(dailyReminderProvider).value;
    final eligible = reminder?.eligible ?? false;
    return _SwitchRow(
      title: '每日提醒',
      sub: eligible ? '每天 ${reminder!.formattedTime} 提醒' : '完成首次每日挑战后开启',
      value: reminder?.enabled ?? false,
      onChanged: eligible
          ? (enabled) => _setEnabled(context, ref, enabled)
          : null,
    );
  }

  Future<void> _setEnabled(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final notifier = ref.read(dailyReminderProvider.notifier);
    if (!enabled) {
      await notifier.disable();
      return;
    }
    DailyReminderEnableResult result;
    try {
      result = await notifier.enableFromSettings();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('提醒设置失败，请稍后重试')));
      }
      return;
    }
    if (!context.mounted) return;
    if (result == DailyReminderEnableResult.needsSystemSettings) {
      final open = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('开启每日提醒'),
          content: const Text('通知权限已关闭，请前往 iOS 系统设置允许通知。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('前往系统设置'),
            ),
          ],
        ),
      );
      if (open == true) await notifier.openSystemSettings();
    } else if (result == DailyReminderEnableResult.unavailable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前设备不支持每日通知')));
    }
  }
}

class _ReminderTimeRow extends ConsumerWidget {
  const _ReminderTimeRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminder = ref.watch(dailyReminderProvider).value;
    final eligible = reminder?.eligible ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: eligible && reminder != null
          ? () => _selectTime(context, ref, reminder)
          : null,
      child: _Row(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '提醒时间',
              style: bodyStyle(
                size: 14.5,
                weight: FontWeight.w600,
                color: eligible ? AppColors.fg : AppColors.faint,
              ),
            ),
            Text(
              reminder?.formattedTime ?? '12:00',
              style: bodyStyle(
                size: 13,
                color: eligible ? AppColors.muted : AppColors.faint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(
    BuildContext context,
    WidgetRef ref,
    DailyReminderState reminder,
  ) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: reminder.hour, minute: reminder.minute),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (selected == null) return;
    await ref
        .read(dailyReminderProvider.notifier)
        .setTime(hour: selected.hour, minute: selected.minute);
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String sub;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _SwitchRow({
    required this.title,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Row(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: bodyStyle(size: 14.5, weight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(sub, style: bodyStyle(size: 11.5, color: AppColors.muted)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: AppColors.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String title;
  final String value;
  const _ValueRow({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return _Row(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: bodyStyle(size: 14.5, weight: FontWeight.w600)),
          Text(value, style: bodyStyle(size: 13, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _TapRow extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _TapRow({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _Row(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: bodyStyle(size: 14.5, weight: FontWeight.w600)),
            const Text(
              '›',
              style: TextStyle(fontSize: 16, color: AppColors.faint),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final Widget child;
  const _Row({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: child,
    );
  }
}

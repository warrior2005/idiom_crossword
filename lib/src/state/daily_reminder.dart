import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/daily_reminder_platform.dart';
import 'database_provider.dart';
import 'level_generation.dart';

const String dailyReminderEnabledKey = 'daily_reminder';
const String dailyReminderEligibleKey = 'daily_reminder_eligible';
const String dailyReminderPromptedKey = 'daily_reminder_prompted';
const String dailyReminderHourKey = 'daily_reminder_hour';
const String dailyReminderMinuteKey = 'daily_reminder_minute';
const int defaultDailyReminderHour = 12;
const int defaultDailyReminderMinute = 0;

enum DailyReminderEnableResult {
  enabled,
  permissionDenied,
  needsSystemSettings,
  unavailable,
}

class DailyReminderState {
  final bool eligible;
  final bool prompted;
  final bool enabled;
  final int hour;
  final int minute;
  final NotificationAuthorization authorization;

  const DailyReminderState({
    required this.eligible,
    required this.prompted,
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.authorization,
  });

  String get formattedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  DailyReminderState copyWith({
    bool? eligible,
    bool? prompted,
    bool? enabled,
    int? hour,
    int? minute,
    NotificationAuthorization? authorization,
  }) {
    return DailyReminderState(
      eligible: eligible ?? this.eligible,
      prompted: prompted ?? this.prompted,
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      authorization: authorization ?? this.authorization,
    );
  }
}

final dailyReminderProvider =
    AsyncNotifierProvider<DailyReminderNotifier, DailyReminderState>(
      DailyReminderNotifier.new,
    );

class DailyReminderNotifier extends AsyncNotifier<DailyReminderState> {
  bool _enableAfterSystemSettings = false;

  @override
  Future<DailyReminderState> build() async {
    final db = ref.watch(databaseProvider);
    final values = await (
      db.getSetting(dailyReminderEnabledKey),
      db.getSetting(dailyReminderEligibleKey),
      db.getSetting(dailyReminderPromptedKey),
      db.getSetting(dailyReminderHourKey),
      db.getSetting(dailyReminderMinuteKey),
      db.getLevelHistory(),
    ).wait;
    final authorization = await ref
        .read(dailyReminderPlatformProvider)
        .getAuthorizationStatus();
    final eligible =
        values.$2 == 'true' ||
        values.$6.any((history) => history.levelNumber >= dailyLevelOffset);
    final hour =
        int.tryParse(values.$4 ?? '')?.clamp(0, 23) ?? defaultDailyReminderHour;
    final minute =
        int.tryParse(values.$5 ?? '')?.clamp(0, 59) ??
        defaultDailyReminderMinute;
    final enabled = eligible && values.$1 == 'true' && authorization.canNotify;

    if (values.$1 == 'true' && !enabled) {
      await db.setSetting(dailyReminderEnabledKey, 'false');
    }
    if (enabled) {
      await ref
          .read(dailyReminderPlatformProvider)
          .scheduleDailyReminder(hour: hour, minute: minute);
    }
    return DailyReminderState(
      eligible: eligible,
      prompted: values.$3 == 'true',
      enabled: enabled,
      hour: hour,
      minute: minute,
      authorization: authorization,
    );
  }

  Future<bool> unlockAndMarkPrompted() async {
    var current = state.value;
    if (current == null) return false;
    final db = ref.read(databaseProvider);
    if (!current.eligible) {
      await db.setSetting(dailyReminderEligibleKey, 'true');
      current = current.copyWith(eligible: true);
      state = AsyncData(current);
    }
    if (current.authorization == NotificationAuthorization.unsupported) {
      return false;
    }
    if (current.prompted) return false;
    await db.setSetting(dailyReminderPromptedKey, 'true');
    state = AsyncData(current.copyWith(prompted: true));
    return true;
  }

  Future<bool> requestPermissionAndEnable() async {
    final current = state.value;
    if (current == null) return false;
    var authorization = await ref
        .read(dailyReminderPlatformProvider)
        .getAuthorizationStatus();
    if (authorization == NotificationAuthorization.notDetermined) {
      authorization = await ref
          .read(dailyReminderPlatformProvider)
          .requestAuthorization();
    }
    if (!authorization.canNotify) {
      await _setDisabled(authorization);
      return false;
    }
    await _setEnabled(current, authorization);
    return true;
  }

  Future<DailyReminderEnableResult> enableFromSettings() async {
    final current = state.value;
    if (current == null || !current.eligible) {
      return DailyReminderEnableResult.unavailable;
    }
    var authorization = await ref
        .read(dailyReminderPlatformProvider)
        .getAuthorizationStatus();
    if (authorization == NotificationAuthorization.denied) {
      state = AsyncData(current.copyWith(authorization: authorization));
      return DailyReminderEnableResult.needsSystemSettings;
    }
    if (authorization == NotificationAuthorization.notDetermined) {
      authorization = await ref
          .read(dailyReminderPlatformProvider)
          .requestAuthorization();
      if (authorization == NotificationAuthorization.denied) {
        await _setDisabled(authorization);
        return DailyReminderEnableResult.permissionDenied;
      }
    }
    if (!authorization.canNotify) {
      await _setDisabled(authorization);
      return authorization == NotificationAuthorization.denied
          ? DailyReminderEnableResult.needsSystemSettings
          : DailyReminderEnableResult.unavailable;
    }
    await _setEnabled(current, authorization);
    return DailyReminderEnableResult.enabled;
  }

  Future<void> disable() async {
    final current = state.value;
    if (current == null) return;
    await _setDisabled(current.authorization);
  }

  Future<void> setTime({required int hour, required int minute}) async {
    final current = state.value;
    if (current == null) return;
    final db = ref.read(databaseProvider);
    await db.setSetting(dailyReminderHourKey, '$hour');
    await db.setSetting(dailyReminderMinuteKey, '$minute');
    final updated = current.copyWith(hour: hour, minute: minute);
    state = AsyncData(updated);
    if (updated.enabled) {
      await ref
          .read(dailyReminderPlatformProvider)
          .scheduleDailyReminder(hour: hour, minute: minute);
    }
  }

  Future<void> openSystemSettings() async {
    _enableAfterSystemSettings = true;
    await ref.read(dailyReminderPlatformProvider).openNotificationSettings();
  }

  Future<void> syncAuthorization() async {
    final current = state.value;
    if (current == null) return;
    final authorization = await ref
        .read(dailyReminderPlatformProvider)
        .getAuthorizationStatus();
    if (_enableAfterSystemSettings && authorization.canNotify) {
      _enableAfterSystemSettings = false;
      await _setEnabled(current, authorization);
      return;
    }
    if (current.enabled && !authorization.canNotify) {
      await _setDisabled(authorization);
      return;
    }
    state = AsyncData(current.copyWith(authorization: authorization));
  }

  Future<void> _setEnabled(
    DailyReminderState current,
    NotificationAuthorization authorization,
  ) async {
    await ref
        .read(dailyReminderPlatformProvider)
        .scheduleDailyReminder(hour: current.hour, minute: current.minute);
    await ref
        .read(databaseProvider)
        .setSetting(dailyReminderEnabledKey, 'true');
    state = AsyncData(
      current.copyWith(enabled: true, authorization: authorization),
    );
  }

  Future<void> _setDisabled(NotificationAuthorization authorization) async {
    await ref.read(dailyReminderPlatformProvider).cancelDailyReminder();
    await ref
        .read(databaseProvider)
        .setSetting(dailyReminderEnabledKey, 'false');
    final current = state.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(enabled: false, authorization: authorization),
      );
    }
  }
}

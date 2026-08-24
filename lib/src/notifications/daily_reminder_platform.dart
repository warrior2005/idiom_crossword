import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NotificationAuthorization {
  notDetermined,
  denied,
  authorized,
  provisional,
  ephemeral,
  unsupported;

  bool get canNotify =>
      this == authorized || this == provisional || this == ephemeral;
}

abstract interface class DailyReminderPlatform {
  Future<NotificationAuthorization> getAuthorizationStatus();

  Future<NotificationAuthorization> requestAuthorization();

  Future<void> scheduleDailyReminder({required int hour, required int minute});

  Future<void> cancelDailyReminder();

  Future<bool> openNotificationSettings();
}

final dailyReminderPlatformProvider = Provider<DailyReminderPlatform>(
  (ref) => const MethodChannelDailyReminderPlatform(),
);

class MethodChannelDailyReminderPlatform implements DailyReminderPlatform {
  static const _channel = MethodChannel('idiom_crossword/daily_reminder');

  const MethodChannelDailyReminderPlatform();

  @override
  Future<NotificationAuthorization> getAuthorizationStatus() async {
    try {
      final value = await _channel.invokeMethod<String>('authorizationStatus');
      return _authorizationFromString(value);
    } on MissingPluginException {
      return NotificationAuthorization.unsupported;
    }
  }

  @override
  Future<NotificationAuthorization> requestAuthorization() async {
    try {
      final value = await _channel.invokeMethod<String>('requestAuthorization');
      return _authorizationFromString(value);
    } on MissingPluginException {
      return NotificationAuthorization.unsupported;
    }
  }

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    try {
      await _channel.invokeMethod<void>('scheduleDaily', {
        'hour': hour,
        'minute': minute,
      });
    } on MissingPluginException {
      // 仅 iOS 支持每日通知。
    }
  }

  @override
  Future<void> cancelDailyReminder() async {
    try {
      await _channel.invokeMethod<void>('cancelDaily');
    } on MissingPluginException {
      // 仅 iOS 支持每日通知。
    }
  }

  @override
  Future<bool> openNotificationSettings() async {
    try {
      return await _channel.invokeMethod<bool>('openSettings') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  NotificationAuthorization _authorizationFromString(String? value) {
    return switch (value) {
      'notDetermined' => NotificationAuthorization.notDetermined,
      'denied' => NotificationAuthorization.denied,
      'authorized' => NotificationAuthorization.authorized,
      'provisional' => NotificationAuthorization.provisional,
      'ephemeral' => NotificationAuthorization.ephemeral,
      _ => NotificationAuthorization.unsupported,
    };
  }
}

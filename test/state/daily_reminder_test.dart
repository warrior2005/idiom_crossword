import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/notifications/daily_reminder_platform.dart';
import 'package:idiom_crossword/src/state/daily_reminder.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';

void main() {
  test('首次完成每日挑战后只主动请求一次，授权后默认每天12点提醒', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final platform = _FakeDailyReminderPlatform(
      requestResult: NotificationAuthorization.authorized,
    );
    final container = _container(db, platform);
    addTearDown(container.dispose);

    final initial = await container.read(dailyReminderProvider.future);
    expect(initial.eligible, isFalse);
    expect(initial.enabled, isFalse);
    expect((initial.hour, initial.minute), (12, 0));

    final notifier = container.read(dailyReminderProvider.notifier);
    expect(await notifier.unlockAndMarkPrompted(), isTrue);
    expect(await notifier.unlockAndMarkPrompted(), isFalse);
    expect(await notifier.requestPermissionAndEnable(), isTrue);

    expect(platform.requestCount, 1);
    expect(platform.scheduledTimes, [(12, 0)]);
    expect(await db.getSetting(dailyReminderEnabledKey), 'true');
    expect(await db.getSetting(dailyReminderEligibleKey), 'true');
    expect(await db.getSetting(dailyReminderPromptedKey), 'true');
  });

  test('系统权限被拒绝后，手动开启只要求跳转系统设置', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.setSetting(dailyReminderEligibleKey, 'true');
    await db.setSetting(dailyReminderPromptedKey, 'true');
    final platform = _FakeDailyReminderPlatform(
      authorization: NotificationAuthorization.denied,
    );
    final container = _container(db, platform);
    addTearDown(container.dispose);
    await container.read(dailyReminderProvider.future);

    final notifier = container.read(dailyReminderProvider.notifier);
    expect(
      await notifier.enableFromSettings(),
      DailyReminderEnableResult.needsSystemSettings,
    );
    expect(platform.requestCount, 0);

    await notifier.openSystemSettings();
    expect(platform.openSettingsCount, 1);
    platform.authorization = NotificationAuthorization.authorized;
    await notifier.syncAuthorization();
    expect(container.read(dailyReminderProvider).value?.enabled, isTrue);
    expect(platform.scheduledTimes, [(12, 0)]);
  });

  test('尚未决定权限时，用户在设置中主动开启才请求权限', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.setSetting(dailyReminderEligibleKey, 'true');
    await db.setSetting(dailyReminderPromptedKey, 'true');
    final platform = _FakeDailyReminderPlatform(
      requestResult: NotificationAuthorization.authorized,
    );
    final container = _container(db, platform);
    addTearDown(container.dispose);
    await container.read(dailyReminderProvider.future);

    final result = await container
        .read(dailyReminderProvider.notifier)
        .enableFromSettings();

    expect(result, DailyReminderEnableResult.enabled);
    expect(platform.requestCount, 1);
    expect(platform.scheduledTimes, [(12, 0)]);
  });

  test('设置中首次请求被拒后保持关闭，再次开启才引导系统设置', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.setSetting(dailyReminderEligibleKey, 'true');
    final platform = _FakeDailyReminderPlatform();
    final container = _container(db, platform);
    addTearDown(container.dispose);
    await container.read(dailyReminderProvider.future);
    final notifier = container.read(dailyReminderProvider.notifier);

    expect(
      await notifier.enableFromSettings(),
      DailyReminderEnableResult.permissionDenied,
    );
    expect(container.read(dailyReminderProvider).value?.enabled, isFalse);
    expect(platform.requestCount, 1);

    expect(
      await notifier.enableFromSettings(),
      DailyReminderEnableResult.needsSystemSettings,
    );
    expect(platform.requestCount, 1);
  });

  test('修改提醒时间后持久化并重新调度', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.setSetting(dailyReminderEligibleKey, 'true');
    await db.setSetting(dailyReminderEnabledKey, 'true');
    final platform = _FakeDailyReminderPlatform(
      authorization: NotificationAuthorization.authorized,
    );
    final container = _container(db, platform);
    addTearDown(container.dispose);
    await container.read(dailyReminderProvider.future);

    await container
        .read(dailyReminderProvider.notifier)
        .setTime(hour: 8, minute: 35);

    expect(platform.scheduledTimes.last, (8, 35));
    expect(await db.getSetting(dailyReminderHourKey), '8');
    expect(await db.getSetting(dailyReminderMinuteKey), '35');
  });
}

ProviderContainer _container(AppDatabase db, DailyReminderPlatform platform) {
  return ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      dailyReminderPlatformProvider.overrideWithValue(platform),
    ],
  );
}

class _FakeDailyReminderPlatform implements DailyReminderPlatform {
  NotificationAuthorization authorization;
  final NotificationAuthorization requestResult;
  int requestCount = 0;
  int openSettingsCount = 0;
  final List<(int, int)> scheduledTimes = [];

  _FakeDailyReminderPlatform({
    this.authorization = NotificationAuthorization.notDetermined,
    this.requestResult = NotificationAuthorization.denied,
  });

  @override
  Future<void> cancelDailyReminder() async {}

  @override
  Future<NotificationAuthorization> getAuthorizationStatus() async =>
      authorization;

  @override
  Future<bool> openNotificationSettings() async {
    openSettingsCount++;
    return true;
  }

  @override
  Future<NotificationAuthorization> requestAuthorization() async {
    requestCount++;
    authorization = requestResult;
    return authorization;
  }

  @override
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
  }) async {
    scheduledTimes.add((hour, minute));
  }
}

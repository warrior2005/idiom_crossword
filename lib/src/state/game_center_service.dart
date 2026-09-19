import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import '../data/achievement_manager.dart';
import '../data/database.dart';

/// Game Center 登录与成就同步。非 iOS 和服务不可用时保留本地进度。
class GameCenterService {
  static const signInTimeout = Duration(seconds: 8);
  static Future<bool>? _signInFuture;
  static Future<void>? _syncFuture;
  static Timer? _retryTimer;
  static Duration _retryDelay = const Duration(seconds: 30);
  static const _maxRetryDelay = Duration(minutes: 5);

  static void _scheduleRetry() {
    if (_retryTimer != null) return;
    _retryTimer = Timer(_retryDelay, () {
      _retryTimer = null;
      unawaited(ensureSignedIn());
    });
    _retryDelay = Duration(
      seconds: (_retryDelay.inSeconds * 2).clamp(30, _maxRetryDelay.inSeconds),
    );
  }

  static void _stopRetrying() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryDelay = const Duration(seconds: 30);
  }

  @visibleForTesting
  static void resetForTesting() {
    _stopRetrying();
    _signInFuture = null;
    _syncFuture = null;
  }

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// 自动上报只读取当前登录状态，不能在游戏中触发原生登录流程。
  static Future<bool> isSignedIn() async {
    if (!isSupported) return false;
    try {
      // first 在超时后也会取消订阅，避免原生事件未返回时遗留监听。
      final signedIn = await GameAuth.player
          .timeout(signInTimeout)
          .map((player) => player != null)
          .first;
      if (signedIn) _stopRetrying();
      return signedIn;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> ensureSignedIn({Duration timeout = signInTimeout}) async {
    if (!isSupported) return false;
    // 所有调用方共用退避窗口，避免通关、成就和云备份重复拉起登录。
    if (_retryTimer != null) {
      return isSignedIn().timeout(timeout, onTimeout: () => false);
    }
    final existing = _signInFuture;
    final Future<bool> pending;
    if (existing != null) {
      pending = existing;
    } else {
      pending = _signIn();
      _signInFuture = pending;
      unawaited(
        pending.then((signedIn) {
          if (!identical(_signInFuture, pending)) return;
          if (signedIn) {
            _stopRetrying();
          } else {
            _signInFuture = null;
            _scheduleRetry();
          }
        }),
      );
    }
    return pending.timeout(
      timeout,
      onTimeout: () {
        debugPrint('Game Center sign-in timed out after $timeout.');
        return false;
      },
    );
  }

  static Future<bool> _signIn() async {
    try {
      if (await isSignedIn()) return true;
      await GameAuth.signIn();
      return await isSignedIn();
    } catch (error) {
      debugPrint('Game Center sign-in failed: $error');
      return false;
    }
  }

  /// 将 Game Center 和本地缓存双向补齐，兼容离线解锁与换机恢复。
  static Future<void> syncAchievements(AppDatabase db) {
    final pending = _syncFuture ??= _syncAchievements(db);
    return pending.whenComplete(() {
      if (identical(_syncFuture, pending)) _syncFuture = null;
    });
  }

  static Future<void> _syncAchievements(AppDatabase db) async {
    await _backfillLocalAchievements(db);
    if (!await ensureSignedIn()) return;
    try {
      final localIds = await db.getUnlockedAchievementIds();
      final remote = await Achievements.loadAchievements(ignoreImages: true);
      final remoteUnlocked = {
        for (final item in remote ?? const [])
          if (item.unlocked) item.id,
      };

      for (final definition in achievementDefs) {
        if (remoteUnlocked.contains(definition.gameCenterId) &&
            !localIds.contains(definition.id.name)) {
          await db.unlockAchievement(definition.id.name);
        }
        if (localIds.contains(definition.id.name) &&
            !remoteUnlocked.contains(definition.gameCenterId)) {
          await _report(definition);
        }
      }
    } catch (_) {
      // Game Center 临时不可用不影响本地成就。
    }
  }

  /// 依据旧存档重新判定，确保新增的长期成就无需再通一关才生效。
  static Future<void> _backfillLocalAchievements(AppDatabase db) async {
    try {
      final progress = await db.getPlayerProgress();
      final history = await db.getLevelHistory();
      final unlockedNames = await db.getUnlockedAchievementIds();
      final unlocked = {
        for (final id in AchievementId.values)
          if (unlockedNames.contains(id.name)) id,
      };
      final newly = AchievementManager.evaluateOnLevelComplete(
        alreadyUnlocked: unlocked,
        totalCompleted: (await db.getCompletedLevelNumbers()).length,
        noHintCompletions: history.where((item) => item.hintsUsed == 0).length,
        flawlessCompletions: history
            .where((item) => item.errorsMade == 0)
            .length,
        dailyCompletions: history
            .where((item) => item.levelNumber >= 1000000)
            .length,
        totalXp: progress?.totalXp ?? 0,
        collectionCount: await db.getCollectionCount(),
      );
      newly.addAll(
        AchievementManager.evaluateStreak(
          alreadyUnlocked: unlocked,
          streak: progress?.bestCorrectStreak ?? 0,
        ),
      );
      for (final id in newly) {
        await db.unlockAchievement(id.name);
      }
    } catch (_) {
      // 存档不可用时不阻塞启动。
    }
  }

  /// 本地先落盘，再异步上报 Game Center；返回是否为本次新解锁。
  static Future<bool> unlockAchievement(
    AppDatabase db,
    AchievementId id,
  ) async {
    final unlocked = await db.getUnlockedAchievementIds();
    if (unlocked.contains(id.name)) return false;
    await db.unlockAchievement(id.name);
    unawaited(reportAchievement(id));
    return true;
  }

  static Future<void> reportAchievement(AchievementId id) async {
    if (!await isSignedIn()) return;
    try {
      await _report(achievementDefFor(id));
    } catch (_) {
      // 下次同步时补报。
    }
  }

  static Future<void> _report(AchievementDef definition) => Achievements.unlock(
    achievement: Achievement(
      iOSID: definition.gameCenterId,
      showsCompletionBanner: false,
      percentComplete: 100,
    ),
  );
}

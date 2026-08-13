import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

import '../data/achievement_manager.dart';
import '../data/database.dart';

/// Game Center 登录与成就同步。非 iOS 和服务不可用时保留本地进度。
class GameCenterService {
  static Future<bool>? _signInFuture;
  static Future<void>? _syncFuture;

  static bool get isSupported => !kIsWeb && Platform.isIOS;

  static Future<bool> ensureSignedIn() async {
    if (!isSupported) return false;
    final pending = _signInFuture ??= _signIn();
    final signedIn = await pending;
    if (!signedIn) _signInFuture = null;
    return signedIn;
  }

  static Future<bool> _signIn() async {
    try {
      await GameAuth.signIn();
      return await GameAuth.isSignedIn;
    } catch (_) {
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
    if (!await ensureSignedIn()) return;
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

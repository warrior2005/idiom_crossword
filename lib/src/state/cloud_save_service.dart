import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:games_services/games_services.dart';

import '../data/database.dart';
import '../data/player_save_repository.dart';
import 'game_center_service.dart';

enum CloudRestoreOutcome {
  existingLocalSave,
  restored,
  noCloudSave,
  unavailable,
}

extension CloudRestoreOutcomeState on CloudRestoreOutcome {
  bool get canBackUp => this != CloudRestoreOutcome.unavailable;
}

/// GameKit Saved Games 云存档。定位为卸载恢复，不处理多设备实时合并。
class CloudSaveService {
  static const String saveName = 'player_snapshot_v1';
  static String? _lastFingerprint;
  static Future<void>? _backupFuture;

  static Future<CloudRestoreOutcome> restoreIfNeeded(AppDatabase db) async {
    if (!GameCenterService.isSupported) {
      return CloudRestoreOutcome.unavailable;
    }
    if (!await PlayerSaveRepository.isLocalSaveEmpty(db)) {
      return CloudRestoreOutcome.existingLocalSave;
    }
    if (!await GameCenterService.ensureSignedIn()) {
      return CloudRestoreOutcome.unavailable;
    }
    try {
      final saves = await SaveGame.getSavedGames(ignoreImages: true);
      if (saves == null || !saves.any((save) => save.name == saveName)) {
        return CloudRestoreOutcome.noCloudSave;
      }
      final data = await SaveGame.loadGame(name: saveName);
      if (data == null || data.isEmpty) return CloudRestoreOutcome.unavailable;
      await PlayerSaveRepository.importJson(db, data);
      return CloudRestoreOutcome.restored;
    } catch (_) {
      // 读取或解析失败时绝不以本地空档覆盖云端旧存档。
      return CloudRestoreOutcome.unavailable;
    }
  }

  static Future<void> backUpIfChanged(AppDatabase db) {
    final pending = _backupFuture ??= _backUpIfChanged(db);
    return pending.whenComplete(() {
      if (identical(_backupFuture, pending)) _backupFuture = null;
    });
  }

  static Future<void> _backUpIfChanged(AppDatabase db) async {
    if (!GameCenterService.isSupported ||
        await PlayerSaveRepository.isLocalSaveEmpty(db) ||
        !await GameCenterService.ensureSignedIn()) {
      return;
    }
    try {
      final snapshot = await PlayerSaveRepository.exportSnapshot(db);
      final comparable = Map<String, dynamic>.from(snapshot)..remove('savedAt');
      final fingerprint = jsonEncode(comparable);
      if (fingerprint == _lastFingerprint) return;
      await SaveGame.saveGame(data: jsonEncode(snapshot), name: saveName);
      _lastFingerprint = fingerprint;
    } catch (_) {
      // 云端暂不可用时保留本地数据，后续定时或进后台时重试。
    }
  }
}

/// 定时检测本地变化，并在进入后台时补一次云存档。
class CloudSaveCoordinator with WidgetsBindingObserver {
  final AppDatabase db;
  Timer? _timer;

  CloudSaveCoordinator(this.db);

  void start() {
    if (kIsWeb || _timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(CloudSaveService.backUpIfChanged(db));
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(CloudSaveService.backUpIfChanged(db));
    }
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:games_services/games_services.dart';

import '../data/database.dart';
import '../data/player_save_repository.dart';
import 'game_center_service.dart';

enum CloudSaveDownloadStatus { available, noCloudSave, unavailable }

class CloudSaveDownloadResult {
  final CloudSaveDownloadStatus status;
  final String? data;

  const CloudSaveDownloadResult._(this.status, [this.data]);

  const CloudSaveDownloadResult.available(String data)
    : this._(CloudSaveDownloadStatus.available, data);

  const CloudSaveDownloadResult.noCloudSave()
    : this._(CloudSaveDownloadStatus.noCloudSave);

  const CloudSaveDownloadResult.unavailable()
    : this._(CloudSaveDownloadStatus.unavailable);
}

/// GameKit Saved Games 云存档。定位为卸载恢复，不处理多设备实时合并。
class CloudSaveService {
  static const String saveName = 'player_snapshot_v1';
  static const restoreNetworkTimeout = Duration(seconds: 30);
  static String? _lastFingerprint;
  static Future<void>? _backupFuture;

  /// 只下载云档，不写数据库。调用方可安全丢弃超时后迟到的结果。
  static Future<CloudSaveDownloadResult> downloadCloudSave({
    Duration timeout = restoreNetworkTimeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    Duration remaining() {
      final value = timeout - stopwatch.elapsed;
      if (value <= Duration.zero) {
        throw TimeoutException('Cloud save restore timed out');
      }
      return value;
    }

    try {
      if (!GameCenterService.isSupported) {
        return const CloudSaveDownloadResult.unavailable();
      }
      if (!await GameCenterService.ensureSignedIn(timeout: remaining())) {
        return const CloudSaveDownloadResult.unavailable();
      }
      final saves = await SaveGame.getSavedGames(
        ignoreImages: true,
      ).timeout(remaining());
      if (saves == null || !saves.any((save) => save.name == saveName)) {
        return const CloudSaveDownloadResult.noCloudSave();
      }
      final data = await SaveGame.loadGame(name: saveName).timeout(remaining());
      if (data == null || data.isEmpty) {
        return const CloudSaveDownloadResult.unavailable();
      }
      return CloudSaveDownloadResult.available(data);
    } catch (_) {
      return const CloudSaveDownloadResult.unavailable();
    }
  }

  static Future<void> importCloudSave(AppDatabase db, String data) {
    return PlayerSaveRepository.importJson(db, data);
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

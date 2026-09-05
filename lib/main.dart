import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'src/data/database.dart';
import 'src/data/player_save_repository.dart';
import 'src/state/database_provider.dart';
import 'src/state/daily_reminder.dart';
import 'src/state/player_state.dart';
import 'src/state/game_center_service.dart';
import 'src/state/leaderboard_service.dart';
import 'src/state/cloud_save_service.dart';
import 'src/state/collection_provider.dart';
import 'src/utils/ad_manager.dart';
import 'src/ui/screens/root_screen.dart';
import 'src/audio/music_manager.dart';
import 'src/audio/audio_route_observer.dart';
import 'src/audio/sound_manager.dart';
import 'src/ui/screens/settings_screen.dart';
import 'src/ui/theme/app_text.dart';
import 'src/ui/widgets/first_launch_dialog.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // iOS 锁定竖屏
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // iOS 状态栏样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // 初始化广告 SDK（横幅/插页式激励/激励广告在各自页面加载）
  unawaited(AdManager().initialize());

  // 先加载已保存的玩家进度，避免启动后闪回默认值
  final container = ProviderContainer();
  final db = container.read(databaseProvider);
  var isSoundEnabled = true;
  var isMusicEnabled = true;
  var needsSaveChoice = false;
  String? currentAppVersion;
  try {
    final (_, soundEnabled, musicEnabled, localSaveEmpty) = await (
      container.read(playerProvider.notifier).loadFromDatabase(db),
      db.getSetting(soundEnabledKey),
      db.getSetting(musicEnabledKey),
      PlayerSaveRepository.isLocalSaveEmpty(db),
    ).wait;
    isSoundEnabled = soundEnabled != 'false';
    isMusicEnabled = musicEnabled != 'false';
    needsSaveChoice = localSaveEmpty;
  } catch (_) {
    // 数据库不可用时以默认进度启动，进入游戏时会给出错误提示
  }
  try {
    final info = await PackageInfo.fromPlatform();
    currentAppVersion = '${info.version}+${info.buildNumber}';
  } catch (_) {
    // 版本信息不可用时跳过本次更新奖励检查。
  }
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: IdiomCrosswordApp(
        home: CloudSaveBootstrap(
          db: db,
          needsSaveChoice: needsSaveChoice,
          currentAppVersion: currentAppVersion,
        ),
      ),
    ),
  );

  // 音频插件无响应时不能挡住首屏渲染。
  unawaited(
    _initializeAudio(
      musicEnabled: isMusicEnabled,
      soundEnabled: isSoundEnabled,
    ),
  );
}

Future<void> _initializeAudio({
  required bool musicEnabled,
  required bool soundEnabled,
}) async {
  await MusicManager.instance.init(
    musicEnabled: musicEnabled,
    soundEnabled: soundEnabled,
  );
  await SoundManager.instance.init(enabled: soundEnabled);
}

class IdiomCrosswordApp extends StatelessWidget {
  final Widget? home;

  const IdiomCrosswordApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '成语接龙',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [appRouteObserver],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB33B27),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3EDE1),
        fontFamily: kSans,
        fontFamilyFallback: const ['PingFang SC', 'Songti SC'],
      ),
      home: home ?? const RootScreen(),
    );
  }
}

class CloudSaveBootstrap extends ConsumerStatefulWidget {
  final AppDatabase db;
  final bool needsSaveChoice;
  final String? currentAppVersion;
  final CloudSaveDownloader? downloadCloudSave;
  final CloudSaveImporter? importCloudSave;
  final NewGameStarter? startNewGame;
  final Duration restoreTimeout;

  const CloudSaveBootstrap({
    super.key,
    required this.db,
    required this.needsSaveChoice,
    this.currentAppVersion,
    this.downloadCloudSave,
    this.importCloudSave,
    this.startNewGame,
    this.restoreTimeout = const Duration(seconds: 30),
  });

  @override
  ConsumerState<CloudSaveBootstrap> createState() => _CloudSaveBootstrapState();
}

class _CloudSaveBootstrapState extends ConsumerState<CloudSaveBootstrap> {
  CloudSaveCoordinator? _coordinator;
  late final AppLifecycleListener _lifecycleListener;
  late bool _waitingForSaveChoice;
  var _servicesStarted = false;

  @override
  void initState() {
    super.initState();
    _waitingForSaveChoice = widget.needsSaveChoice;
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (!_waitingForSaveChoice) {
          unawaited(_syncDailyReminderAuthorization());
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_waitingForSaveChoice) {
        unawaited(_showFirstLaunchDialog());
      } else {
        _startOnlineServices();
      }
    });
  }

  Future<void> _showFirstLaunchDialog() async {
    final choice = await showDialog<FirstLaunchChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FirstLaunchDialog(
        downloadCloudSave: _downloadCloudSave,
        importCloudSave: _importCloudSave,
        startNewGame: _startNewGame,
        restoreTimeout: widget.restoreTimeout,
      ),
    );
    if (!mounted || choice == null) return;

    setState(() => _waitingForSaveChoice = false);
    _startOnlineServices();
  }

  Future<CloudSaveDownloadResult> _downloadCloudSave() {
    final download = widget.downloadCloudSave;
    if (download != null) return download();
    return CloudSaveService.downloadCloudSave(timeout: widget.restoreTimeout);
  }

  Future<void> _importCloudSave(String data) async {
    final import = widget.importCloudSave;
    if (import != null) {
      await import(data);
    } else {
      await CloudSaveService.importCloudSave(widget.db, data);
    }
    await ref.read(playerProvider.notifier).loadFromDatabase(widget.db);
    ref.invalidate(collectionProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(favoriteIdsProvider);
  }

  Future<void> _startNewGame() async {
    final start = widget.startNewGame;
    if (start != null) {
      await start();
      return;
    }
    await ref.read(playerProvider.notifier).initializeNewGame();
  }

  void _startOnlineServices() {
    if (_servicesStarted) return;
    _servicesStarted = true;
    _coordinator = CloudSaveCoordinator(widget.db)..start();
    ref.invalidate(dailyReminderProvider);
    unawaited(ref.read(dailyReminderProvider.future));

    unawaited(_syncAchievementsAndRewards());
    unawaited(
      LeaderboardService.submitScores(
        widget.db,
        ref.read(playerProvider).totalXp,
      ),
    );
  }

  Future<void> _syncAchievementsAndRewards() async {
    await GameCenterService.syncAchievements(widget.db);
    await ref.read(playerProvider.notifier).claimUnlockedAchievementRewards();
  }

  Future<void> _syncDailyReminderAuthorization() async {
    await ref.read(dailyReminderProvider.future);
    await ref.read(dailyReminderProvider.notifier).syncAuthorization();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _coordinator?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RootScreen(
      claimDailyLoginReward: !_waitingForSaveChoice,
      claimVersionUpdateReward: !_waitingForSaveChoice,
      currentAppVersion: widget.currentAppVersion,
      rewardUntrackedVersion: !widget.needsSaveChoice,
    );
  }
}

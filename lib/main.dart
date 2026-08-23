import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/data/database.dart';
import 'src/state/database_provider.dart';
import 'src/state/player_state.dart';
import 'src/state/game_center_service.dart';
import 'src/state/leaderboard_service.dart';
import 'src/state/cloud_save_service.dart';
import 'src/utils/ad_manager.dart';
import 'src/ui/screens/root_screen.dart';
import 'src/audio/music_manager.dart';
import 'src/audio/audio_route_observer.dart';
import 'src/audio/sound_manager.dart';
import 'src/ui/screens/settings_screen.dart';
import 'src/ui/theme/app_text.dart';

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
  try {
    final (_, soundEnabled, musicEnabled) = await (
      container.read(playerProvider.notifier).loadFromDatabase(db),
      db.getSetting(soundEnabledKey),
      db.getSetting(musicEnabledKey),
    ).wait;
    isSoundEnabled = soundEnabled != 'false';
    isMusicEnabled = musicEnabled != 'false';
  } catch (_) {
    // 数据库不可用时以默认进度启动，进入游戏时会给出错误提示
  }
  await MusicManager.instance.init(
    musicEnabled: isMusicEnabled,
    soundEnabled: isSoundEnabled,
  );
  await SoundManager.instance.init(enabled: isSoundEnabled);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: IdiomCrosswordApp(home: _CloudSaveBootstrap(db: db)),
    ),
  );
}

class IdiomCrosswordApp extends StatelessWidget {
  final Widget? home;

  const IdiomCrosswordApp({super.key, this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '成语接龙',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [audioRouteObserver],
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

class _CloudSaveBootstrap extends ConsumerStatefulWidget {
  final AppDatabase db;

  const _CloudSaveBootstrap({required this.db});

  @override
  ConsumerState<_CloudSaveBootstrap> createState() =>
      _CloudSaveBootstrapState();
}

class _CloudSaveBootstrapState extends ConsumerState<_CloudSaveBootstrap> {
  CloudSaveCoordinator? _coordinator;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final outcome = await CloudSaveService.restoreIfNeeded(widget.db);
    if (outcome == CloudRestoreOutcome.restored) {
      await ref.read(playerProvider.notifier).loadFromDatabase(widget.db);
    }
    if (outcome.canBackUp) {
      _coordinator = CloudSaveCoordinator(widget.db)..start();
    }

    // 云恢复完成后再同步成就与排行榜，避免提交全新空档的数据。
    unawaited(_syncAchievementsAndRewards());
    unawaited(
      LeaderboardService.submitScores(
        widget.db,
        ref.read(playerProvider).totalXp,
      ),
    );
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _syncAchievementsAndRewards() async {
    await GameCenterService.syncAchievements(widget.db);
    await ref.read(playerProvider.notifier).claimUnlockedAchievementRewards();
  }

  @override
  void dispose() {
    _coordinator?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const RootScreen();
    return const Scaffold(
      backgroundColor: Color(0xFFF3EDE1),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

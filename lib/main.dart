import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/state/database_provider.dart';
import 'src/state/player_state.dart';
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

  // 初始化广告 SDK（横幅/插屏/激励广告在各自页面加载）
  unawaited(AdManager().initialize());

  // 先加载已保存的玩家进度，避免启动后闪回默认值
  final container = ProviderContainer();
  var isSoundEnabled = true;
  var isMusicEnabled = true;
  try {
    final db = container.read(databaseProvider);
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
      child: const IdiomCrosswordApp(),
    ),
  );
}

class IdiomCrosswordApp extends StatelessWidget {
  const IdiomCrosswordApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '成语填字',
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
      home: const RootScreen(),
    );
  }
}

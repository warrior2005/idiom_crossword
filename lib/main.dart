import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/state/database_provider.dart';
import 'src/state/player_state.dart';
import 'src/ui/screens/root_screen.dart';
import 'src/audio/game_audio.dart';
import 'src/ui/screens/settings_screen.dart';

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

  // 先加载已保存的玩家进度，避免启动后闪回默认值
  final container = ProviderContainer();
  try {
    final db = container.read(databaseProvider);
    final (_, soundEnabled) = await (
      container.read(playerProvider.notifier).loadFromDatabase(db),
      db.getSetting(soundEnabledKey),
    ).wait;
    GameAudio.instance.muted = soundEnabled == 'false';
  } catch (_) {
    // 数据库不可用时以默认进度启动，进入游戏时会给出错误提示
  }

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB33B27),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3EDE1),
      ),
      home: const RootScreen(),
    );
  }
}

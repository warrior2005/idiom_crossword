import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // iOS 锁定竖屏
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // iOS 状态栏样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    const ProviderScope(
      child: IdiomCrosswordApp(),
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
          seedColor: const Color(0xFF8B4513), // 古典棕色
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: '.SF Pro Display', // iOS 系统字体
      ),
      home: const Placeholder(), // TODO: 首页
    );
  }
}

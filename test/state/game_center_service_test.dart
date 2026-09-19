import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/achievement_manager.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/state/cloud_save_service.dart';
import 'package:idiom_crossword/src/state/game_center_service.dart';
import 'package:idiom_crossword/src/state/leaderboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('games_services');
  const events = MethodChannel('games_services.player');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late AppDatabase db;
  late List<MethodCall> calls;
  Object? player;
  var emitPlayer = true;

  setUp(() {
    GameCenterService.resetForTesting();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    db = AppDatabase(NativeDatabase.memory());
    calls = [];
    player = null;
    emitPlayer = true;
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (call.method == 'signIn') {
        throw PlatformException(code: 'sign_in_failed');
      }
      return null;
    });
    messenger.setMockMethodCallHandler(events, (call) async {
      if (call.method == 'listen' && emitPlayer) {
        scheduleMicrotask(() {
          messenger.handlePlatformMessage(
            events.name,
            const StandardMethodCodec().encodeSuccessEnvelope(player),
            (_) {},
          );
        });
      }
      return null;
    });
  });

  tearDown(() async {
    GameCenterService.resetForTesting();
    await db.close();
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockMethodCallHandler(events, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('登录失败后连续通关提交和成就上报不再触发登录', () async {
    expect(await GameCenterService.ensureSignedIn(), isFalse);
    calls.clear();

    await LeaderboardService.submitScores(db, 100);
    await LeaderboardService.submitScores(db, 200);
    await GameCenterService.reportAchievement(AchievementId.values.first);

    expect(calls, isEmpty);
  });

  test('未登录的自动云备份不触发登录', () async {
    await db.addLevelHistory(levelNumber: 1, xpGained: 20, idiomsUsed: []);
    await CloudSaveService.backUpIfChanged(db);
    expect(calls, isEmpty);
  });

  test('登录流程未完成时自动提交不等待登录，也不再次登录', () async {
    final signIn = Completer<String?>();
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return signIn.future;
    });
    final pending = GameCenterService.ensureSignedIn();
    await LeaderboardService.submitScores(db, 100);
    expect(calls.map((call) => call.method), ['signIn']);
    signIn.completeError(PlatformException(code: 'sign_in_failed'));
    expect(await pending, isFalse);
  });

  test('外部登录后自动提交总经验和本周经验，无需再次登录', () async {
    await LeaderboardService.submitScores(db, 100);
    player = jsonEncode({'displayName': '玩家', 'playerID': 'player-1'});
    await db.addLevelHistory(levelNumber: 1, xpGained: 20, idiomsUsed: []);
    await LeaderboardService.submitScores(db, 100);

    expect(calls.map((call) => call.method), ['submitScore', 'submitScore']);
    expect(calls.map((call) => (call.arguments as Map)['value']), [100, 20]);
  });

  testWidgets('后台登录指数退避、共享重试，并在成功后停止', (tester) async {
    unawaited(GameCenterService.ensureSignedIn());
    await tester.pump();
    expect(calls.length, 1);
    unawaited(GameCenterService.ensureSignedIn());
    unawaited(LeaderboardService.submitScores(db, 100));
    await tester.pump();
    expect(calls.length, 1);

    for (final seconds in [30, 60, 120, 240, 300, 300]) {
      final previous = calls.length;
      await tester.pump(Duration(seconds: seconds - 1));
      expect(calls.length, previous);
      await tester.pump(const Duration(seconds: 1));
      expect(calls.length, previous + 1);
    }

    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      player = jsonEncode({'displayName': '玩家', 'playerID': 'player-1'});
      return null;
    });
    await tester.pump(const Duration(minutes: 5));
    final afterSuccess = calls.length;
    await tester.pump(const Duration(minutes: 10));
    expect(calls.length, afterSuccess);
    GameCenterService.resetForTesting();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('原生登录超时后不并发重试，迟到失败后进入退避', (tester) async {
    final signIn = Completer<String?>();
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return signIn.future;
    });
    final first = GameCenterService.ensureSignedIn();
    await tester.pump();
    await tester.pump(GameCenterService.signInTimeout);
    expect(await first, isFalse);
    final second = GameCenterService.ensureSignedIn();
    await tester.pump(GameCenterService.signInTimeout);
    expect(await second, isFalse);
    expect(calls.length, 1);
    signIn.completeError(PlatformException(code: 'sign_in_failed'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 29));
    expect(calls.length, 1);
    GameCenterService.resetForTesting();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('登录状态事件不返回时超时退出', (tester) async {
    emitPlayer = false;
    final result = GameCenterService.isSignedIn();
    await tester.pump();
    await tester.pump(GameCenterService.signInTimeout);
    expect(await result, isFalse);
    expect(calls, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });
}

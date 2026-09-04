import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:idiom_crossword/main.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/state/cloud_save_service.dart';
import 'package:idiom_crossword/src/state/database_provider.dart';
import 'package:idiom_crossword/src/state/level_state_codec.dart';
import 'package:idiom_crossword/src/state/player_state.dart';
import 'package:idiom_crossword/src/ui/screens/game_screen.dart';
import 'package:idiom_crossword/src/ui/screens/home_screen.dart';
import 'package:idiom_crossword/src/ui/screens/root_screen.dart';
import 'package:idiom_crossword/src/ui/widgets/primary_button.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: IdiomCrosswordApp()));
    expect(find.text('成语接龙'), findsOneWidget);
  });

  testWidgets('空存档立即进入首页并等待玩家选择', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: CloudSaveBootstrap(
            db: db,
            needsSaveChoice: true,
            downloadCloudSave: () async =>
                const CloudSaveDownloadResult.unavailable(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RootScreen), findsOneWidget);
    expect(find.text('欢迎来到成语接龙'), findsOneWidget);
    expect(find.textContaining('点击下方候选字'), findsOneWidget);
    expect(find.textContaining('交叉点同时满足两条线索'), findsOneWidget);
    expect(find.text('恢复云存档'), findsOneWidget);
    expect(find.text('开始新游戏'), findsOneWidget);
    expect(find.text('每日登录奖励'), findsNothing);
    expect(await db.getPlayerProgress(), isNull);
  });

  testWidgets('选择开始新游戏后留在首页并建立本地存档', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: CloudSaveBootstrap(
            db: db,
            needsSaveChoice: true,
            currentAppVersion: '1.0.2+3',
            downloadCloudSave: () async =>
                const CloudSaveDownloadResult.unavailable(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('开始新游戏'));
    await tester.pumpAndSettle();

    expect(find.byType(RootScreen), findsOneWidget);
    expect(find.text('欢迎来到成语接龙'), findsNothing);
    expect(find.text('版本更新奖励'), findsNothing);
    expect(find.text('每日登录奖励'), findsOneWidget);
    expect(await db.getPlayerProgress(), isNotNull);
    expect((await db.getPlayerProgress())!.points, 0);
    expect(await db.getSetting(kLastSeenAppVersionKey), '1.0.2+3');
  });

  testWidgets('云存档恢复成功后导入并进入首页', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    var imports = 0;
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: CloudSaveBootstrap(
            db: db,
            needsSaveChoice: true,
            downloadCloudSave: () async =>
                const CloudSaveDownloadResult.available('cloud-save'),
            importCloudSave: (_) async => imports++,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('恢复云存档'));
    await tester.pumpAndSettle();

    expect(imports, 1);
    expect(find.byType(RootScreen), findsOneWidget);
    expect(find.text('欢迎来到成语接龙'), findsNothing);
    expect(find.text('每日登录奖励'), findsOneWidget);
  });

  testWidgets('恢复超时后可重试且迟到结果不会导入', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final firstAttempt = Completer<CloudSaveDownloadResult>();
    var attempts = 0;
    var imports = 0;
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: CloudSaveBootstrap(
            db: db,
            needsSaveChoice: true,
            restoreTimeout: const Duration(seconds: 2),
            downloadCloudSave: () {
              attempts++;
              if (attempts == 1) return firstAttempt.future;
              return Future.value(
                const CloudSaveDownloadResult.available('cloud-save'),
              );
            },
            importCloudSave: (_) async => imports++,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('恢复云存档'));
    await tester.pump();

    expect(find.text('正在恢复（2 秒）'), findsOneWidget);
    expect(find.text('开始新游戏'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('连接超时，请检查网络后重试。'), findsOneWidget);
    expect(find.text('恢复云存档'), findsOneWidget);
    expect(
      tester
          .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, '恢复云存档'))
          .onTap,
      isNotNull,
    );

    firstAttempt.complete(
      const CloudSaveDownloadResult.available('late-cloud-save'),
    );
    await tester.pump();
    expect(imports, 0);

    await tester.tap(find.text('恢复云存档'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(imports, 1);
    expect(find.text('欢迎来到成语接龙'), findsNothing);
  });

  testWidgets('Game Center 不可用时提示系统设置且可重试', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    var attempts = 0;
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: CloudSaveBootstrap(
            db: db,
            needsSaveChoice: true,
            downloadCloudSave: () async {
              attempts++;
              return const CloudSaveDownloadResult.gameCenterUnavailable();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('恢复云存档'));
    await tester.pumpAndSettle();

    expect(find.textContaining('“设置”中登录 Game Center'), findsOneWidget);
    expect(
      tester
          .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, '恢复云存档'))
          .onTap,
      isNotNull,
    );

    await tester.tap(find.text('恢复云存档'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('进入第一关时不再重复显示玩法说明', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.saveLevelState(
      levelNumber: 1,
      levelJson:
          '{"levelId":1,"title":"第 1 关","rows":1,"cols":4,'
          '"cells":[[1,"画",0,1],[1,"蛇",0,0],[1,"添",0,0],[1,"足",0,0]],'
          '"placements":[["画蛇添足","hua she tian zu","释义",1,"",0,0,0]],'
          '"storyHint":null}',
      stateJson: encodeGameState(
        const SavedGameState(
          answers: {},
          usedCandidateSlots: {},
          fillHistory: [],
          cellToCandidateSlot: {},
          candidateBoard: [
            ['蛇', '添', '足'],
          ],
          hintUsesThisLevel: 0,
          errorsMade: 0,
          correctStreak: 0,
          totalFills: 0,
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('开始第 1 关'));
    await tester.pumpAndSettle();

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.text('欢迎来到成语接龙'), findsNothing);
    expect(await db.getSetting('tutorial_shown'), isNull);
  });
}

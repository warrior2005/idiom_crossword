import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/ui/screens/legal_screen.dart';
import 'package:idiom_crossword/src/ui/widgets/privacy_bootstrap.dart';

void main() {
  testWidgets('首次隐私确认前不进入游戏，遮罩不可关闭，同意后持久保存', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(() => db.getSetting('app_privacy_consent_20260906'));
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyBootstrap(db: db, child: const Text('游戏内容')),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('游戏内容'), findsNothing);
    expect(find.text('个人信息保护指引'), findsOneWidget);
    await tester.tap(find.text('《用户协议》'));
    await tester.pumpAndSettle();
    expect(find.text('用户协议与隐私'), findsOneWidget);
    expect(find.text('游戏内容'), findsNothing);
    Navigator.of(tester.element(find.byType(LegalScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('《隐私政策》'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LegalScreen>(find.byType(LegalScreen)).initialIndex,
      1,
    );
    Navigator.of(tester.element(find.byType(LegalScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(2, 2));
    await tester.pumpAndSettle();
    expect(find.text('同意'), findsOneWidget);
    await tester.tap(find.text('同意'));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('游戏内容'), findsOneWidget);
    expect(
      await tester.runAsync(() => db.getSetting(appPrivacyConsentKey)),
      'true',
    );
  });

  for (final key in ['app_privacy_consent_20260906', appPrivacyConsentKey]) {
    testWidgets('已同意当前协议不因应用升级重复弹框：$key', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() => db.setSetting(key, 'true'));
      await tester.pumpWidget(
        MaterialApp(
          home: PrivacyBootstrap(db: db, child: const Text('游戏内容')),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(find.text('游戏内容'), findsOneWidget);
      expect(find.text('个人信息保护指引'), findsNothing);
    });
  }

  testWidgets('旧协议同意记录不能代替当前协议授权', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.runAsync(
      () => db.setSetting('app_privacy_consent_old_old', 'true'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PrivacyBootstrap(db: db, child: const Text('游戏内容')),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('不同意'), findsNothing);
    expect(find.text('个人信息保护指引'), findsOneWidget);
    expect(find.text('游戏内容'), findsNothing);
    expect(
      await tester.runAsync(() => db.getSetting(appPrivacyConsentKey)),
      isNull,
    );
  });
}

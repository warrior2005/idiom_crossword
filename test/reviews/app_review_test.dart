import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/reviews/app_review.dart';

void main() {
  test('累计通关 10 关后提示，拒绝后冷却 7 天', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final manager = AppReviewPromptManager(db);
    final declinedAt = DateTime.utc(2026, 8, 1, 12);

    expect(await manager.shouldPrompt(completedLevels: 9), isFalse);
    expect(await manager.shouldPrompt(completedLevels: 10), isTrue);

    await manager.markDeclined(now: declinedAt);
    expect(
      await manager.shouldPrompt(
        completedLevels: 11,
        now: declinedAt
            .add(const Duration(days: 7))
            .subtract(const Duration(seconds: 1)),
      ),
      isFalse,
    );
    expect(
      await manager.shouldPrompt(
        completedLevels: 11,
        now: declinedAt.add(appReviewCooldown),
      ),
      isTrue,
    );
  });

  test('确认去评分后不再提示', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final manager = AppReviewPromptManager(db);

    await manager.markReviewRequested();

    expect(await manager.shouldPrompt(completedLevels: 10), isFalse);
    expect(await manager.shouldPrompt(completedLevels: 100), isFalse);
  });
}

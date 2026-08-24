import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';

import '../data/database.dart';

const appReviewRequestedKey = 'app_review_requested';
const appReviewDeclinedAtKey = 'app_review_declined_at';
const appReviewCooldown = Duration(days: 7);

abstract interface class AppReviewPlatform {
  Future<void> requestReview();
}

final appReviewPlatformProvider = Provider<AppReviewPlatform>(
  (ref) => const InAppReviewPlatform(),
);

class InAppReviewPlatform implements AppReviewPlatform {
  const InAppReviewPlatform();

  @override
  Future<void> requestReview() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) {
      await review.requestReview();
    }
  }
}

class AppReviewPromptManager {
  final AppDatabase _db;

  const AppReviewPromptManager(this._db);

  Future<bool> shouldPrompt({
    required int completedLevels,
    DateTime? now,
  }) async {
    if (completedLevels < 10 ||
        await _db.getSetting(appReviewRequestedKey) == 'true') {
      return false;
    }

    final declinedAt = DateTime.tryParse(
      await _db.getSetting(appReviewDeclinedAtKey) ?? '',
    );
    if (declinedAt == null) return true;

    return !(now ?? DateTime.now()).isBefore(declinedAt.add(appReviewCooldown));
  }

  Future<void> markReviewRequested() {
    return _db.setSetting(appReviewRequestedKey, 'true');
  }

  Future<void> markDeclined({DateTime? now}) {
    return _db.setSetting(
      appReviewDeclinedAtKey,
      (now ?? DateTime.now()).toUtc().toIso8601String(),
    );
  }
}

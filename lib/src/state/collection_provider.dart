import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';

class CollectionItem {
  final int id;
  final String word;
  final String explanation;
  final String? derivation;
  final String pinyin;
  final DateTime collectedAt;

  const CollectionItem({
    required this.id,
    required this.word,
    required this.explanation,
    required this.derivation,
    required this.pinyin,
    required this.collectedAt,
  });
}

final collectionProvider = FutureProvider<List<CollectionItem>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.getCollectionWithCollectedAt();
  return rows
      .map(
        (r) => CollectionItem(
          id: r.idiom.id,
          word: r.idiom.word,
          explanation: r.idiom.explanation,
          derivation: r.idiom.derivation,
          pinyin: r.idiom.pinyin,
          collectedAt: r.collectedAt,
        ),
      )
      .toList();
});

final favoriteIdsProvider = FutureProvider<Set<int>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (await db.getFavoriteIds()).toSet();
});

final favoritesProvider = FutureProvider<List<CollectionItem>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.getFavoritesWithFavoritedAt();
  return rows
      .map(
        (r) => CollectionItem(
          id: r.idiom.id,
          word: r.idiom.word,
          explanation: r.idiom.explanation,
          derivation: r.idiom.derivation,
          pinyin: r.idiom.pinyin,
          collectedAt: r.favoritedAt,
        ),
      )
      .toList();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_provider.dart';

class CollectionItem {
  final String word;
  final String explanation;
  final String? derivation;
  final String pinyin;
  final DateTime collectedAt;

  const CollectionItem({
    required this.word,
    required this.explanation,
    required this.derivation,
    required this.pinyin,
    required this.collectedAt,
  });
}

final collectionProvider = FutureProvider<List<CollectionItem>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.getCollectionWithDetails();
  return rows
      .map(
        (i) => CollectionItem(
          word: i.word,
          explanation: i.explanation,
          derivation: i.derivation,
          pinyin: i.pinyin,
          collectedAt: i.createdAt,
        ),
      )
      .toList();
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 收藏成语详情
class CollectionItem {
  final String word;
  final String explanation;
  final int difficulty;
  final DateTime collectedAt;

  const CollectionItem({
    required this.word,
    required this.explanation,
    required this.difficulty,
    required this.collectedAt,
  });
}

class CollectionScreen extends ConsumerWidget {
  const CollectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Web 测试用：空收藏列表
    final collection = <CollectionItem>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('成语收藏'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: collection.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 64,
                    color: Colors.brown,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '还没有收藏任何成语',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.brown,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '通关后自动收录',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.brown,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: collection.length,
              itemBuilder: (context, index) {
                final item = collection[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    title: Text(
                      item.word,
                      style: const TextStyle(fontSize: 20),
                    ),
                    subtitle: Text(item.explanation),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _difficultyColor(item.difficulty),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${item.difficulty}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _difficultyColor(int difficulty) {
    if (difficulty <= 10) return Colors.green;
    if (difficulty <= 20) return Colors.blue;
    if (difficulty <= 30) return Colors.orange;
    if (difficulty <= 40) return Colors.red;
    return Colors.purple;
  }
}

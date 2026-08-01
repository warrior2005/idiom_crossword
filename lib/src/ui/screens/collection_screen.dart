import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/database_provider.dart';

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

/// 收藏列表（从数据库加载，按收藏时间倒序）
final collectionProvider = FutureProvider<List<CollectionItem>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.getCollectionWithDetails();
  return rows
      .map(
        (i) => CollectionItem(
          word: i.word,
          explanation: i.explanation,
          difficulty: i.difficulty,
          collectedAt: i.createdAt,
        ),
      )
      .toList();
});

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  static const _pageSize = 30;

  String _query = '';
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final collectionAsync = ref.watch(collectionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('成语收藏'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: collectionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('加载失败: $e', style: const TextStyle(color: Colors.brown)),
        ),
        data: (collection) {
          final filtered = _query.isEmpty
              ? collection
              : collection
                    .where(
                      (c) =>
                          c.word.contains(_query) ||
                          c.explanation.contains(_query),
                    )
                    .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '搜索成语或释义',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.brown.shade200),
                    ),
                  ),
                  onChanged: (v) => setState(() {
                    _query = v.trim();
                    _page = 0;
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _page > 0
                          ? () => setState(() => _page--)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('上一页'),
                    ),
                    Text(
                      '共 ${filtered.length} 条',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.brown.shade500,
                      ),
                    ),
                    TextButton.icon(
                      onPressed:
                          _page < ((filtered.length / _pageSize).ceil() - 1)
                          ? () => setState(() => _page++)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('下一页'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: collection.isEmpty
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
                    : filtered.isEmpty
                    ? const Center(
                        child: Text(
                          '没有找到匹配的成语',
                          style: TextStyle(fontSize: 15, color: Colors.brown),
                        ),
                      )
                    : () {
                        final page = _page.clamp(
                          0,
                          ((filtered.length / _pageSize).ceil() - 1),
                        );
                        final pageItems = filtered.sublist(
                          page * _pageSize,
                          ((page + 1) * _pageSize).clamp(0, filtered.length),
                        );
                        return ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: pageItems.length,
                          itemBuilder: (context, index) {
                            final item = pageItems[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
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
                        );
                      }(),
              ),
            ],
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

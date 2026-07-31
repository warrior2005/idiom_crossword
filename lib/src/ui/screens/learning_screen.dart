import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../state/database_provider.dart';

/// 本关成语的完整资料（释义/出处/例句）
final learningDetailsProvider =
    FutureProvider.family<List<Idiom>, List<String>>((ref, words) async {
  final db = ref.watch(databaseProvider);
  final rows = <Idiom>[];
  for (final word in words) {
    final row = await db.findIdiomByWord(word);
    if (row != null) rows.add(row);
  }
  return rows;
});

/// 学习模式：通关后复习本关成语的释义、出处与例句
class LearningScreen extends ConsumerWidget {
  final List<String> words;

  const LearningScreen({super.key, required this.words});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(learningDetailsProvider(words));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('本关成语'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('加载失败: $e', style: const TextStyle(color: Colors.brown)),
        ),
        data: (rows) => ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final idiom = rows[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          idiom.word,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.brown.shade900,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.brown.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '难度 ${idiom.difficulty}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (idiom.pinyin.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        idiom.pinyin,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.brown.shade500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _detailRow('释义', idiom.explanation),
                    if (idiom.derivation != null && idiom.derivation!.isNotEmpty)
                      _detailRow('出处', idiom.derivation!),
                    if (idiom.example != null && idiom.example!.isNotEmpty)
                      _detailRow('例句', idiom.example!),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _detailRow(String label, String content) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label：',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.brown.shade700,
              ),
            ),
            TextSpan(
              text: content,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Colors.brown.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

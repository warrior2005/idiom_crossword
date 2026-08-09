import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database.dart';
import '../../state/database_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/app_card.dart';

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
  final Set<String> wrongWords;

  const LearningScreen({
    super.key,
    required this.words,
    this.wrongWords = const {},
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(learningDetailsProvider(words));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(
          '本关成语',
          style: displayStyle(size: 20, weight: FontWeight.w900),
        ),
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.fg,
      ),
      body: detailsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('加载失败: $e', style: const TextStyle(color: Colors.brown)),
        ),
        data: (rows) {
          final ordered = [
            ...rows.where((i) => wrongWords.contains(i.word)),
            ...rows.where((i) => !wrongWords.contains(i.word)),
          ];
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: ordered.length,
            itemBuilder: (context, index) {
              final idiom = ordered[index];
              return AppCard(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          idiom.word,
                          style: displayStyle(
                            size: 24,
                            weight: FontWeight.w900,
                            color: AppColors.accentDeep,
                          ),
                        ),
                        const Spacer(),
                        if (wrongWords.contains(idiom.word))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '填错',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
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
                        style: bodyStyle(
                          size: 11,
                          color: AppColors.muted,
                        ).copyWith(letterSpacing: 1.2),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _detailRow('释义', idiom.explanation),
                    if (idiom.derivation != null &&
                        idiom.derivation!.isNotEmpty)
                      _detailRow('出处', idiom.derivation!),
                    if (idiom.example != null && idiom.example!.isNotEmpty)
                      _detailRow('例句', idiom.example!),
                  ],
                ),
              );
            },
          );
        },
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
                color: AppColors.accentDeep,
              ),
            ),
            TextSpan(
              text: content,
              style: TextStyle(fontSize: 14, height: 1.5, color: AppColors.fg),
            ),
          ],
        ),
      ),
    );
  }
}

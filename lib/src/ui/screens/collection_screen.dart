import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/database_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/badge_soft.dart';
import '../widgets/banner_ad_view.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

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

class CollectionScreen extends ConsumerStatefulWidget {
  final bool bannerActive;

  const CollectionScreen({super.key, this.bannerActive = true});

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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: collectionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e', style: bodyStyle(color: AppColors.accent))),
          data: (collection) {
            final filtered = _query.isEmpty
                ? collection
                : collection
                      .where((c) => c.word.contains(_query) || c.explanation.contains(_query))
                      .toList();
            final weekAgo = DateTime.now().subtract(const Duration(days: 7));
            final weekNew = collection.where((c) => c.collectedAt.isAfter(weekAgo)).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('成语收藏', style: displayStyle(size: 30, weight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text('已通关成语自动收录 · 附释义与出处', style: kickerStyle()),
                      const SizedBox(height: 12),
                      _SearchField(
                        onChanged: (v) => setState(() {
                          _query = v.trim();
                          _page = 0;
                        }),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('共 ${collection.length} 则',
                              style: displayStyle(size: 15, weight: FontWeight.w700)),
                          BadgeSoft('本周新增 $weekNew', color: BadgeSoftColor.leaf),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: collection.isEmpty
                      ? const _EmptyState(
                          title: '还没有收藏任何成语',
                          sub: '通关后自动收录',
                        )
                      : filtered.isEmpty
                      ? const _EmptyState(title: '没有找到匹配的成语', sub: '换个关键词试试')
                      : () {
                          final maxPage = ((filtered.length / _pageSize).ceil() - 1).clamp(0, 1 << 31);
                          final page = _page.clamp(0, maxPage);
                          final items = filtered.sublist(
                            page * _pageSize,
                            ((page + 1) * _pageSize).clamp(0, filtered.length),
                          );
                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            itemCount: items.length + 1,
                            itemBuilder: (context, index) {
                              if (index == items.length) {
                                return _Pager(
                                  page: page,
                                  maxPage: maxPage,
                                  onPrev: () => setState(() => _page--),
                                  onNext: () => setState(() => _page++),
                                );
                              }
                              final item = items[index];
                              return _ColCard(item: item);
                            },
                          );
                      }(),
                ),
                BannerAdView(active: widget.bannerActive),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          AppIcon('search', size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索成语或释义',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.faint),
                border: InputBorder.none,
                isDense: true,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColCard extends StatelessWidget {
  final CollectionItem item;
  const _ColCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(item.word, style: displayStyle(size: 24, weight: FontWeight.w900)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.pinyin.toUpperCase(),
                  style: bodyStyle(size: 11, color: AppColors.muted).copyWith(letterSpacing: 1.2),
                ),
                const SizedBox(height: 6),
                Text(item.explanation, style: bodyStyle(size: 13, color: const Color(0xFF4A4438))),
                if (item.derivation != null && item.derivation!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('· ${item.derivation}', style: bodyStyle(size: 11, color: AppColors.faint)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String sub;
  const _EmptyState({required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon('book', size: 64, color: AppColors.faint),
          const SizedBox(height: 16),
          Text(title, style: displayStyle(size: 18, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(sub, style: bodyStyle(size: 14, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  final int page;
  final int maxPage;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _Pager({
    required this.page,
    required this.maxPage,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: page > 0 ? onPrev : null,
          icon: const AppIcon('back', size: 18),
          color: AppColors.muted,
        ),
        Text('第 ${page + 1} / ${maxPage + 1} 页', style: bodyStyle(size: 12, color: AppColors.muted)),
        IconButton(
          onPressed: page < maxPage ? onNext : null,
          icon: Transform.rotate(angle: 3.14159, child: const AppIcon('back', size: 18)),
          color: AppColors.muted,
        ),
      ],
    );
  }
}

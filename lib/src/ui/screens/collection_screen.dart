import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/collection_provider.dart';
import '../../state/database_provider.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/badge_soft.dart';
import '../widgets/banner_ad_view.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

class CollectionScreen extends ConsumerWidget {
  final bool bannerActive;

  const CollectionScreen({super.key, this.bannerActive = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collectionAsync = ref.watch(collectionProvider);
    final favoritesAsync = ref.watch(favoritesProvider);
    final favoriteIds = ref.watch(favoriteIdsProvider).value ?? const <int>{};

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '成语收藏',
                      style: displayStyle(size: 30, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text('主动收藏与通关收录的成语', style: kickerStyle()),
                    const SizedBox(height: 12),
                    TabBar(
                      labelColor: AppColors.accentDeep,
                      unselectedLabelColor: AppColors.muted,
                      indicatorColor: AppColors.accentDeep,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: const [
                        Tab(text: '收藏'),
                        Tab(text: '全部'),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _CollectionList(
                      itemsAsync: favoritesAsync,
                      emptyTitle: '还没有收藏任何成语',
                      emptySub: '在“本关成语”中点击收藏',
                      weekLabel: '本周收藏',
                      onDelete: (item) => _confirmDelete(context, ref, item),
                    ),
                    _CollectionList(
                      itemsAsync: collectionAsync,
                      emptyTitle: '还没有收录任何成语',
                      emptySub: '通关后自动收录',
                      weekLabel: '本周新增',
                      favoriteIds: favoriteIds,
                      onFavoriteToggle: (item, isFavorite) =>
                          _toggleFavorite(context, ref, item, isFavorite),
                    ),
                  ],
                ),
              ),
              BannerAdView(active: bannerActive),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CollectionItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ThemeDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '删除收藏？',
              style: displayStyle(size: 20, weight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              '确定要从收藏中删除“${item.word}”吗？',
              style: bodyStyle(size: 14, color: AppColors.fg),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    label: '取消',
                    small: true,
                    ghost: true,
                    onTap: () => Navigator.of(dialogContext).pop(false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(
                    label: '确认删除',
                    small: true,
                    onTap: () => Navigator.of(dialogContext).pop(true),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    await ref.read(databaseProvider).removeFromFavorites(item.id);
    ref.invalidate(favoriteIdsProvider);
    ref.invalidate(favoritesProvider);
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    CollectionItem item,
    bool isFavorite,
  ) async {
    final db = ref.read(databaseProvider);
    if (isFavorite) {
      await db.removeFromFavorites(item.id);
    } else {
      await db.addToFavorites(item.id);
    }
    ref.invalidate(favoriteIdsProvider);
    ref.invalidate(favoritesProvider);
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(isFavorite ? '取消收藏' : '已收藏')),
    );
  }
}

class _CollectionList extends StatefulWidget {
  final AsyncValue<List<CollectionItem>> itemsAsync;
  final String emptyTitle;
  final String emptySub;
  final String weekLabel;
  final ValueChanged<CollectionItem>? onDelete;
  final Set<int> favoriteIds;
  final void Function(CollectionItem item, bool isFavorite)? onFavoriteToggle;

  const _CollectionList({
    required this.itemsAsync,
    required this.emptyTitle,
    required this.emptySub,
    required this.weekLabel,
    this.onDelete,
    this.favoriteIds = const {},
    this.onFavoriteToggle,
  });

  @override
  State<_CollectionList> createState() => _CollectionListState();
}

class _CollectionListState extends State<_CollectionList> {
  static const _pageSize = 10;
  String _query = '';
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return widget.itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('加载失败: $e', style: bodyStyle(color: AppColors.accent)),
      ),
      data: (items) {
        final filtered = _query.isEmpty
            ? items
            : items.where((item) => item.word.contains(_query)).toList();
        final weekAgo = DateTime.now().subtract(const Duration(days: 7));
        final weekNew = items
            .where((c) => c.collectedAt.isAfter(weekAgo))
            .length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
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
                      Text(
                        '共 ${items.length} 则',
                        style: displayStyle(size: 15, weight: FontWeight.w700),
                      ),
                      BadgeSoft(
                        '${widget.weekLabel} $weekNew',
                        color: BadgeSoftColor.leaf,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? _EmptyState(title: widget.emptyTitle, sub: widget.emptySub)
                  : filtered.isEmpty
                  ? const _EmptyState(title: '没有找到匹配的成语', sub: '换个关键词试试')
                  : () {
                      final maxPage = ((filtered.length / _pageSize).ceil() - 1)
                          .clamp(0, 1 << 31);
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
                          return _ColCard(
                            key: ValueKey(item.id),
                            item: item,
                            isFavorite: widget.onFavoriteToggle == null
                                ? null
                                : widget.favoriteIds.contains(item.id),
                            onFavoriteToggle: widget.onFavoriteToggle == null
                                ? null
                                : () => widget.onFavoriteToggle!(
                                    item,
                                    widget.favoriteIds.contains(item.id),
                                  ),
                            onDelete: widget.onDelete == null
                                ? null
                                : () => widget.onDelete!(item),
                          );
                        },
                      );
                    }(),
            ),
          ],
        );
      },
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
                hintText: '搜索成语',
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
  final VoidCallback? onDelete;
  final bool? isFavorite;
  final VoidCallback? onFavoriteToggle;

  const _ColCard({
    super.key,
    required this.item,
    this.onDelete,
    this.isFavorite,
    this.onFavoriteToggle,
  });

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
            child: Text(
              item.word,
              style: displayStyle(size: 24, weight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.pinyin.toUpperCase(),
                        style: bodyStyle(
                          size: 11,
                          color: AppColors.muted,
                        ).copyWith(letterSpacing: 1.2),
                      ),
                    ),
                    if (onDelete != null)
                      Semantics(
                        button: true,
                        label: '删除收藏 ${item.word}',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onDelete,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                            child: BadgeSoft('删除'),
                          ),
                        ),
                      ),
                    if (onFavoriteToggle != null)
                      OutlinedButton(
                        onPressed: onFavoriteToggle,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          foregroundColor: isFavorite!
                              ? AppColors.accentDeep
                              : AppColors.muted,
                          side: BorderSide(
                            color: isFavorite!
                                ? AppColors.accentDeep
                                : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isFavorite! ? '已收藏' : '收藏',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.explanation,
                  style: bodyStyle(size: 13, color: const Color(0xFF4A4438)),
                ),
                if (item.derivation != null && item.derivation!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '· ${item.derivation}',
                      style: bodyStyle(size: 11, color: AppColors.faint),
                    ),
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
        Text(
          '第 ${page + 1} / ${maxPage + 1} 页',
          style: bodyStyle(size: 12, color: AppColors.muted),
        ),
        IconButton(
          onPressed: page < maxPage ? onNext : null,
          icon: Transform.rotate(
            angle: 3.14159,
            child: const AppIcon('back', size: 18),
          ),
          color: AppColors.muted,
        ),
      ],
    );
  }
}

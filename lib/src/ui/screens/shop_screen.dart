import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/badge_soft.dart';
import '../widgets/section_title.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/grid_skins.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('内购功能即将上线')));
  }

  Future<void> _buyFunctional(
    BuildContext context,
    WidgetRef ref, {
    int hintCards = 0,
    int reviveCards = 0,
  }) async {
    await ref.read(playerProvider.notifier).addHintCards(hintCards);
    await ref.read(playerProvider.notifier).addReviveCards(reviveCards);
    if (!context.mounted) return;
    final parts = <String>[
      if (hintCards > 0) '提示卡 ×$hintCards',
      if (reviveCards > 0) '复活卡 ×$reviveCards',
    ];
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('购买成功：${parts.join(' + ')}')));
  }

  Future<void> _selectSkin(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    await ref.read(playerProvider.notifier).setActiveGridSkin(id);
    if (!context.mounted) return;
    final name = gridSkinById(id)?.name ?? id;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已切换网格皮肤：$name')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final hintCards = player.functionalItems['hint_card'] ?? 0;
    final reviveCards = player.functionalItems['revive_card'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            Text(
              '文房四宝 · 商城',
              style: displayStyle(size: 30, weight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('功能道具 · 装饰藏品 · 均可永久保留', style: kickerStyle()),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _WalletCard(
                    iconName: 'pen',
                    label: '提示卡',
                    value: '$hintCards',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _WalletCard(
                    iconName: 'revive',
                    label: '复活卡',
                    value: '$reviveCards',
                  ),
                ),
              ],
            ),
            const SectionTitle(title: '功能道具', trailing: BadgeSoft('实用')),
            _PackCard(
              iconName: 'pen',
              name: '提示卡 ×10',
              desc: '每次使用消耗一张提示卡',
              price: '¥6',
              oldPrice: '¥9',
              onBuy: () => _buyFunctional(context, ref, hintCards: 10),
            ),
            _PackCard(
              iconName: 'revive',
              name: '复活卡 ×5',
              desc: '失误满格后可重整旗鼓，保留已填正确字',
              price: '¥12',
              onBuy: () => _buyFunctional(context, ref, reviveCards: 5),
            ),
            _PackCard(
              iconName: 'star',
              name: '备考礼盒（提示×10 + 复活×5）',
              desc: '冲刺阶段一次备齐，限量供应',
              price: '¥15',
              oldPrice: '¥21',
              onBuy: () =>
                  _buyFunctional(context, ref, hintCards: 10, reviveCards: 5),
            ),
            const SectionTitle(
              title: '装饰藏品',
              trailing: BadgeSoft('限定', color: BadgeSoftColor.gold),
            ),
            _SkinsCard(
              owned: player.ownedDecorations,
              active: player.activeGridSkin,
              onSelect: (id) => _selectSkin(context, ref, id),
            ),
            const SectionTitle(title: '尊享'),
            _RemoveAdsCard(onBuy: () => _comingSoon(context)),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '内购不影响关卡难度与成语选择',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.faint,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  final String iconName;
  final String label;
  final String value;
  const _WalletCard({
    required this.iconName,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _IconBox(
            iconName: iconName,
            bg: AppColors.accentPale,
            color: AppColors.accent,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: bodyStyle(size: 11, color: AppColors.muted)),
              Text(
                value,
                style: displayStyle(size: 17, weight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final String iconName;
  final String name;
  final String desc;
  final String price;
  final String? oldPrice;
  final VoidCallback onBuy;
  const _PackCard({
    required this.iconName,
    required this.name,
    required this.desc,
    required this.price,
    this.oldPrice,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _IconBox(
            iconName: iconName,
            bg: AppColors.accentPale,
            color: AppColors.accent,
            size: 56,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: bodyStyle(size: 15, weight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: bodyStyle(size: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: displayStyle(
                  size: 15,
                  weight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
              if (oldPrice != null)
                Text(
                  oldPrice!,
                  style: bodyStyle(
                    size: 11,
                    color: AppColors.faint,
                  ).copyWith(decoration: TextDecoration.lineThrough),
                ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onBuy,
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '购买',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFF6EC),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkinsCard extends StatelessWidget {
  final Set<String> owned;
  final String active;
  final ValueChanged<String> onSelect;
  const _SkinsCard({
    required this.owned,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('网格皮肤', style: bodyStyle(size: 14, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            '测试阶段不锁定，点击即可使用',
            style: bodyStyle(size: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          for (final skin in gridSkins) _skinTile(skin),
        ],
      ),
    );
  }

  Widget _skinTile(GridSkin skin) {
    final isActive = active == skin.id;
    final isOwned = owned.contains('grid_skin_${skin.id}');
    return GestureDetector(
      onTap: () => onSelect(skin.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: skin.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? skin.accent : skin.border,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: skin.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: skin.borderStrong),
              ),
              child: Center(
                child: Text(
                  '字',
                  style: TextStyle(
                    fontFamily: kSerif,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: skin.accentDeep,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skin.name,
                    style: bodyStyle(
                      size: 14,
                      weight: FontWeight.w600,
                      color: skin.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isActive
                        ? '当前使用'
                        : isOwned
                        ? '已拥有'
                        : '未拥有（测试可选）',
                    style: bodyStyle(
                      size: 11,
                      color: skin.foreground.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (isActive) BadgeSoft('使用中', color: BadgeSoftColor.gold),
          ],
        ),
      ),
    );
  }
}

class _RemoveAdsCard extends StatelessWidget {
  final VoidCallback onBuy;
  const _RemoveAdsCard({required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _IconBox(
            iconName: 'eye',
            bg: AppColors.goldSoft,
            color: const Color(0xFF7A5D14),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '去广告',
                  style: bodyStyle(size: 15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '移除全部插屏广告，永久生效',
                  style: bodyStyle(size: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onBuy,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF7A5D14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '¥3',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final String iconName;
  final Color bg;
  final Color color;
  final double size;
  const _IconBox({
    required this.iconName,
    required this.bg,
    required this.color,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(
        child: AppIcon(iconName, size: size * 0.5, color: color),
      ),
    );
  }
}

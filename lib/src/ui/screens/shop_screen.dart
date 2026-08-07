import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';
import '../../utils/ad_manager.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/badge_soft.dart';
import '../widgets/banner_ad_view.dart';
import '../widgets/section_title.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/grid_skins.dart';

/// 积分定价（按广告价值估算后的初值，可后续调整）
const int kHintCardPoints = 10;
const int kReviveCardPoints = 15;
const int kGiftBoxPoints = 40;

/// 广告兑换皮肤积分定价（初值，可后续调整）
const Map<String, int> kAdSkinPoints = {
  'qiuxiang': 2000, // 秋香
  'moyu': 3000, // 墨玉
  'zhusha': 3000, // 朱砂
  'dailan': 4000, // 黛蓝
  'ouhe': 4000, // 藕荷
  'jiangzi': 5000, // 绛紫
};

/// 等级皮肤解锁等级（升级奖励发放后自动拥有）
const Map<String, int> kLevelSkinUnlockLevels = {
  'bamboo': 3, // 竹简
  'paper': 7, // 宣纸
  'qinghua': 11, // 青花
  'gold': 15, // 金箔
  'emperor': 19, // 九五至尊
};

class ShopScreen extends ConsumerStatefulWidget {
  final bool bannerActive;

  const ShopScreen({super.key, this.bannerActive = true});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;
  int _watchedToday = 0;
  bool _maxReachedToday = false;

  @override
  void initState() {
    super.initState();
    _refreshAdStatus();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showPointsGuide(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('积分说明', style: displayStyle(size: 20, weight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _guideLine('激励广告', '观看完成 +3 积分；每天最多 100 次，前 10 次冷却 1 分钟，之后每次冷却 2 分钟。'),
            _guideLine('插屏广告', '通关结算前随机展示，单次观看满 10 秒 +2 积分。'),
            _guideLine('横幅广告', '关卡/收藏/商城底部常驻，每累计观看 1 分钟 +1 积分，每天上限 $kMaxBannerPointsPerDay 积分。'),
            _guideLine('积分用途', '兑换提示卡、复活卡、备考礼盒与广告兑换网格皮肤。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _guideLine(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: bodyStyle(size: 13, color: AppColors.fg),
          children: [
            TextSpan(
              text: '$title：',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: desc),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshAdStatus() async {
    final status = await ref
        .read(playerProvider.notifier)
        .rewardedAdStatus();
    if (!mounted) return;
    setState(() {
      _watchedToday = status.countToday;
      _cooldownSeconds = status.cooldownSeconds;
      _maxReachedToday = status.maxReached;
    });
    _startCooldownTick();
  }

  void _startCooldownTick() {
    _cooldownTimer?.cancel();
    if (_cooldownSeconds <= 0) return;
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_cooldownSeconds > 0) _cooldownSeconds--;
      });
      if (_cooldownSeconds <= 0) _cooldownTimer?.cancel();
    });
  }

  Future<void> _watchRewardedAd() async {
    final notifier = ref.read(playerProvider.notifier);
    final status = await notifier.rewardedAdStatus();
    if (!status.canWatch) {
      _showSnack(status.maxReached ? '今日激励广告已达上限' : '广告冷却中，请稍后再试');
      return;
    }
    final shown = AdManager().showRewardedAd(
      onRewardEarned: (type, amount) async {
        final newStatus = await notifier.consumeRewardedAd();
        await notifier.addPoints(kRewardedAdPointsReward);
        if (!mounted) return;
        setState(() {
          _watchedToday = newStatus.countToday;
          _cooldownSeconds = newStatus.cooldownSeconds;
          _maxReachedToday = newStatus.maxReached;
        });
        _startCooldownTick();
        _showSnack('观看广告，获得 $kRewardedAdPointsReward 积分');
      },
    );
    if (!shown) _showSnack('广告暂未加载，请稍后再试');
  }

  Future<void> _buyFunctional(
    BuildContext context,
    WidgetRef ref, {
    required int points,
    int hintCards = 0,
    int reviveCards = 0,
  }) async {
    final notifier = ref.read(playerProvider.notifier);
    final ok = await notifier.spendPoints(points);
    if (!ok) {
      _showSnack('积分不足，可观看广告赚取积分');
      return;
    }
    await notifier.addHintCards(hintCards);
    await notifier.addReviveCards(reviveCards);
    final parts = <String>[
      if (hintCards > 0) '提示卡 ×$hintCards',
      if (reviveCards > 0) '复活卡 ×$reviveCards',
    ];
    _showSnack('购买成功：${parts.join(' + ')}');
  }

  Future<void> _onSkinTap(BuildContext context, WidgetRef ref, String id) async {
    final notifier = ref.read(playerProvider.notifier);
    final player = ref.read(playerProvider);
    final skin = gridSkinById(id);
    final name = skin?.name ?? id;
    final isOwned =
        id == 'paper' ||
        player.ownedDecorations.contains('grid_skin_$id') ||
        (id == 'qinghua' && player.ownedDecorations.contains('grid_skin_dragon'));
    if (skin?.source == 'level') {
      // 等级皮肤：升级奖励解锁后才可切换
      if (!isOwned) {
        final unlockLevel = kLevelSkinUnlockLevels[id] ?? 0;
        _showSnack(
          unlockLevel > 0
              ? '该皮肤为 Lv.$unlockLevel 升级奖励，达到等级后解锁'
              : '该皮肤为等级奖励皮肤，达到对应等级后解锁',
        );
        return;
      }
      await notifier.setActiveGridSkin(id);
      _showSnack('已切换网格皮肤：$name');
      return;
    }
    // 广告兑换皮肤：积分购买后解锁
    if (!isOwned) {
      final price = kAdSkinPoints[id] ?? 0;
      if (price <= 0) return;
      final ok = await notifier.spendPoints(price);
      if (!ok) {
        _showSnack('积分不足，可观看广告赚取积分');
        return;
      }
      await notifier.unlockGridSkin(id);
      await notifier.setActiveGridSkin(id);
      _showSnack('已购买并切换网格皮肤：$name');
      return;
    }
    await notifier.setActiveGridSkin(id);
    _showSnack('已切换网格皮肤：$name');
  }

  @override
  Widget build(BuildContext context) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('功能道具 · 装饰藏品 · 广告赚积分', style: kickerStyle()),
                GestureDetector(
                  onTap: () => _showPointsGuide(context),
                  child: Row(
                    children: [
                      AppIcon('chart', size: 14, color: AppColors.muted),
                      const SizedBox(width: 3),
                      Text(
                        '积分说明',
                        style: bodyStyle(size: 11.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _PointsCard(
              points: player.points,
              cooldownSeconds: _cooldownSeconds,
              watchedToday: _watchedToday,
              maxReached: _maxReachedToday,
              onWatch: _watchRewardedAd,
            ),
            const SizedBox(height: 12),
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
            const SectionTitle(title: '功能道具', trailing: BadgeSoft('积分购买')),
            _PackCard(
              iconName: 'pen',
              name: '提示卡 ×1',
              desc: '每次使用消耗一张提示卡',
              price: '$kHintCardPoints 积分',
              onBuy: () => _buyFunctional(
                context,
                ref,
                points: kHintCardPoints,
                hintCards: 1,
              ),
            ),
            _PackCard(
              iconName: 'revive',
              name: '复活卡 ×1',
              desc: '失误满格后可重整旗鼓，保留已填正确字',
              price: '$kReviveCardPoints 积分',
              onBuy: () => _buyFunctional(
                context,
                ref,
                points: kReviveCardPoints,
                reviveCards: 1,
              ),
            ),
            _PackCard(
              iconName: 'star',
              name: '备考礼盒（提示×3 + 复活×1）',
              desc: '冲刺阶段一次备齐，限量供应',
              price: '$kGiftBoxPoints 积分',
              onBuy: () => _buyFunctional(
                context,
                ref,
                points: kGiftBoxPoints,
                hintCards: 3,
                reviveCards: 1,
              ),
            ),
            const SectionTitle(
              title: '装饰藏品',
              trailing: BadgeSoft('限定', color: BadgeSoftColor.gold),
            ),
            _SkinsCard(
              owned: player.ownedDecorations,
              active: player.activeGridSkin,
              onSelect: (id) => _onSkinTap(context, ref, id),
            ),
            BannerAdView(active: widget.bannerActive),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                '广告与积分不影响关卡难度与成语选择',
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

class _PointsCard extends StatelessWidget {
  final int points;
  final int cooldownSeconds;
  final int watchedToday;
  final bool maxReached;
  final VoidCallback onWatch;

  const _PointsCard({
    required this.points,
    required this.cooldownSeconds,
    required this.watchedToday,
    required this.maxReached,
    required this.onWatch,
  });

  String _formatCooldown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final String statusText;
    if (maxReached) {
      statusText = '今日激励广告已达上限（$watchedToday/$kRewardedAdMaxPerDay）';
    } else if (cooldownSeconds > 0) {
      statusText = '下次观看：${_formatCooldown(cooldownSeconds)}';
    } else {
      statusText = '今日已看 $watchedToday/$kRewardedAdMaxPerDay 次';
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.accentPale,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: AppIcon('star', size: 24, color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('我的积分', style: bodyStyle(size: 11, color: AppColors.muted)),
                Text(
                  '$points',
                  style: displayStyle(size: 22, weight: FontWeight.w800),
                ),
                Text(
                  statusText,
                  style: bodyStyle(size: 10.5, color: AppColors.faint),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: AdManager().isRewardedAdReadyNotifier,
            builder: (context, isAdReady, child) {
              final disabled =
                  maxReached || cooldownSeconds > 0 || !isAdReady;
              return GestureDetector(
                onTap: disabled ? null : onWatch,
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: disabled ? AppColors.border : AppColors.accent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        'video',
                        size: 16,
                        color: disabled
                            ? AppColors.faint
                            : const Color(0xFFFFF6EC),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        cooldownSeconds > 0
                            ? _formatCooldown(cooldownSeconds)
                            : !isAdReady
                            ? '加载中…'
                            : '赚取积分',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: disabled
                              ? AppColors.faint
                              : const Color(0xFFFFF6EC),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
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
  final VoidCallback onBuy;
  const _PackCard({
    required this.iconName,
    required this.name,
    required this.desc,
    required this.price,
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
                  size: 14,
                  weight: FontWeight.w700,
                  color: AppColors.accent,
                ),
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
            '等级皮肤达级解锁，广告兑换皮肤可用积分购买',
            style: bodyStyle(size: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Text('等级皮肤', style: bodyStyle(size: 11.5, color: AppColors.muted)),
          const SizedBox(height: 6),
          for (final skin in gridSkins.where((s) => s.source == 'level'))
            _skinTile(skin),
          const SizedBox(height: 6),
          Text('广告兑换', style: bodyStyle(size: 11.5, color: AppColors.muted)),
          const SizedBox(height: 6),
          for (final skin in gridSkins.where((s) => s.source == 'ads'))
            _skinTile(skin),
        ],
      ),
    );
  }

  bool _isOwned(GridSkin skin) {
    if (skin.id == 'paper') return true;
    return owned.contains('grid_skin_${skin.id}') ||
        (skin.id == 'qinghua' && owned.contains('grid_skin_dragon'));
  }

  Widget _skinTile(GridSkin skin) {
    final isActive = active == skin.id;
    final isOwned = _isOwned(skin);
    final isLevelSkin = skin.source == 'level';
    final price = kAdSkinPoints[skin.id] ?? 0;
    final unlockLevel = kLevelSkinUnlockLevels[skin.id] ?? 0;
    final statusText = isActive
        ? '当前使用'
        : isOwned
        ? '已拥有'
        : isLevelSkin
        ? 'Lv.$unlockLevel 升级奖励'
        : '$price 积分购买';
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
                    statusText,
                    style: bodyStyle(
                      size: 11,
                      color: skin.foreground.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              BadgeSoft('使用中', color: BadgeSoftColor.gold)
            else if (!isOwned)
              BadgeSoft(
                isLevelSkin ? 'Lv.$unlockLevel' : '$price 积分',
                color: BadgeSoftColor.leaf,
              ),
          ],
        ),
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

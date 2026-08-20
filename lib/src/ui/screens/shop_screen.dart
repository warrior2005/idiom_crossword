import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';
import '../../utils/ad_manager.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icons.dart';
import '../widgets/badge_soft.dart';
import '../widgets/banner_ad_view.dart';
import '../widgets/primary_button.dart';
import '../widgets/section_title.dart';
import '../widgets/theme_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/grid_skins.dart';
import '../theme/decoration_catalog.dart';

/// 广告兑换皮肤积分定价（初值，可后续调整）
const Map<String, int> kAdSkinPoints = {
  'qiuxiang': 1000, // 秋香
  'moyu': 2000, // 墨玉
  'zhusha': 2500, // 朱砂
  'dailan': 3000, // 黛蓝
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

/// 商城商品条目统一高度（购买/解锁前后保持不变）
const double kShopItemHeight = 80;

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

  Future<bool> _confirmPurchase(
    BuildContext context,
    String name,
    int points,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ThemeDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确认购买',
              style: displayStyle(size: 20, weight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              '花费 $points 积分购买「$name」？',
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
                    label: '确认',
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
    return confirmed ?? false;
  }

  Future<bool> _showLockedDecorationPreview(
    BuildContext context, {
    required String name,
    required Widget preview,
    int? points,
    String? unlockMessage,
  }) async {
    final shouldBuy = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _LockedDecorationDialog(
        name: name,
        preview: preview,
        points: points,
        unlockMessage: unlockMessage,
      ),
    );
    return shouldBuy ?? false;
  }

  void _showPointsGuide(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => ThemeDialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '积分说明',
                style: displayStyle(size: 20, weight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _guideLine(
                        '激励广告',
                        '观看完成 +3 积分；每天最多 100 次，前 10 次冷却 1 分钟，之后每次冷却 2 分钟。',
                      ),
                      _guideLine(
                        '插页式激励广告',
                        '通关结算前随机提供；确认观看且达到奖励条件后 +$kRewardedInterstitialAdPointsReward 积分，跳过或未完成不奖励。',
                      ),
                      _guideLine(
                        '横幅广告',
                        '关卡/收藏/商城底部常驻，每累计观看 1 分钟 +1 积分，每天上限 $kMaxBannerPointsPerDay 积分。',
                      ),
                      _guideLine('积分用途', '兑换提示卡、复活卡、备考礼盒、广告兑换网格皮肤与头像框。'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: '知道了',
                  small: true,
                  onTap: () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ],
          ),
        ),
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
    final status = await ref.read(playerProvider.notifier).rewardedAdStatus();
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
    final parts = <String>[
      if (hintCards > 0) '提示卡 ×$hintCards',
      if (reviveCards > 0) '复活卡 ×$reviveCards',
    ];
    final confirmed = await _confirmPurchase(
      context,
      parts.join(' + '),
      points,
    );
    if (!confirmed) return;
    final notifier = ref.read(playerProvider.notifier);
    final ok = await notifier.spendPoints(points);
    if (!ok) {
      _showSnack('积分不足，可观看广告赚取积分');
      return;
    }
    await notifier.addHintCards(hintCards);
    await notifier.addReviveCards(reviveCards);
    _showSnack('购买成功：${parts.join(' + ')}');
  }

  Future<void> _onSkinTap(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final notifier = ref.read(playerProvider.notifier);
    final player = ref.read(playerProvider);
    final skin = gridSkinById(id);
    final name = skin?.name ?? id;
    final isOwned =
        id == 'paper' ||
        player.ownedDecorations.contains('grid_skin_$id') ||
        (id == 'qinghua' &&
            player.ownedDecorations.contains('grid_skin_dragon'));
    if (skin?.source == 'level') {
      // 等级皮肤：升级奖励解锁后才可切换
      if (!isOwned) {
        final unlockLevel = kLevelSkinUnlockLevels[id] ?? 0;
        await _showLockedDecorationPreview(
          context,
          name: name,
          preview: _GridSkinPreview(skin: skin!),
          unlockMessage: unlockLevel > 0
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
      final shouldBuy = await _showLockedDecorationPreview(
        context,
        name: name,
        preview: _GridSkinPreview(skin: skin!),
        points: price,
      );
      if (!shouldBuy) return;
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

  Future<void> _onFrameTap(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final notifier = ref.read(playerProvider.notifier);
    final player = ref.read(playerProvider);
    final def = avatarFrameById(id);
    final isOwned = player.ownedDecorations.contains('avatar_frame_$id');
    if (!isOwned && def?.source == 'points' && (def?.points ?? 0) > 0) {
      final frameDef = def!;
      final shouldBuy = await _showLockedDecorationPreview(
        context,
        name: frameDef.name,
        preview: _DecorationAssetPreview(
          asset: frameDef.asset!,
          previewKey: const ValueKey('avatar-frame-preview'),
          aspectRatio: 1,
          maxWidth: 260,
          maxHeight: 260,
          backgroundColor: AppColors.surface2,
          borderColor: frameDef.color,
        ),
        points: frameDef.points,
      );
      if (!shouldBuy) return;
      final ok = await notifier.spendPoints(frameDef.points);
      if (!ok) {
        _showSnack('积分不足，可观看广告赚取积分');
        return;
      }
      await notifier.unlockAvatarFrame(id);
      await notifier.setActiveAvatarFrame(id);
      _showSnack('已购买并切换头像框：${frameDef.name}');
      return;
    }
    if (!isOwned) {
      if (def == null) return;
      await _showLockedDecorationPreview(
        context,
        name: def.name,
        preview: _DecorationAssetPreview(
          asset: def.asset!,
          previewKey: const ValueKey('avatar-frame-preview'),
          aspectRatio: 1,
          maxWidth: 260,
          maxHeight: 260,
          backgroundColor: AppColors.surface2,
          borderColor: def.color,
        ),
        unlockMessage: '该头像框为 Lv.${def.unlockLevel} 升级奖励，达到等级后解锁',
      );
      return;
    }
    await notifier.setActiveAvatarFrame(id);
    _showSnack('已切换头像框：${def?.name ?? id}');
  }

  Future<void> _onBackgroundTap(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final notifier = ref.read(playerProvider.notifier);
    final player = ref.read(playerProvider);
    final def = backgroundById(id);
    if (id == 'default') {
      await notifier.setActiveBackground(id);
      _showSnack('已切换背景：${def?.name ?? '默认'}');
      return;
    }
    final isOwned = player.ownedDecorations.contains('background_$id');
    if (!isOwned && def != null) {
      final shouldBuy = await _showLockedDecorationPreview(
        context,
        name: def.name,
        preview: _DecorationAssetPreview(
          asset: def.asset,
          previewKey: const ValueKey('background-preview'),
          aspectRatio: 941 / 1672,
          maxWidth: 220,
          maxHeight: 310,
        ),
        points: def.points,
      );
      if (!shouldBuy) return;
      final ok = await notifier.spendPoints(def.points);
      if (!ok) {
        _showSnack('积分不足，可观看广告赚取积分');
        return;
      }
      await notifier.unlockBackground(id);
      await notifier.setActiveBackground(id);
      _showSnack('已购买并切换背景：${def.name}');
      return;
    }
    await notifier.setActiveBackground(id);
    _showSnack('已切换背景：${def?.name ?? id}');
  }

  Future<void> _onEffectTap(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final notifier = ref.read(playerProvider.notifier);
    final player = ref.read(playerProvider);
    final def = titleEffectById(id);
    if (!player.ownedDecorations.contains('title_effect_$id')) {
      if (def == null) return;
      await _showLockedDecorationPreview(
        context,
        name: def.name,
        preview: _TitleEffectPreview(def: def),
        unlockMessage: '该称号特效为 Lv.${def.unlockLevel} 升级奖励，达到等级后解锁',
      );
      return;
    }
    await notifier.setActiveTitleEffect(id);
    _showSnack('已切换称号特效：${def?.name ?? id}');
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final hintCards = player.functionalItems['hint_card'] ?? 0;
    final reviveCards = player.functionalItems['revive_card'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
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
                              style: bodyStyle(
                                size: 11.5,
                                color: AppColors.muted,
                              ),
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
                          iconName: 'hint',
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
                  const SectionTitle(
                    title: '功能道具',
                    trailing: BadgeSoft('积分购买'),
                  ),
                  _FunctionalCard(
                    children: [
                      _PackTile(
                        iconName: 'hint',
                        name: '提示卡 ×1',
                        desc: '显示当前空格的正确字',
                        price: '$kHintCardPoints 积分',
                        onBuy: () => _buyFunctional(
                          context,
                          ref,
                          points: kHintCardPoints,
                          hintCards: 1,
                        ),
                      ),
                      _PackTile(
                        iconName: 'revive',
                        name: '复活卡 ×1',
                        desc: '恢复所有生命值',
                        price: '$kReviveCardPoints 积分',
                        onBuy: () => _buyFunctional(
                          context,
                          ref,
                          points: kReviveCardPoints,
                          reviveCards: 1,
                        ),
                      ),
                      _PackTile(
                        iconName: 'star',
                        name: '备考礼盒',
                        desc: '提示×3 + 复活×1',
                        price: '$kGiftBoxPoints 积分',
                        onBuy: () => _buyFunctional(
                          context,
                          ref,
                          points: kGiftBoxPoints,
                          hintCards: 3,
                          reviveCards: 1,
                        ),
                      ),
                    ],
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
                  _BackgroundsCard(
                    owned: player.ownedDecorations,
                    active: player.activeBackground,
                    onSelect: (id) => _onBackgroundTap(context, ref, id),
                  ),
                  _FramesCard(
                    owned: player.ownedDecorations,
                    active: player.activeAvatarFrame,
                    onSelect: (id) => _onFrameTap(context, ref, id),
                  ),
                  _EffectsCard(
                    owned: player.ownedDecorations,
                    active: player.activeTitleEffect,
                    onSelect: (id) => _onEffectTap(context, ref, id),
                  ),
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
            BannerAdView(active: widget.bannerActive),
          ],
        ),
      ),
    );
  }
}

class _LockedDecorationDialog extends StatelessWidget {
  final String name;
  final Widget preview;
  final int? points;
  final String? unlockMessage;

  const _LockedDecorationDialog({
    required this.name,
    required this.preview,
    this.points,
    this.unlockMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ThemeDialog(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 360,
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name预览',
              style: displayStyle(size: 20, weight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            Flexible(child: Center(child: preview)),
            const SizedBox(height: 18),
            if (points case final price?)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$price 积分',
                      style: displayStyle(
                        size: 16,
                        weight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 112,
                    child: PrimaryButton(
                      label: '购买',
                      small: true,
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              )
            else ...[
              Text(
                unlockMessage!,
                style: bodyStyle(size: 14, color: AppColors.fg),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: '确定',
                  small: true,
                  onTap: () => Navigator.of(context).pop(false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GridSkinPreview extends StatelessWidget {
  final GridSkin skin;

  const _GridSkinPreview({required this.skin});

  // 固定三成语：一心一意（横）、心想事成和意气风发（竖）。
  static const _characters = <String?>[
    '一',
    '心',
    '一',
    '意',
    null,
    '想',
    null,
    '气',
    null,
    '事',
    null,
    '风',
    null,
    '成',
    null,
    '发',
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        key: const ValueKey('grid-skin-preview'),
        constraints: const BoxConstraints(maxWidth: 240, maxHeight: 240),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: skin.surface2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: skin.border),
        ),
        child: AspectRatio(
          aspectRatio: 1,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
            ),
            itemCount: _characters.length,
            itemBuilder: (context, index) {
              final character = _characters[index];
              if (character == null) return const SizedBox.shrink();
              final intersection = index == 1 || index == 3;
              return Padding(
                padding: const EdgeInsets.all(2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: intersection
                        ? Color.lerp(skin.surface2, Colors.black, 0.08)
                        : skin.surface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: skin.borderStrong),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          character,
                          style: TextStyle(
                            fontFamily: kSerif,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: skin.foreground,
                          ),
                        ),
                      ),
                      if (intersection)
                        Positioned(
                          right: 5,
                          top: 5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: skin.accent,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox.square(dimension: 5),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DecorationAssetPreview extends StatelessWidget {
  final String asset;
  final Key previewKey;
  final double aspectRatio;
  final double maxWidth;
  final double maxHeight;
  final Color? backgroundColor;
  final Color? borderColor;

  const _DecorationAssetPreview({
    required this.asset,
    required this.previewKey,
    required this.aspectRatio,
    required this.maxWidth,
    required this.maxHeight,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: borderColor == null
                ? null
                : Border.all(color: borderColor!),
          ),
          child: Image.asset(asset, key: previewKey, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _TitleEffectPreview extends StatelessWidget {
  final TitleEffectDef def;

  const _TitleEffectPreview({required this.def});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 300, minHeight: 140),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        def.name,
        key: const ValueKey('title-effect-preview'),
        style: applyTitleEffect(
          def.id,
          displayStyle(
            size: 28,
            weight: FontWeight.w900,
            color: AppColors.accentDeep,
          ),
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
                Text(
                  '我的积分',
                  style: bodyStyle(size: 11, color: AppColors.muted),
                ),
                Text(
                  '$points',
                  style: displayStyle(size: 22, weight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 5),
              Text(
                '$watchedToday/$kRewardedAdMaxPerDay',
                style: bodyStyle(size: 10.5, color: AppColors.faint),
              ),
            ],
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

class _FunctionalCard extends StatelessWidget {
  final List<Widget> children;
  const _FunctionalCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [...children],
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  final String iconName;
  final String name;
  final String desc;
  final String price;
  final VoidCallback onBuy;
  const _PackTile({
    required this.iconName,
    required this.name,
    required this.desc,
    required this.price,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kShopItemHeight,
      margin: const EdgeInsets.only(top: 5, bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accentPale,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderStrong),
            ),
            child: Center(
              child: AppIcon(iconName, size: 22, color: AppColors.accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name, style: bodyStyle(size: 14, weight: FontWeight.w600)),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: bodyStyle(size: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _PurchaseBlock(priceText: price, onBuy: onBuy),
        ],
      ),
    );
  }
}

class _PurchaseBlock extends StatelessWidget {
  final String priceText;
  final VoidCallback onBuy;
  final Color? priceColor;
  const _PurchaseBlock({
    required this.priceText,
    required this.onBuy,
    this.priceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          priceText,
          style: displayStyle(
            size: 14,
            weight: FontWeight.w700,
            color: priceColor ?? AppColors.accent,
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
    final adSkins = gridSkins.where((s) => s.source == 'ads').toList()
      ..sort(
        (a, b) =>
            (kAdSkinPoints[a.id] ?? 0).compareTo(kAdSkinPoints[b.id] ?? 0),
      );
    return AppCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('网格皮肤', style: bodyStyle(size: 14, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          Text('等级皮肤', style: bodyStyle(size: 11.5, color: AppColors.muted)),
          const SizedBox(height: 6),
          for (final skin in gridSkins.where((s) => s.source == 'level'))
            _skinTile(skin),
          const SizedBox(height: 6),
          Text('积分兑换', style: bodyStyle(size: 11.5, color: AppColors.muted)),
          const SizedBox(height: 6),
          for (final skin in adSkins) _skinTile(skin),
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
    final priceColor = skin.surface.computeLuminance() < 0.5
        ? skin.accent
        : AppColors.accent;
    final statusText = isActive
        ? '当前使用'
        : isOwned
        ? '已拥有'
        : isLevelSkin
        ? 'Lv.$unlockLevel 升级奖励'
        : '积分购买';
    return GestureDetector(
      onTap: () => onSelect(skin.id),
      child: Container(
        height: kShopItemHeight,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                mainAxisAlignment: MainAxisAlignment.center,
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
            else if (!isOwned && !isLevelSkin && price > 0)
              _PurchaseBlock(
                priceText: '$price 积分',
                priceColor: priceColor,
                onBuy: () => onSelect(skin.id),
              )
            else if (!isOwned)
              BadgeSoft('Lv.$unlockLevel', color: BadgeSoftColor.leaf),
          ],
        ),
      ),
    );
  }
}

/// 头像框选择卡
class _FramesCard extends StatelessWidget {
  final Set<String> owned;
  final String? active;
  final ValueChanged<String> onSelect;
  const _FramesCard({
    required this.owned,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final levelFrames = avatarFrames.where((f) => f.source == 'level').toList()
      ..sort((a, b) => a.unlockLevel.compareTo(b.unlockLevel));
    final pointFrames = avatarFrames.where((f) => f.source == 'points').toList()
      ..sort((a, b) => a.points.compareTo(b.points));
    return _DecoCard(
      title: '头像框',
      hint: '',
      children: [
        Text('等级奖励', style: bodyStyle(size: 11.5, color: AppColors.muted)),
        const SizedBox(height: 6),
        for (final frame in levelFrames)
          _DecoTile(
            glyph: '冠',
            name: frame.name,
            frameDef: frame,
            statusText: active == frame.id
                ? '使用中'
                : owned.contains('avatar_frame_${frame.id}')
                ? '已拥有'
                : 'Lv.${frame.unlockLevel} 升级奖励',
            isActive: active == frame.id,
            isOwned: owned.contains('avatar_frame_${frame.id}'),
            unlockLevel: frame.unlockLevel,
            onTap: () => onSelect(frame.id),
          ),
        const SizedBox(height: 6),
        Text('积分购买', style: bodyStyle(size: 11.5, color: AppColors.muted)),
        const SizedBox(height: 6),
        for (final frame in pointFrames)
          _DecoTile(
            glyph: '冠',
            name: frame.name,
            frameDef: frame,
            statusText: active == frame.id
                ? '使用中'
                : owned.contains('avatar_frame_${frame.id}')
                ? '已拥有'
                : '积分购买',
            isActive: active == frame.id,
            isOwned: owned.contains('avatar_frame_${frame.id}'),
            unlockLevel: frame.unlockLevel,
            onTap: () => onSelect(frame.id),
          ),
      ],
    );
  }
}

/// 称号特效选择卡
class _EffectsCard extends StatelessWidget {
  final Set<String> owned;
  final String? active;
  final ValueChanged<String> onSelect;
  const _EffectsCard({
    required this.owned,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return _DecoCard(
      title: '称号特效',
      hint: '',
      children: [
        for (final effect in titleEffects)
          _DecoTile(
            glyph: '耀',
            name: effect.name,
            effectDef: effect,
            statusText: active == effect.id
                ? '使用中'
                : owned.contains('title_effect_${effect.id}')
                ? '已拥有'
                : 'Lv.${effect.unlockLevel} 升级奖励',
            isActive: active == effect.id,
            isOwned: owned.contains('title_effect_${effect.id}'),
            unlockLevel: effect.unlockLevel,
            onTap: () => onSelect(effect.id),
          ),
      ],
    );
  }
}

class _DecoCard extends StatelessWidget {
  final String title;
  final String hint;
  final List<Widget> children;
  const _DecoCard({
    required this.title,
    required this.hint,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: bodyStyle(size: 14, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          Offstage(
            offstage: hint == '',
            child: Text(
              hint,
              style: bodyStyle(size: 11, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DecoTile extends StatelessWidget {
  final String glyph;
  final String name;
  final AvatarFrameDef? frameDef;
  final TitleEffectDef? effectDef;
  final String statusText;
  final bool isActive;
  final bool isOwned;
  final int unlockLevel;
  final VoidCallback onTap;
  const _DecoTile({
    required this.glyph,
    required this.name,
    this.frameDef,
    this.effectDef,
    required this.statusText,
    required this.isActive,
    required this.isOwned,
    required this.unlockLevel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final frame = frameDef;
    final effect = effectDef;
    final lockBadge = frame != null && frame.source == 'points'
        ? '${frame.points} 积分'
        : 'Lv.$unlockLevel';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: kShopItemHeight,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? AppColors.accent : AppColors.border,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: frame?.color ?? AppColors.borderStrong,
                  width: 1,
                ),
                boxShadow: frame == null
                    ? null
                    : [
                        BoxShadow(
                          color: frame.glow,
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
              ),
              child: Center(
                child: frame?.asset != null
                    ? Image.asset(
                        frame!.asset!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Text(
                          glyph,
                          style: TextStyle(
                            fontFamily: kSerif,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: effect?.textColor ?? AppColors.accentDeep,
                          ),
                        ),
                      )
                    : Text(
                        glyph,
                        style: TextStyle(
                          fontFamily: kSerif,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: effect?.textColor ?? AppColors.accentDeep,
                          shadows: effect == null
                              ? null
                              : [
                                  Shadow(
                                    color: effect.glow.withValues(alpha: 0.75),
                                    blurRadius: 8,
                                  ),
                                  Shadow(
                                    color: effect.glow.withValues(alpha: 0.4),
                                    blurRadius: 16,
                                  ),
                                ],
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    style: bodyStyle(size: 14, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    style: bodyStyle(size: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (isActive)
              BadgeSoft('使用中', color: BadgeSoftColor.gold)
            else if (!isOwned &&
                frame?.source == 'points' &&
                (frame?.points ?? 0) > 0)
              _PurchaseBlock(priceText: '${frame!.points} 积分', onBuy: onTap)
            else if (!isOwned)
              BadgeSoft(lockBadge, color: BadgeSoftColor.leaf),
          ],
        ),
      ),
    );
  }
}

/// 游戏背景选择卡
class _BackgroundsCard extends StatelessWidget {
  final Set<String> owned;
  final String active;
  final ValueChanged<String> onSelect;

  const _BackgroundsCard({
    required this.owned,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return _DecoCard(
      title: '背景',
      hint: '点击切换游戏背景',
      children: [
        for (final bg in backgrounds)
          _BackgroundTile(
            bg: bg,
            isActive: active == bg.id,
            isOwned:
                bg.id == 'default' || owned.contains('background_${bg.id}'),
            onTap: () => onSelect(bg.id),
          ),
      ],
    );
  }
}

class _BackgroundTile extends StatelessWidget {
  final BackgroundDef bg;
  final bool isActive;
  final bool isOwned;
  final VoidCallback onTap;

  const _BackgroundTile({
    required this.bg,
    required this.isActive,
    required this.isOwned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = isActive
        ? '使用中'
        : bg.id == 'default'
        ? '默认'
        : isOwned
        ? '已拥有'
        : '积分购买';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: kShopItemHeight,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? AppColors.accent : AppColors.border,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Image.asset(bg.asset, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    bg.name,
                    style: bodyStyle(size: 14, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    style: bodyStyle(size: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (isActive)
              BadgeSoft('使用中', color: BadgeSoftColor.gold)
            else if (!isOwned)
              _PurchaseBlock(priceText: '${bg.points} 积分', onBuy: onTap),
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
  const _IconBox({
    required this.iconName,
    required this.bg,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: AppIcon(iconName, size: 20, color: color)),
    );
  }
}

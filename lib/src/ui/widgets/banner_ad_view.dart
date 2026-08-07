import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../state/player_state.dart';
import '../../utils/ad_manager.dart';

/// 页面底部横幅广告
///
/// 每个页面持有独立 BannerAd 实例，页面销毁时自动释放。
/// 非移动端或广告未就绪时渲染为空，不影响页面布局。
class BannerAdView extends ConsumerStatefulWidget {
  /// 当前页面是否处于可见 Tab（避免 IndexedStack 中多个横幅同时累计积分）
  final bool active;

  const BannerAdView({super.key, this.active = true});

  @override
  ConsumerState<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends ConsumerState<BannerAdView>
    with WidgetsBindingObserver {
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  bool _canShowAds = false;
  bool _appForeground = true;
  Timer? _accrualTimer;
  int _accruedSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBannerAd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accrualTimer?.cancel();
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(BannerAdView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _syncAccrual();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appForeground = state == AppLifecycleState.resumed;
    _syncAccrual();
  }

  /// 横幅可见时每累计 60 秒发放 1 积分（受每日上限约束）
  void _syncAccrual() {
    _accrualTimer?.cancel();
    _accrualTimer = null;
    if (!widget.active ||
        !_canShowAds ||
        !_isBannerLoaded ||
        !_appForeground) {
      _accruedSeconds = 0;
      return;
    }
    _accrualTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !widget.active || !_appForeground) return;
      _accruedSeconds++;
      if (_accruedSeconds >= 60) {
        _accruedSeconds -= 60;
        unawaited(
          ref.read(playerProvider.notifier).addBannerPoints(1),
        );
      }
    });
  }

  Future<void> _loadBannerAd() async {
    if (!AdManager.isSupportedPlatform) return;
    try {
      _canShowAds = await AdManager().canRequestAds();
    } catch (_) {
      return;
    }
    if (!mounted || !_canShowAds) return;
    final ad = AdManager().createBannerAd(
      onAdLoaded: (ad) {
        if (mounted) {
          setState(() => _isBannerLoaded = true);
          _syncAccrual();
        }
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        if (mounted) {
          setState(() => _isBannerLoaded = false);
          _syncAccrual();
        }
      },
    );
    _bannerAd = ad;
    ad.load();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (!_canShowAds || !_isBannerLoaded || ad == null) {
      return const SizedBox(height: 0);
    }
    return Container(
      width: double.infinity,
      color: const Color(0xFFF0E9DC),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AdManager().buildBannerAdWidget(ad),
    );
  }
}

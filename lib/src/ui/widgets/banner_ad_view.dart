import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../audio/audio_route_observer.dart';
import '../../state/player_state.dart';
import '../../utils/ad_manager.dart';

@visibleForTesting
Duration bannerAdRetryDelay(int retryAttempt) => switch (retryAttempt) {
  0 => const Duration(seconds: 15),
  1 => const Duration(seconds: 30),
  _ => const Duration(minutes: 1),
};

@visibleForTesting
bool canAccrueBannerPoints({
  required bool active,
  required bool canShowAds,
  required bool isBannerLoaded,
  required bool appForeground,
  required bool routeVisible,
}) => active && canShowAds && isBannerLoaded && appForeground && routeVisible;

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
    with WidgetsBindingObserver, RouteAware {
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  bool _canShowAds = false;
  bool _appForeground = true;
  bool _routeVisible = true;
  PageRoute<dynamic>? _subscribedRoute;
  Timer? _accrualTimer;
  Timer? _bannerAdRetryTimer;
  int _bannerAdRetryAttempt = 0;
  int _accruedSeconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBannerAd();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute<dynamic> && route != _subscribedRoute) {
      if (_subscribedRoute != null) appRouteObserver.unsubscribe(this);
      _subscribedRoute = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPushNext() {
    _routeVisible = false;
    _syncAccrual();
  }

  @override
  void didPopNext() {
    _routeVisible = true;
    _syncAccrual();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _accrualTimer?.cancel();
    _bannerAdRetryTimer?.cancel();
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
    if (!canAccrueBannerPoints(
      active: widget.active,
      canShowAds: _canShowAds,
      isBannerLoaded: _isBannerLoaded,
      appForeground: _appForeground,
      routeVisible: _routeVisible,
    )) {
      _accruedSeconds = 0;
      return;
    }
    _accrualTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted ||
          !canAccrueBannerPoints(
            active: widget.active,
            canShowAds: _canShowAds,
            isBannerLoaded: _isBannerLoaded,
            appForeground: _appForeground,
            routeVisible: _routeVisible,
          )) {
        return;
      }
      _accruedSeconds++;
      if (_accruedSeconds >= 60) {
        _accruedSeconds -= 60;
        unawaited(ref.read(playerProvider.notifier).addBannerPoints(1));
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
          _bannerAdRetryTimer?.cancel();
          _bannerAdRetryTimer = null;
          _bannerAdRetryAttempt = 0;
          setState(() => _isBannerLoaded = true);
          _syncAccrual();
        }
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        if (mounted) {
          _bannerAd = null;
          setState(() => _isBannerLoaded = false);
          _syncAccrual();
          _scheduleBannerAdRetry();
        }
      },
    );
    _bannerAd = ad;
    ad.load();
  }

  void _scheduleBannerAdRetry() {
    if (_bannerAdRetryTimer != null) return;
    final retryDelay = bannerAdRetryDelay(_bannerAdRetryAttempt);
    _bannerAdRetryAttempt++;
    _bannerAdRetryTimer = Timer(retryDelay, () {
      _bannerAdRetryTimer = null;
      unawaited(_loadBannerAd());
    });
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../audio/audio_route_observer.dart';
import '../../utils/ad_manager.dart';
import 'dirichlet_banner_view.dart';

@visibleForTesting
Duration bannerAdRetryDelay(int retryAttempt) => switch (retryAttempt) {
  0 => const Duration(seconds: 15),
  1 => const Duration(seconds: 30),
  _ => const Duration(minutes: 1),
};

/// 页面底部横幅广告
///
/// 每个页面持有独立 BannerAd 实例，页面销毁时自动释放。
/// 非移动端或广告未就绪时渲染为空，不影响页面布局。
class BannerAdView extends ConsumerStatefulWidget {
  /// 当前页面是否处于可见 Tab
  final bool active;

  const BannerAdView({super.key, this.active = true});

  @override
  ConsumerState<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends ConsumerState<BannerAdView>
    with WidgetsBindingObserver, RouteAware {
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;
  bool _dirichletFailed = false;
  bool _dirichletClosed = false;
  int _dirichletViewGeneration = 0;
  bool _canShowAds = false;
  bool _appForeground = true;
  bool _routeVisible = true;
  PageRoute<dynamic>? _subscribedRoute;
  Timer? _bannerAdRetryTimer;
  int _bannerAdRetryAttempt = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdManager().isDirichletFullScreenShowing.addListener(_fullScreenChanged);
    AdManager().adPrivacyChanged.addListener(_reloadForPrivacy);
    AdManager().adsRemovedNotifier.addListener(_reloadForPrivacy);
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
    _refreshDirichletVisibility();
  }

  @override
  void didPopNext() {
    _routeVisible = true;
    _refreshDirichletVisibility();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    AdManager().isDirichletFullScreenShowing.removeListener(_fullScreenChanged);
    AdManager().adPrivacyChanged.removeListener(_reloadForPrivacy);
    AdManager().adsRemovedNotifier.removeListener(_reloadForPrivacy);
    WidgetsBinding.instance.removeObserver(this);
    _bannerAdRetryTimer?.cancel();
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(BannerAdView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _refreshDirichletVisibility();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appForeground = state == AppLifecycleState.resumed;
    _refreshDirichletVisibility();
  }

  void _fullScreenChanged() {
    _refreshDirichletVisibility();
  }

  void _reloadForPrivacy() {
    _bannerAdRetryTimer?.cancel();
    _bannerAdRetryTimer = null;
    _bannerAd?.dispose();
    _bannerAd = null;
    setState(() {
      _canShowAds = false;
      _isBannerLoaded = false;
      _dirichletClosed = false;
    });
    unawaited(_loadBannerAd());
  }

  void _refreshDirichletVisibility() {
    if (!AdManager().usesDirichlet) return;
    // The native view is removed while hidden; don't count stale impressions.
    setState(() {
      _isBannerLoaded = false;
      _dirichletViewGeneration++;
    });
  }

  Future<void> _loadBannerAd() async {
    if (!AdManager.isSupportedPlatform) return;
    try {
      _canShowAds = await AdManager().canRequestAds();
    } catch (_) {
      if (mounted) _scheduleBannerAdRetry();
      return;
    }
    if (!mounted) return;
    if (!_canShowAds) {
      _scheduleBannerAdRetry();
      return;
    }
    if (AdManager().usesDirichlet) {
      setState(() => _dirichletFailed = false);
      return;
    }
    final ad = AdManager().createBannerAd(
      onAdLoaded: (ad) {
        if (mounted) {
          _bannerAdRetryTimer?.cancel();
          _bannerAdRetryTimer = null;
          _bannerAdRetryAttempt = 0;
          setState(() => _isBannerLoaded = true);
        }
      },
      onAdFailedToLoad: (ad, error) {
        ad.dispose();
        if (mounted) {
          _bannerAd = null;
          setState(() => _isBannerLoaded = false);
          _scheduleBannerAdRetry();
        }
      },
    );
    _bannerAd = ad;
    ad.load();
  }

  void _scheduleBannerAdRetry() {
    if (!AdManager().shouldRetryAds || _bannerAdRetryTimer != null) return;
    final retryDelay = bannerAdRetryDelay(_bannerAdRetryAttempt);
    _bannerAdRetryAttempt++;
    _bannerAdRetryTimer = Timer(retryDelay, () {
      _bannerAdRetryTimer = null;
      unawaited(_loadBannerAd());
    });
  }

  @override
  Widget build(BuildContext context) {
    if (AdManager().usesDirichlet) {
      if (!_canShowAds ||
          !widget.active ||
          !_appForeground ||
          !_routeVisible ||
          _dirichletFailed ||
          _dirichletClosed ||
          AdManager().isDirichletFullScreenShowing.value) {
        return const SizedBox.shrink();
      }
      return Container(
        width: double.infinity,
        color: const Color(0xFFF0E9DC),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SafeArea(
          child: Center(
            child: DirichletBannerView(
              key: ValueKey(_dirichletViewGeneration),
              onShown: () {
                if (!mounted) return;
                _bannerAdRetryAttempt = 0;
                setState(() => _isBannerLoaded = true);
              },
              onFailed: () {
                if (!mounted) return;
                setState(() {
                  _isBannerLoaded = false;
                  _dirichletFailed = true;
                });
                _scheduleBannerAdRetry();
              },
              onClosed: () {
                if (!mounted) return;
                setState(() {
                  _isBannerLoaded = false;
                  _dirichletClosed = true;
                });
              },
            ),
          ),
        ),
      );
    }
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

import 'dart:async';
import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:logger/logger.dart';
import 'package:dirichlet_ads/dirichlet_ads.dart';
import 'ad_region.dart';

/// 广告管理类
class AdManager with WidgetsBindingObserver {
  static final AdManager _instance = AdManager._internal();
  factory AdManager() => _instance;

  AdManager._internal() {
    _dirichlet.rewardReady.addListener(() {
      if (usesDirichlet) {
        isRewardedAdReadyNotifier.value = _dirichlet.rewardReady.value;
      }
    });
  }

  final DirichletAds _dirichlet = DirichletAds();
  bool usesDirichlet = false;
  bool _adsRemoved = false;
  final ValueNotifier<bool> isDirichletFullScreenShowing = ValueNotifier(false);

  /// 广告 SDK 仅支持 Android / iOS（Web 与桌面直接跳过）
  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  final Logger _logger = Logger();

  // 用于监听广告加载状态的通知器
  final ValueNotifier<bool> isBannerAdLoadedNotifier = ValueNotifier<bool>(
    false,
  );

  /// 激励广告是否已经可以立即展示。
  final ValueNotifier<bool> isRewardedAdReadyNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<int> adsRemovedNotifier = ValueNotifier<int>(0);
  // 广告单位ID
  // 横幅广告ID, android
  String _bannerAdUnitId = 'ca-app-pub-5534836333837678/7104085737';
  // 激励视频广告ID, android
  String _rewardedAdUnitId = 'ca-app-pub-5534836333837678/4514481146';
  // 插页式广告ID, android
  String _interstitialAdUnitId = 'ca-app-pub-5534836333837678/7573524174';

  // 广告实例
  BannerAd? _bannerAd;
  RewardedAd? _rewardedAd;
  InterstitialAd? _interstitialAd;

  // 广告加载状态
  bool _isRewardedAdLoaded = false;
  bool _isInterstitialAdLoaded = false;
  bool _isInterstitialAdLoading = false;
  bool _isInitialized = false;
  bool? _canRequestAdsCached;
  Future<void>? _initializationFuture;
  Future<bool>? _rewardedAdLoadFuture;
  VoidCallback? _rewardedAdClosedCallback;
  Timer? _rewardedAdRetryTimer;
  int _rewardedAdRetryAttempt = 0;

  bool get shouldRetryAds =>
      !_adsRemoved && !(_isInitialized && _canRequestAdsCached == false);

  bool get isInterstitialAdReady => usesDirichlet
      ? _dirichlet.interstitialReady.value
      : _interstitialAd != null && _isInterstitialAdLoaded;

  Future<void> initialize() async {
    if (_adsRemoved || _isInitialized) {
      return;
    }
    final active = _initializationFuture;
    if (active != null) return active;
    final initialization = _initialize().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      _logger.e('广告初始化失败', error: error, stackTrace: stackTrace);
      _canRequestAdsCached = false;
    });
    _initializationFuture = initialization;
    try {
      await initialization;
    } finally {
      if (identical(_initializationFuture, initialization)) {
        _initializationFuture = null;
      }
    }
  }

  Future<void> _initialize() async {
    // 1. 增加平台检查：如果不是移动端，直接返回，不执行任何广告逻辑
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _logger.i('当前平台不支持广告 SDK，跳过初始化');
      _isInitialized = true;
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isIOS) {
      // NSLocale.currentLocale reflects Settings > General > Language & Region.
      // A bridge failure must not accidentally initialize Google in mainland China.
      final region = await _dirichlet.systemRegion();
      if (region == null || region.isEmpty) {
        throw StateError('无法读取 iOS 系统地区');
      }
      usesDirichlet = usesDirichletForRegion(region);
      _logger.i(
        '广告分流: systemRegion=$region, provider=${usesDirichlet ? "Dirichlet" : "AdMob"}',
      );
      if (usesDirichlet) {
        await WidgetsBinding.instance.endOfFrame;
        final accepted = await _dirichlet.requestConsent();
        _canRequestAdsCached = accepted && await _dirichlet.initialize();
        _isInitialized = !accepted || _canRequestAdsCached!;
        if (_canRequestAdsCached! && !_adsRemoved) {
          unawaited(loadRewardedAd());
        }
        return;
      }
    }
    if (Platform.isIOS) {
      // ios 平台使用不同的广告单位ID
      _bannerAdUnitId = 'ca-app-pub-5534836333837678/2782055476';
      _rewardedAdUnitId = 'ca-app-pub-5534836333837678/3903565451';
      _interstitialAdUnitId = 'ca-app-pub-5534836333837678/7573524174';
    }
    // 测试id
    if (kDebugMode) {
      if (Platform.isIOS) {
        _bannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716';
        _rewardedAdUnitId = 'ca-app-pub-3940256099942544/1712485313';
        _interstitialAdUnitId = 'ca-app-pub-3940256099942544/4411468910';
      } else {
        _bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
        _rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
        _interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
      }
    }
    // 1. 定义隐私请求参数
    // 如果是测试阶段，可以强制开启调试，模拟欧盟地区
    final params = ConsentRequestParameters(
      consentDebugSettings: kDebugMode
          ? ConsentDebugSettings(
              debugGeography: DebugGeography.debugGeographyEea,
              testIdentifiers: ['905C6FA8A84C219BB8A54CFFEED8B03C'],
            )
          : null,
    );

    final completer = Completer<void>();

    // 2. 请求隐私状态更新
    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        // 检查是否可以弹出隐私确认窗
        bool isConsentFormAvailable = await ConsentInformation.instance
            .isConsentFormAvailable();
        if (isConsentFormAvailable) {
          await _loadAndShowConsentForm();
        } else {
          // 如果不需要弹窗，直接初始化广告
          await _initializeMobileAds();
        }
        _isInitialized = true;
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) async {
        _logger.e('隐私状态更新失败: ${error.message}');
        // 即使隐私请求失败，通常也尝试初始化广告（可能只展示非个性化广告）
        await _initializeMobileAds();
        _isInitialized = true;
        if (!completer.isCompleted) completer.complete();
      },
    );

    await completer.future;
  }

  Future<bool> canRequestAds() async {
    if (!isSupportedPlatform || _adsRemoved) return false;
    await initialize();
    if (_adsRemoved) return false;
    if (usesDirichlet) return _canRequestAdsCached == true;
    if (_canRequestAdsCached != null) {
      return _canRequestAdsCached!;
    }
    _canRequestAdsCached = await ConsentInformation.instance.canRequestAds();
    return _canRequestAdsCached!;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (usesDirichlet &&
        state == AppLifecycleState.resumed &&
        _canRequestAdsCached == true &&
        !_adsRemoved) {
      unawaited(loadRewardedAd());
    }
    if (state == AppLifecycleState.detached) {
      _logger.i('检测到detached，开始释放所有广告资源...');
      disposeAllAds();
    }
  }

  /// 加载并显示隐私同意表单
  Future<void> _loadAndShowConsentForm() async {
    final completer = Completer<void>();
    ConsentForm.loadConsentForm(
      (ConsentForm consentForm) async {
        // 获取当前的同意状态
        var status = await ConsentInformation.instance.getConsentStatus();

        if (status == ConsentStatus.required) {
          // 如果是必须同意（欧盟用户），则显示表单
          consentForm.show((formError) async {
            if (formError != null) {
              _logger.e('隐私表单显示失败: ${formError.message}');
            }
            // 无论显示结果如何，最后都初始化 MobileAds
            await _initializeMobileAds();
            if (!completer.isCompleted) completer.complete();
          });
        } else {
          // 已经同意过或不需要同意
          await _initializeMobileAds();
          if (!completer.isCompleted) completer.complete();
        }
      },
      (FormError error) async {
        _logger.e('隐私表单加载失败: ${error.message}');
        await _initializeMobileAds();
        if (!completer.isCompleted) completer.complete();
      },
    );
    await completer.future;
  }

  /// 最终初始化 MobileAds SDK
  Future<void> _initializeMobileAds() async {
    try {
      // 检查是否可以展示广告（必须符合隐私要求）
      bool canRequestAds = await ConsentInformation.instance.canRequestAds();
      _canRequestAdsCached = canRequestAds;
      if (!canRequestAds) {
        _logger.w('根据当前隐私设置，无法请求广告');
        return;
      }

      // 如果是iOS平台，需要ATT请求
      if (Platform.isIOS) {
        final status =
            await AppTrackingTransparency.trackingAuthorizationStatus;

        // 如果尚未请求，则弹出iOS系统弹窗
        if (status == TrackingStatus.notDetermined) {
          await AppTrackingTransparency.requestTrackingAuthorization();
        }
      }

      // 原有的初始化逻辑
      RequestConfiguration configuration = RequestConfiguration(
        // 没有年龄验证，不主动断言用户所属的年龄限制类别
        ageRestrictedTreatment: AgeRestrictedTreatment.unspecified,

        // App Store 13+，允许投放适合青少年及以上的广告
        maxAdContentRating: MaxAdContentRating.t,
      );
      MobileAds.instance.updateRequestConfiguration(configuration);
      await MobileAds.instance.initialize();
      _logger.i('AdMob SDK 初始化成功');

      // 加载广告
      unawaited(loadRewardedAd());
    } catch (e) {
      _logger.e('MobileAds 初始化异常: $e');
    }
  }

  /// 获取广告请求
  AdRequest getAdRequest() {
    return const AdRequest(
      keywords: <String>['game', 'puzzle', 'crossword', 'idiom'],
      contentUrl: 'http://sunnywarrior.top/idiom_crossword_support/',
    );
  }

  /// 创建一个新的 BannerAd 实例
  /// 这样每个页面都能拥有独立的 Ad 对象，互不干扰
  BannerAd createBannerAd({
    required void Function(Ad ad) onAdLoaded,
    required void Function(Ad ad, LoadAdError error) onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: _bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
        onAdOpened: (ad) {
          if (kDebugMode) {
            debugPrint('广告打开');
          }
        },
        onAdClosed: (ad) {
          if (kDebugMode) {
            debugPrint('广告关闭');
          }
        },
      ),
    );
  }

  /// 封装一个通用的 AdWidget 包装器
  Widget buildBannerAdWidget(BannerAd ad) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }

  // 销毁横幅广告
  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    isBannerAdLoadedNotifier.value = false;
  }

  void handleAdsRemoved() {
    _adsRemoved = true;
    _canRequestAdsCached = false;
    disposeAllAds();
    adsRemovedNotifier.value++;
  }

  /// 预加载激励视频广告，并合并同时发起的加载请求。
  Future<bool> loadRewardedAd() async {
    if (_rewardedAd != null && _isRewardedAdLoaded) {
      return true;
    }

    final activeLoad = _rewardedAdLoadFuture;
    if (activeLoad != null) {
      return activeLoad;
    }

    _rewardedAdRetryTimer?.cancel();
    _rewardedAdRetryTimer = null;
    final loadFuture = _loadRewardedAd();
    _rewardedAdLoadFuture = loadFuture;
    try {
      return await loadFuture;
    } catch (error, stackTrace) {
      _logger.e('激励视频广告加载流程异常', error: error, stackTrace: stackTrace);
      _scheduleRewardedAdRetry();
      return false;
    } finally {
      if (identical(_rewardedAdLoadFuture, loadFuture)) {
        _rewardedAdLoadFuture = null;
      }
    }
  }

  Future<bool> _loadRewardedAd() async {
    try {
      // 检查是否具备请求广告的隐私权限
      if (!(await canRequestAds())) {
        _logger.w('由于无权展示广告，取消激励广告加载');
        return false;
      }

      if (usesDirichlet) {
        final loaded = await _dirichlet.loadRewarded();
        if (loaded) {
          _rewardedAdRetryAttempt = 0;
        } else {
          _scheduleRewardedAdRetry();
        }
        return loaded;
      }
      final completer = Completer<bool>();
      RewardedAd.load(
        adUnitId: _rewardedAdUnitId,
        request: getAdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _logger.i('激励视频广告加载成功');
            _rewardedAdRetryTimer?.cancel();
            _rewardedAdRetryTimer = null;
            _rewardedAdRetryAttempt = 0;
            _isRewardedAdLoaded = true;
            _rewardedAd = ad;
            isRewardedAdReadyNotifier.value = true;

            // 设置激励视频广告监听器
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                _logger.i('激励视频广告显示');
              },
              onAdDismissedFullScreenContent: (ad) {
                _logger.i('激励视频广告关闭');
                _isRewardedAdLoaded = false;
                _rewardedAd = null;
                isRewardedAdReadyNotifier.value = false;
                ad.dispose();
                _rewardedAdClosedCallback?.call();
                _rewardedAdClosedCallback = null;
                // 预加载下一个激励视频广告
                unawaited(loadRewardedAd());
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                _logger.e('激励视频广告显示失败: $error');
                _isRewardedAdLoaded = false;
                _rewardedAd = null;
                isRewardedAdReadyNotifier.value = false;
                ad.dispose();
                _rewardedAdClosedCallback?.call();
                _rewardedAdClosedCallback = null;
                // 预加载下一个激励视频广告
                unawaited(loadRewardedAd());
              },
              onAdClicked: (ad) {
                _logger.i('激励视频广告被点击');
              },
            );
            if (!completer.isCompleted) completer.complete(true);
          },
          onAdFailedToLoad: (error) {
            _logger.e('激励视频广告加载失败: $error');
            _isRewardedAdLoaded = false;
            _rewardedAd = null;
            isRewardedAdReadyNotifier.value = false;
            _scheduleRewardedAdRetry();
            if (!completer.isCompleted) completer.complete(false);
          },
        ),
      );
      return await completer.future;
    } catch (error, stackTrace) {
      _logger.e('加载激励视频广告时出错', error: error, stackTrace: stackTrace);
      _scheduleRewardedAdRetry();
      return false;
    }
  }

  void _scheduleRewardedAdRetry() {
    if (!shouldRetryAds || _rewardedAdRetryTimer != null) {
      return;
    }
    final retryDelay = switch (_rewardedAdRetryAttempt) {
      0 => const Duration(seconds: 15),
      1 => const Duration(seconds: 30),
      _ => const Duration(minutes: 1),
    };
    _rewardedAdRetryAttempt++;
    _rewardedAdRetryTimer = Timer(retryDelay, () {
      _rewardedAdRetryTimer = null;
      unawaited(loadRewardedAd());
    });
  }

  // 显示激励视频广告
  bool showRewardedAd({
    required Function(String, int) onRewardEarned,
    VoidCallback? onAdClosed,
  }) {
    if (usesDirichlet) {
      if (_adsRemoved || _canRequestAdsCached != true) return false;
      final shown = _dirichlet.showRewarded(
        onRewardEarned: onRewardEarned,
        onAdClosed: () {
          isDirichletFullScreenShowing.value = false;
          onAdClosed?.call();
          unawaited(loadRewardedAd());
        },
      );
      if (shown) {
        isDirichletFullScreenShowing.value = true;
      } else {
        unawaited(loadRewardedAd());
      }
      return shown;
    }
    if (_rewardedAd != null && _isRewardedAdLoaded) {
      final ad = _rewardedAd!;
      _rewardedAd = null;
      _isRewardedAdLoaded = false;
      isRewardedAdReadyNotifier.value = false;
      _rewardedAdClosedCallback = onAdClosed;
      ad.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          _logger.i('用户获得奖励: ${reward.type}, ${reward.amount}');
          onRewardEarned(reward.type, reward.amount.toInt());
        },
      );
      return true;
    } else {
      _logger.w('激励视频广告未加载，无法显示');
      // 尝试重新加载
      unawaited(loadRewardedAd());
      return false;
    }
  }

  // 销毁激励视频广告
  void disposeRewardedAd() {
    if (usesDirichlet) unawaited(_dirichlet.disposeAds());
    _rewardedAdRetryTimer?.cancel();
    _rewardedAdRetryTimer = null;
    _rewardedAdRetryAttempt = 0;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isRewardedAdLoaded = false;
    _rewardedAdClosedCallback = null;
    isRewardedAdReadyNotifier.value = false;
  }

  /// 预加载插页式广告。
  Future<void> loadInterstitialAd() async {
    await initialize();
    if (usesDirichlet) {
      if (await canRequestAds()) await _dirichlet.loadInterstitial();
      return;
    }
    if (isInterstitialAdReady || _isInterstitialAdLoading) {
      return;
    }
    if (!(await canRequestAds())) {
      _logger.w('由于无权展示广告，取消插页式广告加载');
      return;
    }
    _isInterstitialAdLoading = true;
    try {
      await InterstitialAd.load(
        adUnitId: _interstitialAdUnitId,
        request: getAdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _logger.i('插页式广告加载成功');
            _isInterstitialAdLoading = false;
            _isInterstitialAdLoaded = true;
            _interstitialAd = ad;
          },
          onAdFailedToLoad: (error) {
            _logger.e('插页式广告加载失败: $error');
            _isInterstitialAdLoading = false;
            _isInterstitialAdLoaded = false;
            _interstitialAd = null;
          },
        ),
      );
    } catch (error, stackTrace) {
      _isInterstitialAdLoading = false;
      _logger.e('加载插页式广告时出错', error: error, stackTrace: stackTrace);
    }
  }

  /// 显示普通插页广告，不发放积分。
  bool showInterstitialAd({VoidCallback? onAdShown, VoidCallback? onAdClosed}) {
    if (usesDirichlet) {
      final shown = _dirichlet.showInterstitial(
        onAdShown: onAdShown,
        onAdClosed: () {
          isDirichletFullScreenShowing.value = false;
          onAdClosed?.call();
          unawaited(loadInterstitialAd());
        },
      );
      if (shown) isDirichletFullScreenShowing.value = true;
      return shown;
    }
    if (_interstitialAd != null && _isInterstitialAdLoaded) {
      final ad = _interstitialAd!;
      _interstitialAd = null;
      _isInterstitialAdLoaded = false;
      var adFinished = false;

      void finishAd() {
        if (adFinished) return;
        adFinished = true;
        ad.dispose();
        onAdClosed?.call();
        unawaited(loadInterstitialAd());
      }

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (ad) {
          _logger.i('插页式广告全屏内容显示');
          onAdShown?.call();
        },
        onAdDismissedFullScreenContent: (ad) {
          _logger.i('插页式广告全屏内容关闭');
          finishAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          _logger.e('插页式广告全屏内容显示失败: $error');
          finishAd();
        },
        onAdClicked: (ad) {
          _logger.i('插页式广告被点击');
        },
      );
      try {
        unawaited(
          ad.show().catchError((Object error, StackTrace stackTrace) {
            _logger.e('插页式广告显示异常', error: error, stackTrace: stackTrace);
            finishAd();
          }),
        );
      } catch (error, stackTrace) {
        _logger.e('插页式广告显示异常', error: error, stackTrace: stackTrace);
        finishAd();
      }
      return true;
    } else {
      _logger.w('插页式广告未加载，无法显示');
      unawaited(loadInterstitialAd());
      return false;
    }
  }

  /// 销毁插页式广告。
  void disposeInterstitialAd() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isInterstitialAdLoaded = false;
    _isInterstitialAdLoading = false;
  }

  // 销毁所有广告
  void disposeAllAds() {
    disposeBannerAd();
    disposeRewardedAd();
    disposeInterstitialAd();
  }
}

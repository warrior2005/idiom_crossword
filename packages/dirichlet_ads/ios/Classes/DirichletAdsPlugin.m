#import "DirichletAdsPlugin.h"
#import <AdSupport/AdSupport.h>
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <DirichletMediationSDK/DirichletMediationSDK.h>
#import <SafariServices/SafariServices.h>
#import <WebKit/WebKit.h>

static NSString *const DRConsentKey = @"dirichlet_ad_privacy_v1";
static NSString *const DRRewardSpace = @"1063798";
static NSString *const DRBannerSpace = @"1063797";

static FlutterError *DRError(NSString *code) {
  return [FlutterError errorWithCode:code message:code details:nil];
}

static UIViewController *DRPresenter(void) {
  for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
    if (![scene isKindOfClass:UIWindowScene.class] ||
        scene.activationState != UISceneActivationStateForegroundActive) continue;
    for (UIWindow *window in ((UIWindowScene *)scene).windows) {
      if (!window.isKeyWindow) continue;
      UIViewController *controller = window.rootViewController;
      while (controller.presentedViewController) controller = controller.presentedViewController;
      return controller;
    }
  }
  return nil;
}

static BOOL DRCanLoad(void) {
  return [NSUserDefaults.standardUserDefaults boolForKey:DRConsentKey] &&
      [DirichletMediation isInitialized] && DRPresenter() != nil;
}

@interface DRPrivacyController : DRMCustomController
@end
@implementation DRPrivacyController
- (BOOL)canUseLocation { return NO; }
@end

// Present the exact bundled app policy before consent; external SDK links remain accessible.
@interface DRPolicyViewController : UIViewController <WKNavigationDelegate>
@property(nonatomic, copy) NSString *assetPath;
@property(nonatomic, copy) void (^onClose)(void);
@end
@implementation DRPolicyViewController
- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = @"隐私政策";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closePolicy)];
  WKWebView *webView = [[WKWebView alloc] initWithFrame:self.view.bounds];
  webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  webView.navigationDelegate = self;
  [self.view addSubview:webView];
  NSURL *url = [NSURL fileURLWithPath:self.assetPath];
  [webView loadFileURL:url allowingReadAccessToURL:url.URLByDeletingLastPathComponent];
}
- (void)closePolicy {
  [self dismissViewControllerAnimated:YES completion:self.onClose];
}
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action
    decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
  NSURL *url = action.request.URL;
  if (action.navigationType == WKNavigationTypeLinkActivated) {
    decisionHandler(WKNavigationActionPolicyCancel);
    if ([url.scheme isEqualToString:@"https"]) {
      SFSafariViewController *browser = [[SFSafariViewController alloc] initWithURL:url];
      [self presentViewController:browser animated:YES completion:nil];
    }
    return;
  }
  decisionHandler(WKNavigationActionPolicyAllow);
}
@end

@interface DRBannerView : NSObject <FlutterPlatformView, DRMBannerAdDelegate>
@property(nonatomic, strong) UIView *container;
@property(nonatomic, strong) DRMBannerAd *ad;
@property(nonatomic, strong) FlutterMethodChannel *channel;
@property(nonatomic) NSUInteger generation;
- (instancetype)initWithFrame:(CGRect)frame identifier:(int64_t)identifier
                   messenger:(NSObject<FlutterBinaryMessenger> *)messenger;
- (void)disposeAd;
@end

@implementation DRBannerView
- (instancetype)initWithFrame:(CGRect)frame identifier:(int64_t)identifier
                   messenger:(NSObject<FlutterBinaryMessenger> *)messenger {
  if ((self = [super init])) {
    _container = [[UIView alloc] initWithFrame:frame];
    _channel = [FlutterMethodChannel methodChannelWithName:
        [NSString stringWithFormat:@"idiom_crossword/dirichlet/banner/%lld", identifier]
        binaryMessenger:messenger];
    __weak typeof(self) weakSelf = self;
    [_channel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
      if ([call.method isEqualToString:@"load"]) {
        [weakSelf loadAd];
        result(nil);
      } else if ([call.method isEqualToString:@"dispose"]) {
        [weakSelf disposeAd];
        result(nil);
      } else {
        result(FlutterMethodNotImplemented);
      }
    }];
  }
  return self;
}
- (UIView *)view { return self.container; }
- (void)loadAd {
  [self disposeAd];
  if (!DRCanLoad()) {
    [self.channel invokeMethod:@"failed" arguments:nil];
    return;
  }
  NSUInteger generation = self.generation;
  DRMAdLoadRequest *request = [[DRMAdLoadRequest alloc] initWithSpaceId:DRBannerSpace];
  request.adSize = CGSizeMake(320, 50);
  request.viewController = DRPresenter();
  __weak typeof(self) weakSelf = self;
  [DRMBannerAd loadWithRequest:request completion:^(NSArray<DRMBannerAd *> *ads, NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      typeof(self) self = weakSelf;
      if (!self || generation != self.generation || !DRCanLoad()) {
        for (DRMBannerAd *ad in ads) [ad destroy];
        return;
      }
      self.generation++; // Invalidates this request's timeout.
      if (error || ads.count == 0) {
        [self.channel invokeMethod:@"failed" arguments:nil];
        return;
      }
      self.ad = ads.firstObject;
      for (NSUInteger i = 1; i < ads.count; i++) [ads[i] destroy];
      self.ad.delegate = self;
      UIView *view = self.ad.view;
      view.frame = self.container.bounds;
      view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
      [self.container addSubview:view];
    });
  }];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    typeof(self) self = weakSelf;
    if (self && self.generation == generation) {
      [self disposeAd];
      [self.channel invokeMethod:@"failed" arguments:nil];
    }
  });
}
- (void)bannerAdDidShow:(DRMBannerAd *)ad {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (ad == self.ad) [self.channel invokeMethod:@"shown" arguments:nil];
  });
}
- (void)bannerAdDidClose:(DRMBannerAd *)ad {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (ad != self.ad) return;
    [self disposeAd];
    [self.channel invokeMethod:@"closed" arguments:nil];
  });
}
- (void)disposeAd {
  self.generation++;
  self.ad.delegate = nil;
  [self.ad.view removeFromSuperview];
  [self.ad destroy];
  self.ad = nil;
}
- (void)dealloc {
  [_channel setMethodCallHandler:nil];
  _ad.delegate = nil;
  [_ad destroy];
}
@end

@interface DRBannerFactory : NSObject <FlutterPlatformViewFactory>
@property(nonatomic, strong) NSObject<FlutterBinaryMessenger> *messenger;
@property(nonatomic, strong) NSHashTable<DRBannerView *> *views;
@end
@implementation DRBannerFactory
- (NSObject<FlutterPlatformView> *)createWithFrame:(CGRect)frame viewIdentifier:(int64_t)viewId
                                       arguments:(id)args {
  DRBannerView *view = [[DRBannerView alloc] initWithFrame:frame identifier:viewId messenger:self.messenger];
  [self.views addObject:view];
  return view;
}
@end

@interface DirichletAdsPlugin () <DRMRewardVideoAdDelegate>
@property(nonatomic, copy) NSString *privacyAssetPath;
@property(nonatomic, strong) DRMRewardVideoAd *rewardAd;
@property(nonatomic, copy) FlutterResult loadResult;
@property(nonatomic, copy) FlutterResult showResult;
@property(nonatomic, copy) FlutterResult consentResult;
@property(nonatomic) BOOL rewarded;
@property(nonatomic) BOOL rewardDidShow;
@property(nonatomic) BOOL didPresentDebugIDFA;
@property(nonatomic) NSUInteger generation;
@property(nonatomic, strong) DRBannerFactory *bannerFactory;
@end

@implementation DirichletAdsPlugin

#if DEBUG
- (void)presentDebugIDFAForStatus:(ATTrackingManagerAuthorizationStatus)status {
  if (self.didPresentDebugIDFA) return;

  UIViewController *presenter = DRPresenter();
  if (!presenter || [presenter isKindOfClass:UIAlertController.class]) return;
  self.didPresentDebugIDFA = YES;

  NSString *statusText;
  switch (status) {
    case ATTrackingManagerAuthorizationStatusAuthorized:
      statusText = @"已授权";
      break;
    case ATTrackingManagerAuthorizationStatusDenied:
      statusText = @"系统当前不允许跟踪";
      break;
    case ATTrackingManagerAuthorizationStatusRestricted:
      statusText = @"受限制";
      break;
    default:
      statusText = @"尚未选择";
      break;
  }

  NSString *idfa = status == ATTrackingManagerAuthorizationStatusAuthorized
      ? ASIdentifierManager.sharedManager.advertisingIdentifier.UUIDString
      : @"00000000-0000-0000-0000-000000000000";
  
  NSLog(@"[Dirichlet] ATT 状态: %@", statusText);
  NSLog(@"[Dirichlet] IDFA: %@", idfa);

  BOOL available = ![idfa isEqualToString:@"00000000-0000-0000-0000-000000000000"];
  NSString *message = available
      ? [NSString stringWithFormat:@"ATT 状态：%@\n\nIDFA：\n%@\n\n请复制后填写到 Dirichlet 后台测试工具。", statusText, idfa]
      : [NSString stringWithFormat:@"ATT 状态：%@\n\n请前往“设置 → 隐私与安全性 → 跟踪”检查“允许 App 请求跟踪”和本应用开关，然后重新启动。本按钮仅打开应用设置页。系统不允许跟踪不代表您曾手动拒绝，也不影响已同意隐私政策后的广告请求。", statusText];

  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Dirichlet 测试 IDFA"
      message:message preferredStyle:UIAlertControllerStyleAlert];
  if (available) {
    [alert addAction:[UIAlertAction actionWithTitle:@"复制 IDFA" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *action) {
          UIPasteboard.generalPasteboard.string = idfa;
        }]];
  } else {
    [alert addAction:[UIAlertAction actionWithTitle:@"打开系统设置" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *action) {
          NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
          if (url) [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
        }]];
  }
  [alert addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];
  [presenter presentViewController:alert animated:YES completion:nil];
}
#endif
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  DirichletAdsPlugin *instance = [[DirichletAdsPlugin alloc] init];
  instance.privacyAssetPath = [NSBundle.mainBundle pathForResource:
      [registrar lookupKeyForAsset:@"privacy.html"] ofType:nil];
  FlutterMethodChannel *channel = [FlutterMethodChannel
      methodChannelWithName:@"idiom_crossword/dirichlet" binaryMessenger:registrar.messenger];
  [registrar addMethodCallDelegate:instance channel:channel];
  instance.bannerFactory = [[DRBannerFactory alloc] init];
  instance.bannerFactory.messenger = registrar.messenger;
  instance.bannerFactory.views = NSHashTable.weakObjectsHashTable;
  [registrar registerViewFactory:instance.bannerFactory withId:@"idiom_crossword/dirichlet/banner"];
  [NSNotificationCenter.defaultCenter addObserver:instance selector:@selector(pauseBackgroundAds:)
      name:UISceneDidEnterBackgroundNotification object:nil];
}
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  if ([call.method isEqualToString:@"systemRegion"]) {
    result([NSLocale.currentLocale objectForKey:NSLocaleCountryCode]);
  } else if ([call.method isEqualToString:@"acceptAppPrivacy"]) {
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:DRConsentKey];
    result(nil);
  } else if ([call.method isEqualToString:@"requestConsent"]) {
    if (self.consentResult) { result(DRError(@"consent_in_progress")); return; }
    if (![call.arguments[@"force"] boolValue] &&
        [NSUserDefaults.standardUserDefaults objectForKey:DRConsentKey]) {
      result(@([NSUserDefaults.standardUserDefaults boolForKey:DRConsentKey]));
      return;
    }
    self.consentResult = result;
    [self presentConsent];
  } else if ([call.method isEqualToString:@"initialize"]) {
    [self initializeSDK:call.arguments result:result];
  } else if ([call.method isEqualToString:@"loadRewarded"]) {
    [self loadRewarded:result];
  } else if ([call.method isEqualToString:@"showRewarded"]) {
    if (self.showResult || !DRCanLoad() || ![self.rewardAd isReady]) {
      result(DRError(@"ad_not_ready")); return;
    }
    for (DRBannerView *banner in self.bannerFactory.views) [banner disposeAd];
    self.showResult = result;
    self.rewarded = NO;
    self.rewardDidShow = NO;
    self.rewardAd.delegate = self;
    DRMRewardVideoAd *presentingAd = self.rewardAd;
    [presentingAd showFromViewController:DRPresenter()];
    // Only bound presentation startup. Never time out a video the user is watching.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
      if (self.rewardAd == presentingAd && self.showResult && !self.rewardDidShow) {
        self.rewarded = NO;
        [self finishRewarded];
      }
    });
  } else if ([call.method isEqualToString:@"disposeAds"]) {
    [self disposeAds];
    result(nil);
  } else {
    result(FlutterMethodNotImplemented);
  }
}
- (void)presentConsent {
  UIViewController *presenter = DRPresenter();
  if (!presenter || [presenter isKindOfClass:UIAlertController.class]) {
    FlutterResult result = self.consentResult;
    self.consentResult = nil;
    result(DRError(@"no_presenter"));
    return;
  }
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"广告隐私说明"
      message:@"为提供横幅和观看视频奖励，中国大陆地区使用 Dirichlet 聚合（上海艾得蒽数字科技有限公司）及穿山甲。广告 SDK 会采集设备信息、IDFV、IP 地址、网络状态、广告互动及诊断数据，用于广告投放、效果衡量和反作弊；仅在系统授权后访问 IDFA，不申请定位权限。保存期限和权利行使方式见隐私政策。您可在“设置—用户协议与隐私”查看各平台完整政策并修改授权。拒绝不影响游戏基本功能。"
      preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"暂不启用广告" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    [presenter dismissViewControllerAnimated:YES completion:^{ [self completeConsent:NO]; }];
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"阅读完整政策" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    DRPolicyViewController *policy = [[DRPolicyViewController alloc] init];
    policy.assetPath = self.privacyAssetPath;
    policy.onClose = ^{ [self presentConsent]; };
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:policy];
    navigation.modalInPresentation = YES;
    [presenter dismissViewControllerAnimated:YES completion:^{
      [presenter presentViewController:navigation animated:YES completion:nil];
    }];
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"同意并启用广告" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [presenter dismissViewControllerAnimated:YES completion:^{ [self completeConsent:YES]; }];
  }]];
  [presenter presentViewController:alert animated:YES completion:nil];
}
- (void)completeConsent:(BOOL)accepted {
  [NSUserDefaults.standardUserDefaults setBool:accepted forKey:DRConsentKey];
  if (!accepted) [self disposeAds];
  FlutterResult result = self.consentResult;
  self.consentResult = nil;
  if (result) result(@(accepted));
}
- (void)initializeSDK:(NSDictionary *)arguments result:(FlutterResult)result {
  if (![NSUserDefaults.standardUserDefaults boolForKey:DRConsentKey] || !DRPresenter()) {
    result(@NO); return;
  }
  if ([DirichletMediation isInitialized]) {
#if DEBUG
    [self presentDebugIDFAForStatus:ATTrackingManager.trackingAuthorizationStatus];
#endif
    result(@YES);
    return;
  }
  void (^start)(ATTrackingManagerAuthorizationStatus) = ^(ATTrackingManagerAuthorizationStatus status) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (!DRPresenter() || ![NSUserDefaults.standardUserDefaults boolForKey:DRConsentKey]) {
        result(@NO); return;
      }
#if DEBUG
      [self presentDebugIDFAForStatus:status];
#endif
      DRMSDKConfig *config = [DRMSDKConfig configWithMediaId:@"1107498"
          mediaKey:@"Ad1sg8Sb5mOdlxGAvLXtmlv321zwn5glEr3Tq9Z8t8AUneoeyOlHdszDuihS9x8x"];
      config.mediaName = @"成语接龙";
      config.isDebug = [arguments[@"debug"] boolValue];
      config.allowIDFAAccess = status == ATTrackingManagerAuthorizationStatusAuthorized;
      config.shakeEnabled = NO;
      config.customController = [[DRPrivacyController alloc] init];
      __block BOOL finished = NO;
      [DirichletMediation startWithConfig:config completion:^(BOOL success, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (finished) return;
          finished = YES;
          result(@(success));
        });
      }];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (finished) return;
        finished = YES;
        result(DRError(@"initialization_timeout"));
      });
    });
  };
  if (ATTrackingManager.trackingAuthorizationStatus == ATTrackingManagerAuthorizationStatusNotDetermined) {
    [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:start];
  } else {
    start(ATTrackingManager.trackingAuthorizationStatus);
  }
}
- (void)loadRewarded:(FlutterResult)result {
  if (!DRCanLoad() || self.showResult) { result(@NO); return; }
  if ([self.rewardAd isReady]) { result(@YES); return; }
  if (self.loadResult) { result(DRError(@"load_in_progress")); return; }
  [self.rewardAd destroy];
  self.rewardAd = nil;
  self.loadResult = result;
  NSUInteger generation = ++self.generation;
  DRMAdLoadRequest *request = [[DRMAdLoadRequest alloc] initWithSpaceId:DRRewardSpace];
  // Reward accounting belongs to each existing Flutter entry point; no server verification configured.
  [DRMRewardVideoAd loadWithRequest:request completion:^(NSArray<DRMRewardVideoAd *> *ads, NSError *error) {
    dispatch_async(dispatch_get_main_queue(), ^{
      if (generation != self.generation || !self.loadResult) {
        for (DRMRewardVideoAd *ad in ads) [ad destroy];
        return;
      }
      FlutterResult pending = self.loadResult;
      self.loadResult = nil;
      if (error || !DRCanLoad()) {
        for (DRMRewardVideoAd *ad in ads) [ad destroy];
        pending(@NO); return;
      }
      self.rewardAd = ads.firstObject;
      for (NSUInteger i = 1; i < ads.count; i++) [ads[i] destroy];
      pending(@([self.rewardAd isReady]));
    });
  }];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
    if (generation != self.generation || !self.loadResult) return;
    self.generation++;
    FlutterResult pending = self.loadResult;
    self.loadResult = nil;
    pending(@NO);
  });
}
- (void)rewardVideoAdDidShow:(DRMRewardVideoAd *)ad {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (ad == self.rewardAd && self.showResult) self.rewardDidShow = YES;
  });
}
- (void)rewardVideoAdDidRewardUser:(DRMRewardVideoAd *)ad {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (ad == self.rewardAd && self.showResult) self.rewarded = YES;
  });
}
- (void)rewardVideoAdDidClose:(DRMRewardVideoAd *)ad {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (ad == self.rewardAd) [self finishRewarded];
  });
}
// The 5.2.1.5 header uses this selector (the website example uses an older name).
- (void)rewardVideoAdDidFailToShow:(DRMRewardVideoAd *)ad withError:(NSError *)error {
  dispatch_async(dispatch_get_main_queue(), ^{
    if (ad != self.rewardAd) return;
    self.rewarded = NO;
    [self finishRewarded];
  });
}
- (void)finishRewarded {
  FlutterResult result = self.showResult;
  BOOL earned = self.rewarded;
  self.showResult = nil;
  self.rewarded = NO;
  self.rewardAd.delegate = nil;
  [self.rewardAd destroy];
  self.rewardAd = nil;
  if (result) result(@(earned));
}
- (void)pauseBackgroundAds:(NSNotification *)notification {
  if (DRPresenter()) return;
  // Flutter may stop drawing frames in the background. Release auto-refreshing
  // banners natively instead of waiting for a widget disposal frame.
  for (DRBannerView *banner in self.bannerFactory.views) [banner disposeAd];
  if (!self.showResult) {
    self.generation++;
    FlutterResult loading = self.loadResult;
    self.loadResult = nil;
    if (loading) loading(@NO);
    [self.rewardAd destroy];
    self.rewardAd = nil;
  }
}
- (void)detachFromEngineForRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  [NSNotificationCenter.defaultCenter removeObserver:self];
  [self disposeAds];
}
- (void)dealloc {
  [NSNotificationCenter.defaultCenter removeObserver:self];
}
- (void)disposeAds {
  self.generation++;
  FlutterResult loading = self.loadResult;
  self.loadResult = nil;
  if (loading) loading(@NO);
  self.rewarded = NO;
  [self finishRewarded];
  for (DRBannerView *banner in self.bannerFactory.views) [banner disposeAd];
}
@end

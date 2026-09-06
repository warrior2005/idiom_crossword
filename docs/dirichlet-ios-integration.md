# iOS Dirichlet 广告接入

## 地区与广告入口

使用 iOS “设置 → 通用 → 语言与地区 → 地区”的 `NSLocale.currentLocale` 国家代码。`CN` 使用 Dirichlet；其他地区（包括 HK/MO/TW）使用 AdMob。与界面语言、IP、GPS 和 App Store 商店地区无关，地区修改后重启应用生效。Android 仍使用原有 AdMob，本次未接入 Android Dirichlet SDK。

| 现有入口 | 中国大陆 iOS | 其他地区 iOS |
| --- | --- | --- |
| 页面底部横幅 | Dirichlet Banner，1063797，320 × 50 pt | 原 AdMob Banner |
| 商城积分、游戏内激励 | Dirichlet 激励视频，1063798 | 原 AdMob RewardedAd |
| 通关结算前插屏激励 | 同一 Dirichlet 激励视频广告位 | 原 AdMob RewardedInterstitialAd |

积分数额、每日次数、冷却和复活规则仍由原页面及 PlayerState 决定。两个国内激励入口共用一个缓存，合并加载并阻止同时展示。SDK 确认奖励后记录一次资格，关闭时先回调奖励再通知页面结束；提前关闭、无填充、过期、展示失败均不发奖。未配置服务端奖励验证（callbackUrl/securityKey 为 `-`，没有把它们作为实际配置发送）。

Banner 每页独立创建原生视图，只有收到展示回调且页面/Tab/应用均可见时才累计积分；切后台由原生主动销毁 Banner，返回后重建。广告失败按 15 秒、30 秒、60 秒重试；拒绝授权后停止重试。单次 SDK 初始化和加载有 30 秒超时，展示启动有 10 秒超时，正在观看的视频不会被计时中断。

## 依赖与代码

- `packages/dirichlet_ads`：项目内 Flutter iOS 插件，Objective-C MethodChannel + UIKit PlatformView。
- `lib/src/utils/ad_manager.dart`：SDK 选择和现有广告 API 的分流。
- `lib/src/ui/widgets/dirichlet_banner_view.dart`：原生横幅生命周期。
- 媒体 1107498 和提供的 mediaKey 位于原生插件初始化配置，不写入日志。mediaKey 是 SDK 客户端初始化凭据，不是服务端奖励校验密钥。
- CocoaPods 固定聚合 SDK、DRA、CSJ 适配器为 `5.2.1.5`；第三方 SDK 版本交给适配器解析。由于 Dirichlet 官方 iOS SDK 只通过 CocoaPods 发布，本项目已在 `pubspec.yaml` 中关闭 iOS Swift Package Manager，让所有 iOS 插件统一由 CocoaPods 管理。
- 已按 Dirichlet 接入文档加入三个 SKAdNetwork ID，并加入 Google 的 ID；接入更多广告网络时需核对对应网络的官方配置。

```sh
flutter pub get
cd ios
pod install
cd ..
flutter build ios --release --no-codesign
```

使用 `ios/Runner.xcworkspace` 打开 Xcode，不能仅打开 `.xcodeproj`。

`Podfile.lock` 当前解析为穿山甲 `7.5.0.7`。优量汇 `4.16.00` 及其 Dirichlet 适配器缺少 arm64 模拟器切片；即使只限定到 Release/Profile，Flutter 的架构检查仍会把 Debug 模拟器产物降为 x86_64，导致 Apple Silicon 模拟器无法安装。因此当前版本不接入优量汇，保留 Dirichlet DRA 与穿山甲。待官方提供 arm64 模拟器切片后，可在 `Podfile` 恢复 GDT 适配器并重新进行真机和模拟器验证。

实际 SDK 头文件的展示失败回调为 `rewardVideoAdDidFailToShow:withError:`，与接入网页中的旧示例名称不同。本插件以安装的头文件为准。

## 隐私初始化

国内不会调用 Google UMP 或初始化 MobileAds。先展示国内广告隐私选择，应用完整政策 `privacy.html` 随包提供，可离线阅读；同意后才请求 ATT 和启动 Dirichlet，拒绝后保留基本游戏功能。可在“设置 → 用户协议与隐私 → 修改国内广告隐私授权”重新选择。

仅在 ATT 已授权时允许 IDFA；不申请或提供精确定位。更新了应用内政策和仓库中的 `privacy.html`；公开网站仍需发布该文件的新版本。

## 联调与上线

1. 真机系统地区设为中国大陆，重启，确认日志 `provider=Dirichlet`，分别验证同意/拒绝、拒绝 ATT 和允许 ATT。
2. 在 Dirichlet 后台确认媒体对应当前 iOS Bundle ID `com.sunnywarrior.idiomCrossword`，广告位类型及聚合网络配置正确；通过后台“流量管理 → 测试工具”配置测试设备。
3. Debug 只开启 SDK 调试日志，**不等同于测试广告**，提供的广告位仍是真实广告位。按后台测试工具联调，不要点击自己的正式广告。
4. 分别验证完整观看、提前关闭、断网、无填充、广告过期、重复点击、从落地页返回；确认商城积分、通关额外积分及复活各只触发一次。
5. 切换 Tab、推入其他页面、锁屏和切后台，确认不可见 Banner 不累计积分；关闭横幅后当前页面不再自动展示它。
6. 将系统地区改为美国或香港并重启，确认 `provider=AdMob` 和原有三类广告正常。
7. 上线前确认媒体和推广位在后台为正式、开启状态，并同步发布新的隐私政策页面。未在本次工作中修改后台配置或发布网站。

## 官方资料

- [iOS 聚合接入](https://ssp.dirichlet.cn/docs/dirichlet-mediation-sdk/dirichlet-mediation-sdk-guide-ios/)
- [SDK 发布记录](https://ssp.dirichlet.cn/docs/dirichlet-mediation-sdk/dirichlet-sdk-release-notes/)
- [平台接入及测试工具](https://ssp.dirichlet.cn/docs/ssp-guide/)
- [SDK 隐私政策](https://ssp.dirichlet.cn/docs/agreement/)
- [SDK 合规说明](https://ssp.dirichlet.cn/docs/compliance/)

## 本次验证记录

- `flutter analyze --no-pub`：通过。
- `flutter build ios --simulator --debug --no-pub`：通过；产物同时包含 arm64 与 x86_64，并已在 iOS 26.2 的 iPhone 17 Pro 模拟器完成安装和启动。
- `flutter build ios --release --no-codesign --no-pub`：通过，生成 `build/ios/iphoneos/Runner.app`（147.7 MB，未签名），包含 Google Mobile Ads、Dirichlet、DRA、穿山甲及离线隐私政策。
- 广告桥接、Banner 积分、玩家状态、游戏流程共 63 项测试：通过。
- 更新后的隐私页面测试：通过。
- 额外页面回归中的两个收藏按钮对齐断言，在未修改的 HEAD 临时副本中也失败（偏差 8.5，预期小于 1），与本次广告接入无关。
- Objective-C 桥接针对真实 Dirichlet 5.2.1.5 / Flutter / iOS SDK 头文件的语法编译：通过。
- 真实广告填充、ATT 弹窗和后台投放配置仍需按上述步骤在真机验收。

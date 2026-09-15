import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../widgets/sub_page_header.dart';

// Change only when the corresponding document content changes, not on app releases.
const userAgreementVersion = '20260906';
const privacyPolicyVersion = '20260906';
const appPrivacyConsentKey =
    'app_privacy_consent_${userAgreementVersion}_$privacyPolicyVersion';

class LegalScreen extends StatelessWidget {
  final int initialIndex;

  const LegalScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: SubPageHeader(title: '用户协议与隐私'),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: TabBar(
                  labelColor: AppColors.accent,
                  unselectedLabelColor: AppColors.muted,
                  indicatorColor: AppColors.accent,
                  tabs: [
                    Tab(text: '用户协议'),
                    Tab(text: '隐私政策'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _LegalDocument(sections: _agreementSections),
                    _LegalDocument(sections: _privacySections),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegalDocument extends StatelessWidget {
  final List<({String title, String body})> sections;

  const _LegalDocument({required this.sections});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        Text(
          '生效日期：2026年9月6日',
          style: bodyStyle(size: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        for (final section in sections) ...[
          Text(
            section.title,
            style: displayStyle(size: 16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 7),
          SelectableText(
            section.body,
            style: bodyStyle(size: 13.5, color: AppColors.fg),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

const _agreementSections = <({String title, String body})>[
  (
    title: '一、协议说明',
    body: '欢迎使用“成语接龙”。下载、安装或使用本应用，即表示您已阅读并同意本协议及隐私政策。若您不同意相关内容，请停止使用本应用。',
  ),
  (
    title: '二、服务内容',
    body:
        '本应用提供成语接龙、关卡进度、收藏、成就、排行榜及装饰道具等功能。部分功能依赖 Apple 的 iCloud 和 Game Center 服务，相关服务是否可用受设备、系统设置、网络和 Apple 服务状态影响。',
  ),
  (
    title: '三、使用规则',
    body:
        '您应合法、合理地使用本应用，不得利用本应用从事违法活动，不得干扰应用、广告服务、排行榜或其他服务的正常运行，未经允许不得对软件进行解包、反编译等操作，也不得通过修改、作弊或自动化方式不当获取积分、道具、成就或排名。',
  ),
  (
    title: '四、广告与奖励',
    body:
        '本应用可能展示横幅广告、激励广告或其他广告。激励奖励仅在广告平台确认满足奖励条件后发放；因网络中断、广告库存不足或第三方服务异常导致广告无法展示时，请稍后重试。未来接入新的广告供应商时，我们会同步更新隐私政策。',
  ),
  (
    title: '五、知识产权',
    body: '本应用的软件、界面、图形及其他原创内容受相关法律保护。成语、典故等传统文化资料来源于公共文化资料，仅用于学习与游戏体验。',
  ),
  (
    title: '六、服务变更与免责',
    body:
        '我们可能为改进体验而更新功能、规则或内容。对于不可抗力、设备故障、网络异常以及 Apple、广告平台等第三方服务造成的中断或数据同步延迟，我们会尽力恢复，但不承诺服务始终无中断或完全无误。',
  ),
  (title: '七、联系我们', body: '如对本协议有疑问，请通过 App Store 应用页面提供的开发者联系方式与我们联系。'),
];

const _privacySections = <({String title, String body})>[
  (
    title: '一、我们处理的信息',
    body:
        '游戏进度会保存在设备本地。启用 iCloud 后，关卡、经验、收藏、成就、设置及商城资产等存档数据会保存到您的 iCloud 账户，用于跨设备同步或重新安装后的恢复。我们不会要求您提供姓名、手机号或身份证件等真实身份信息。',
  ),
  (
    title: '二、广告服务',
    body:
        '本应用使用Dirichlet聚合SDK 与 Google AdMob。用于横幅、激励视频和插页式广告。广告商可能依据您的授权状态处理设备标识符、广告互动、诊断信息及大致位置等数据，用于广告投放、频次控制、反欺诈和效果衡量。iOS 会在需要时显示系统跟踪授权提示；拒绝跟踪不会阻止您使用游戏，但广告可能与您的兴趣无关。',
  ),
  (
    title: '三、Dirichlet 聚合广告',
    body:
        'Dirichlet 聚合 SDK（TapADN，上海艾得蒽数字科技有限公司及其关联方），接入穿山甲（北京巨量引擎网络技术有限公司）适配器，由聚合平台按广告位配置选择广告来源。SDK 在您同意后自行采集设备基础信息、IDFV、网络状态、广告互动和诊断信息等，用于广告投放、监测归因、反作弊和统计分析。IDFA 仅在 iOS 跟踪授权后访问；本应用不向广告 SDK 提供精确位置。拒绝广告授权不影响基本游戏功能。第三方保存期限、权利行使和联系方式见各自完整隐私政策：Dirichlet https://ssp.dirichlet.cn/docs/agreement/；穿山甲 https://www.csjplatform.com/privacy/partner。',
  ),
  (
    title: '四、Game Center',
    body:
        '使用成就和排行榜时，本应用会向 Apple Game Center 提交已解锁成就、总经验和每周经验，并读取展示排行榜所需的昵称、排名与成绩。相关信息由 Apple 按其隐私政策处理。',
  ),
  (
    title: '五、iCloud',
    body:
        '游戏存档保存在您的 iCloud 账户中。我们使用该数据提供备份和恢复功能，不会借此获取您的真实身份。删除本应用会删除设备上的本地数据，但不会自动删除 iCloud 中的游戏存档；您可在 iOS 的 iCloud 存储设置中管理相关数据。',
  ),
  (
    title: '六、数据安全与保留',
    body:
        '本地数据随应用保留；云端和第三方服务中的数据按照 Apple、Google、Dirichlet 及其已接入广告网络的规则保留。我们会采取合理措施保护应用内数据，但互联网传输和第三方服务无法保证绝对安全。',
  ),
  (
    title: '七、儿童隐私',
    body: '本应用不以儿童为主要目标用户，也不会主动收集儿童的真实身份信息。未成年人应在监护人指导下使用本应用及相关广告功能。',
  ),
  (
    title: '八、政策更新与联系我们',
    body:
        '当功能、广告供应商或法律要求发生变化时，我们可能更新本政策，并在应用内公布新版本。如有隐私相关问题，请通过 App Store 应用页面提供的开发者联系方式与我们联系。',
  ),
];

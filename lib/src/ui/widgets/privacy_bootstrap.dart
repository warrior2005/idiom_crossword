import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/database.dart';
import '../../utils/ad_manager.dart';
import '../screens/legal_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'primary_button.dart';
import 'theme_dialog.dart';

/// Keep startup services behind explicit, persisted app privacy consent.
class PrivacyBootstrap extends StatefulWidget {
  const PrivacyBootstrap({super.key, required this.db, required this.child});

  final AppDatabase db;
  final Widget child;

  @override
  State<PrivacyBootstrap> createState() => _PrivacyBootstrapState();
}

class _PrivacyBootstrapState extends State<PrivacyBootstrap> {
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      await _loadConsent();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _loadConsent() async {
    var accepted = await widget.db.getSetting(appPrivacyConsentKey) == 'true';
    // The old single-button dialog covered these exact document versions.
    if (!accepted &&
        userAgreementVersion == '20260906' &&
        privacyPolicyVersion == '20260906' &&
        await widget.db.getSetting('app_privacy_consent_20260906') == 'true') {
      await widget.db.setSetting(appPrivacyConsentKey, 'true');
      accepted = true;
    }
    if (!mounted) return;
    if (!accepted) {
      final agreed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: ThemeDialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('个人信息保护指引', style: displayStyle(size: 22)),
                const SizedBox(height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '欢迎使用成语接龙！我们重视您的个人信息保护。\n\n'
                          '游戏进度和偏好保存在本机；使用云存档、Game Center 等服务时，相关信息由 Apple 按其规则处理。\n\n'
                          '广告 SDK 会处理设备基础信息、广告互动和诊断数据，用于广告投放、效果统计和反作弊。系统跟踪授权后不提供精确位置。\n\n'
                          '请阅读以下完整协议，了解信息处理、保存期限和您的权利，点击“同意”后继续使用。',
                          style: bodyStyle(size: 14, color: AppColors.fg),
                        ),
                        Wrap(
                          children: [
                            for (final entry in [(0, '《用户协议》'), (1, '《隐私政策》')])
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => LegalScreen(
                                          initialIndex: entry.$1,
                                          allowConsentChanges: false,
                                        ),
                                      ),
                                    ),
                                child: Text(entry.$2),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: '同意',
                  onTap: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            ),
          ),
        ),
      );
      if (!mounted) return;
      if (agreed != true) return;
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        await const MethodChannel(
          'idiom_crossword/dirichlet',
        ).invokeMethod<void>('acceptAppPrivacy');
      }
      await widget.db.setSetting(appPrivacyConsentKey, 'true');
    }
    if (!mounted) return;
    unawaited(AdManager().initialize());
    setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) => _ready
      ? widget.child
      : Scaffold(
          backgroundColor: AppColors.bg,
          body: _failed
              ? Center(
                  child: TextButton(
                    onPressed: () {
                      setState(() => _failed = false);
                      unawaited(_start());
                    },
                    child: const Text('隐私授权保存或读取失败，点击重试'),
                  ),
                )
              : null,
        );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';
import '../widgets/app_seal.dart';
import '../widgets/app_icons.dart';
import '../widgets/primary_button.dart';
import '../widgets/theme_dialog.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'home_screen.dart';
import 'level_select_screen.dart';
import 'collection_screen.dart';
import 'shop_screen.dart';
import 'mine_screen.dart';

class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showDailyLoginReward();
    });
  }

  Future<void> _showDailyLoginReward() async {
    DailyLoginClaim? claim;
    try {
      claim = await ref.read(playerProvider.notifier).claimDailyLoginReward();
    } catch (_) {
      return;
    }
    final rewardClaim = claim;
    if (!mounted || rewardClaim == null) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => ThemeDialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSeal('礼', size: 64, fontSize: 26),
            const SizedBox(height: 16),
            Text(
              '每日登录奖励',
              style: displayStyle(size: 24, weight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              '连续登录第 ${rewardClaim.streakDay} 天',
              style: bodyStyle(size: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.accentPale,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accentSoft),
              ),
              child: Column(
                children: [
                  Text(
                    '今日获得：${rewardClaim.reward.label}',
                    textAlign: TextAlign.center,
                    style: bodyStyle(
                      size: 15,
                      color: AppColors.accentDeep,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '明日奖励：${rewardClaim.nextReward.label}',
                    textAlign: TextAlign.center,
                    style: bodyStyle(size: 13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: '确定',
                small: true,
                onTap: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _index,
        children: [
          TickerMode(
            enabled: _index == 0,
            child: HomeScreen(onSwitchTab: (i) => setState(() => _index = i)),
          ),
          TickerMode(
            enabled: _index == 1,
            child: LevelSelectScreen(bannerActive: _index == 1),
          ),
          TickerMode(
            enabled: _index == 2,
            child: CollectionScreen(bannerActive: _index == 2),
          ),
          TickerMode(
            enabled: _index == 3,
            child: ShopScreen(bannerActive: _index == 3),
          ),
          TickerMode(enabled: _index == 4, child: const MineScreen()),
        ],
      ),
      bottomNavigationBar: _buildTabBar(),
    );
  }

  Widget _buildTabBar() {
    const tabs = [
      ('首页', 'home'),
      ('关卡', 'levels'),
      ('收藏', 'book'),
      ('商城', 'shop'),
      ('我的', 'mine'),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _index = i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AppIcon(
                          tabs[i].$2,
                          size: 23,
                          color: _index == i ? AppColors.accent : AppColors.muted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tabs[i].$1,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _index == i ? AppColors.accent : AppColors.muted,
                          ),
                        ),
                        Container(
                          width: 3,
                          height: 3,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: _index == i ? AppColors.accent : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

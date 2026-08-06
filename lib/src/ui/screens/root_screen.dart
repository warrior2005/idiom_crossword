import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/app_icons.dart';
import '../theme/app_colors.dart';
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          LevelSelectScreen(),
          CollectionScreen(),
          ShopScreen(),
          MineScreen(),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';

class ShopScreen extends ConsumerWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F0E8),
        appBar: AppBar(
          title: const Text('商城'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: '功能道具'),
              Tab(text: '装饰道具'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _FunctionalItemsTab(player: player),
            _DecorationItemsTab(player: player),
          ],
        ),
      ),
    );
  }
}

class _FunctionalItemsTab extends StatelessWidget {
  final PlayerState player;

  const _FunctionalItemsTab({required this.player});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _ShopItem(
          name: '提示卡×10',
          description: '揭示单个空格答案',
          price: '¥6',
          onPurchase: () {
            // TODO: Implement IAP
          },
        ),
        _ShopItem(
          name: '复活卡×5',
          description: '失败后可继续当前关',
          price: '¥12',
          onPurchase: () {
            // TODO: Implement IAP
          },
        ),
      ],
    );
  }
}

class _DecorationItemsTab extends StatelessWidget {
  final PlayerState player;

  const _DecorationItemsTab({required this.player});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _ShopItem(
          name: '龙纹网格皮肤',
          description: '限定装饰',
          price: '¥18',
          isOwned: player.ownedDecorations.contains('grid_skin_dragon'),
          onPurchase: () {
            // TODO: Implement IAP
          },
        ),
        _ShopItem(
          name: '獬豸冠头像框',
          description: '限定装饰',
          price: '¥12',
          isOwned: player.ownedDecorations.contains('avatar_frame_xiezhi'),
          onPurchase: () {
            // TODO: Implement IAP
          },
        ),
      ],
    );
  }
}

class _ShopItem extends StatelessWidget {
  final String name;
  final String description;
  final String price;
  final bool isOwned;
  final VoidCallback onPurchase;

  const _ShopItem({
    required this.name,
    required this.description,
    required this.price,
    this.isOwned = false,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        title: Text(name),
        subtitle: Text(description),
        trailing: isOwned
            ? const Chip(label: Text('已拥有'))
            : ElevatedButton(
                onPressed: onPurchase,
                child: Text(price),
              ),
      ),
    );
  }
}

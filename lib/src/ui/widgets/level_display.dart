import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';

class LevelDisplay extends ConsumerWidget {
  const LevelDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Level badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _iconForLevel(player.level),
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Lv.${player.level} ${player.title}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // XP progress bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '经验值',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '${player.totalXp} / ${player.totalXp + player.xpToNextLevel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: player.xpProgress,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconForLevel(int level) {
    if (level >= 20) return Icons.emoji_events; // 位极人臣
    if (level >= 16) return Icons.school; // 大学士+
    if (level >= 12) return Icons.workspace_premium; // 状元+
    if (level >= 8) return Icons.book; // 进士+
    if (level >= 4) return Icons.person; // 贡生+
    return Icons.menu_book; // 童生+
  }
}

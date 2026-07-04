import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/player_state.dart';

/// AppBar 中的简洁等级显示
class LevelDisplay extends ConsumerWidget {
  const LevelDisplay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _iconForLevel(player.level),
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            'Lv.${player.level}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForLevel(int level) {
    if (level >= 20) return Icons.emoji_events;
    if (level >= 16) return Icons.school;
    if (level >= 12) return Icons.workspace_premium;
    if (level >= 8) return Icons.book;
    if (level >= 4) return Icons.person;
    return Icons.menu_book;
  }
}

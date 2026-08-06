import 'package:flutter/material.dart';
import '../theme/app_text.dart';

/// 竖排成语：模拟 CSS `writing-mode: vertical-rl`，每 2 字一列、列自右向左。
class VerticalWord extends StatelessWidget {
  final String word;
  final double fontSize;

  const VerticalWord({super.key, required this.word, this.fontSize = 34});

  @override
  Widget build(BuildContext context) {
    final chars = word.runes.map(String.fromCharCode).toList();
    final chunks = <List<String>>[];
    for (var i = 0; i < chars.length; i += 2) {
      final end = i + 2 > chars.length ? chars.length : i + 2;
      chunks.add(chars.sublist(i, end));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = chunks.length - 1; c >= 0; c--)
          Padding(
            padding: EdgeInsets.only(left: c == chunks.length - 1 ? 0 : 6),
            child: Column(
              children: [
                for (final ch in chunks[c])
                  Text(ch, style: displayStyle(size: fontSize, weight: FontWeight.w900, height: 1.15)),
              ],
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/database_provider.dart';
import '../../state/level_generation.dart';
import '../widgets/level_loading_dialog.dart';
import 'game_screen.dart';

/// 自定义关卡：自选难度区间与成语数量生成练习关（不计入通关进度）
class CustomLevelScreen extends ConsumerStatefulWidget {
  const CustomLevelScreen({super.key});

  @override
  ConsumerState<CustomLevelScreen> createState() => _CustomLevelScreenState();
}

class _CustomLevelScreenState extends ConsumerState<CustomLevelScreen> {
  RangeValues _difficulty = const RangeValues(10, 40);
  double _count = 6;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: AppBar(
        title: const Text('自定义关卡'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            '难度区间',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.brown.shade800,
            ),
          ),
          RangeSlider(
            values: _difficulty,
            min: 1,
            max: 50,
            divisions: 49,
            labels: RangeLabels(
              '${_difficulty.start.round()}',
              '${_difficulty.end.round()}',
            ),
            activeColor: Colors.brown.shade600,
            inactiveColor: Colors.brown.shade200,
            onChanged: (v) => setState(() => _difficulty = v),
          ),
          Text(
            '难度 ${_difficulty.start.round()} ~ ${_difficulty.end.round()}',
            style: TextStyle(fontSize: 13, color: Colors.brown.shade500),
          ),
          const SizedBox(height: 24),
          Text(
            '成语数量',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.brown.shade800,
            ),
          ),
          Slider(
            value: _count,
            min: 5,
            max: 12,
            divisions: 7,
            label: '${_count.round()} 条',
            activeColor: Colors.brown.shade600,
            inactiveColor: Colors.brown.shade200,
            onChanged: (v) => setState(() => _count = v),
          ),
          Text(
            '${_count.round()} 条成语',
            style: TextStyle(fontSize: 13, color: Colors.brown.shade500),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('开始挑战', style: TextStyle(fontSize: 17)),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.brown.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '自定义关卡为练习模式，不计入通关进度与成就。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.brown),
          ),
        ],
      ),
    );
  }

  Future<void> _start() async {
    showLevelLoadingDialog(context);
    try {
      final db = ref.read(databaseProvider);
      final level = await generateLevel(
        db,
        0,
        targetSize: _count.round(),
        difficultyRange: (_difficulty.start.round(), _difficulty.end.round()),
        title: '自定义关卡',
      );
      if (!mounted) return;
      Navigator.pop(context);
      if (level == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('关卡生成失败，请调整参数后重试')));
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GameScreen(level: level, isCustom: true),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('错误: $e')));
      }
    }
  }
}

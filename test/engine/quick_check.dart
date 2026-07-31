// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:idiom_crossword/src/engine/grid_engine.dart';
import 'package:idiom_crossword/src/engine/crossing_graph.dart';
import 'package:idiom_crossword/src/engine/integrated_generator.dart';

void main() {
  final raw = json.decode(
    File('assets/data/scoring_progress.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final scores = raw['scores'] as Map<String, dynamic>;
  final idioms = <Idiom>[];
  for (final entry in scores.entries) {
    if (entry.key.length != 4) continue;
    idioms.add(Idiom(
      text: entry.key,
      difficulty: (entry.value as num).toInt(),
    ));
  }

  final gen = IntegratedGenerator(graph: CrossingGraph(idioms: idioms));

  // 简单关 (1-20)
  var lvl = gen.generate(
      targetSize: 5, minDifficulty: 1, maxDifficulty: 20, maxAttempts: 30);
  if (lvl != null) {
    print('简单关(1-20):');
    for (final i in lvl.idioms) {
      print('  ${i.text} (难度${i.difficulty})');
    }
  }

  print('');

  // 中等关 (10-35)
  lvl = gen.generate(
      targetSize: 6, minDifficulty: 10, maxDifficulty: 35, maxAttempts: 30);
  if (lvl != null) {
    print('中等关(10-35):');
    for (final i in lvl.idioms) {
      print('  ${i.text} (难度${i.difficulty})');
    }
  }

  print('');

  // 困难关 (40-75)
  lvl = gen.generate(
      targetSize: 7, minDifficulty: 40, maxDifficulty: 75, maxAttempts: 30);
  if (lvl != null) {
    print('困难关(40-75):');
    for (final i in lvl.idioms) {
      print('  ${i.text} (难度${i.difficulty})');
    }
  }
}

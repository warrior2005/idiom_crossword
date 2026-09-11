// flutter test tool/mainline_samples_test.dart --reporter expanded
import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/mainline_learning.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('主线真实入口抽样和连续玩家轨迹', () async {
    final dir = await Directory.systemTemp.createTemp('mainline_samples_');
    final file = await File(
      'assets/data/idiom_crossword.db',
    ).copy('${dir.path}/samples.db');
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    final out = StringBuffer(
      '# 四档智能主线样本与轨迹\n\n内容／策略版本2；固定种子17的横截面，另附真实入口连续新题。桌面测试耗时含数据库查询、布局、消歧及候选盘；不代表真机性能或真人通过率。\n\n| 策略步 | 关卡 | 词数 | 待填 | 候选 | 四档数量 | 毫秒 | 成语 |\n|---:|---:|---:|---:|---:|---|---:|---|\n',
    );
    final durations = <int>[];
    for (final step in [-5, 0, 15, 30]) {
      await db.setSetting(
        MainlineLearning.key,
        jsonEncode({
          'sessions': [],
          'words': {},
          'adaptive': {'step': step},
        }),
      );
      for (final n in [1, 5, 10, 11, 20, 200, 6000]) {
        final timer = Stopwatch()..start();
        final level = await generateLevel(db, n, seed: 17);
        timer.stop();
        expect(level, isNotNull, reason: 'step=$step level=$n');
        final l = level!;
        durations.add(timer.elapsedMilliseconds);
        out.writeln(
          '| $step | $n | ${l.idioms.length} | ${l.fillableCells} | ${l.initialCandidates!.expand((r) => r).length} | ${l.strategy['quotas']} | ${timer.elapsedMilliseconds} | ${l.idioms.map((i) => i.text).join('、')} |',
        );
      }
    }
    out.writeln(
      '\n## 连续新题轨迹\n\n连续生成使用生产入口的相邻题面约束。成功轨迹含辅助完成和记忆积累；失败轨迹含未完成；混合轨迹交替成功失败。每题只记一次终态。\n',
    );
    for (final scenario in ['连续成功', '连续失败', '交替表现']) {
      await db.customStatement('DELETE FROM level_history');
      await db.setSetting(
        MainlineLearning.key,
        jsonEncode({
          'sessions': [],
          'words': {},
          'adaptive': {'step': 0},
        }),
      );
      out.writeln(
        '### $scenario\n\n| 关卡 | 结果 | 步前→后 | 词数 | 待填 | 候选 | 低熟悉词 |\n|---:|---|---|---:|---:|---:|---:|',
      );
      Map<String, dynamic>? previous;
      var lastChange = 0;
      for (var n = 1; n <= 30; n++) {
        final before = await MainlineLearning.ability(db);
        final level = await generateLevel(db, n);
        expect(level, isNotNull, reason: '$scenario level=$n step=$before');
        final l = level!;
        if (n > 10) expect(l.idioms.length, inInclusiveRange(6, 12));
        if (previous != null) {
          expect(
            (l.fillableCells - (previous['answers'] as int)).abs(),
            lessThanOrEqualTo(3),
          );
          expect(
            ((l.strategy['candidates'] as int) -
                    (previous['candidates'] as int))
                .abs(),
            lessThanOrEqualTo(5),
          );
          expect(
            ((l.strategy['unfamiliar'] as int) -
                    (previous['unfamiliar'] as int))
                .abs(),
            lessThanOrEqualTo(2),
          );
          expect(
            (l.idioms.length - (previous['size'] as int)).abs(),
            lessThanOrEqualTo(1),
          );
        }
        final success = scenario == '连续成功' || (scenario == '交替表现' && n.isEven);
        await MainlineLearning.record(
          db,
          l,
          status: success ? 'complete' : 'failed',
          hints: 0,
          errors: success ? 0 : 3,
          completed: success ? l.idioms.map((i) => i.text) : const [],
        );
        if (success) {
          final ids = await db.findIdiomIdsByWords(
            l.idioms.map((i) => i.text).toList(),
          );
          await db.addLevelHistory(
            levelNumber: n,
            xpGained: 0,
            idiomsUsed: ids.values.toList(),
          );
        }
        final after = await MainlineLearning.ability(db);
        expect((after - before).abs(), lessThanOrEqualTo(1));
        if (after != before) {
          expect(n - lastChange, greaterThanOrEqualTo(5));
          lastChange = n;
        }
        out.writeln(
          '| $n | ${success ? '完成' : '失败'} | $before→$after | ${l.idioms.length} | ${l.fillableCells} | ${l.strategy['candidates']} | ${l.strategy['unfamiliar']} |',
        );
        previous = l.strategy;
      }
    }
    durations.sort();
    out.writeln(
      '\n横截面共${durations.length}题，全成功；耗时中位数${durations[durations.length ~/ 2]}ms，最大${durations.last}ms。连续轨迹90题全成功生成；参数仅为工程起点，仍需实际玩家校准。',
    );
    File(
      'docs/specs/four_tier_mainline_samples.md',
    ).writeAsStringSync(out.toString());
  }, timeout: const Timeout(Duration(minutes: 5)));
}

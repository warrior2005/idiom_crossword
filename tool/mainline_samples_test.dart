// flutter test tool/mainline_samples_test.dart --reporter expanded
// 从实际资产和主线入口生成可复核报告，不覆盖历史样本报告。
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idiom_crossword/src/data/database.dart';
import 'package:idiom_crossword/src/data/mainline_content.dart';
import 'package:idiom_crossword/src/engine/mainline_policy.dart';
import 'package:idiom_crossword/src/state/level_generation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('主线真实入口抽样报告', () async {
    final dir = await Directory.systemTemp.createTemp('mainline_samples_');
    final file = await File(
      'assets/data/idiom_crossword.db',
    ).copy('${dir.path}/samples.db');
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
    final content = await MainlineContent.load();
    final out = StringBuffer(
      '# 主线改造抽样报告\n\n内容版本 ${content.version}，策略版本 1。固定种子 17，从实际资产与主线入口生成；不代表真人通过率。\n\n入门词 ${content.intro.length} 条（基础池子集）、基础词 ${content.foundation.length} 条、拓展词 ${content.expansion.length} 条，均为待目标玩家校准的初始清单。\n\n| 偏好 | 关卡 | 词数 | 待填格 | 候选字 | 拓展数 | 成语（拓展标 *） |\n| --- | ---: | ---: | ---: | ---: | ---: | --- |\n',
    );
    for (var ability = 0; ability <= 2; ability++) {
      await db.setSetting('mainline_ability', '$ability');
      for (final n in [1, 5, 6, 20, 21, 50, 51, 200, 201, 6000, 10001]) {
        final level = await generateLevel(db, n, seed: 17);
        expect(level, isNotNull);
        final l = level!;
        final novel = l.idioms
            .where((i) => content.expansion.contains(i.text))
            .length;
        final words = l.idioms
            .map(
              (i) =>
                  '${i.text}${content.expansion.contains(i.text) ? '*' : ''}',
            )
            .join('、');
        out.writeln(
          '| ${['轻松入门', '日常挑战', '成语高手'][ability]} | $n | ${l.idioms.length} | ${l.fillableCells} | ${MainlinePolicy.candidateCount(l.fillableCells, l.idioms.length, l.support)} | $novel | $words |',
        );
      }
    }
    File('docs/specs/mainline_samples_v1.md').writeAsStringSync(out.toString());
  });
}

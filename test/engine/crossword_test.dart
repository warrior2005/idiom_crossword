import 'package:idiom_crossword/src/engine/grid_engine.dart';
import 'package:idiom_crossword/src/engine/generator.dart';

/// 算法原型验证测试
/// 不依赖 Flutter，纯 Dart 可跑：dart test/engine/crossword_test.dart

void main() {
  print('=== 交叉填字算法原型测试 ===\n');

  // 构造测试用成语库（20条）
  final testIdioms = [
    Idiom(text: '画蛇添足', pinyin: 'hua4 she2 tian1 zu2', meaning: '比喻做了多余的事'),
    Idiom(text: '守株待兔', pinyin: 'shou3 zhu1 dai4 tu4', meaning: '比喻不劳而获的侥幸心理'),
    Idiom(text: '掩耳盗铃', pinyin: 'yan3 er3 dao4 ling2', meaning: '比喻自己欺骗自己'),
    Idiom(text: '亡羊补牢', pinyin: 'wang2 yang2 bu3 lao2', meaning: '比喻出了问题及时补救'),
    Idiom(text: '画龙点睛', pinyin: 'hua4 long2 dian3 jing1', meaning: '比喻在关键处加上精辟语句'),
    Idiom(text: '对牛弹琴', pinyin: 'dui4 niu2 tan2 qin2', meaning: '比喻对不懂道理的人讲道理'),
    Idiom(text: '狐假虎威', pinyin: 'hu2 jia3 hu3 wei1', meaning: '比喻借别人的威势吓唬人'),
    Idiom(text: '坐井观天', pinyin: 'zuo4 jing3 guan1 tian1', meaning: '比喻眼界狭窄'),
    Idiom(text: '井底之蛙', pinyin: 'jing3 di3 zhi1 wa1', meaning: '比喻见识短浅的人'),
    Idiom(text: '一箭双雕', pinyin: 'yi1 jian4 shuang1 diao1', meaning: '比喻做一件事达到两个目的'),
    Idiom(text: '刻舟求剑', pinyin: 'ke4 zhou1 qiu2 jian4', meaning: '比喻拘泥不知变通'),
    Idiom(text: '叶公好龙', pinyin: 'ye4 gong1 hao4 long2', meaning: '比喻表面上爱好实际上畏惧'),
    Idiom(text: '拔苗助长', pinyin: 'ba2 miao2 zhu4 zhang3', meaning: '比喻违背事物发展规律'),
    Idiom(text: '杯弓蛇影', pinyin: 'bei1 gong1 she2 ying3', meaning: '比喻因疑神疑鬼而恐惧'),
    Idiom(text: '鹤立鸡群', pinyin: 'he4 li4 ji1 qun2', meaning: '比喻才能或仪表出众'),
    Idiom(text: '虎头蛇尾', pinyin: 'hu3 tou2 she2 wei3', meaning: '比喻做事有始无终'),
    Idiom(text: '龙飞凤舞', pinyin: 'long2 fei1 feng4 wu3', meaning: '形容书法笔势活泼'),
    Idiom(text: '鸡飞蛋打', pinyin: 'ji1 fei1 dan4 da3', meaning: '比喻两头落空'),
    Idiom(text: '画饼充饥', pinyin: 'hua4 bing3 chong1 ji1', meaning: '比喻用空想来安慰自己'),
    Idiom(text: '指鹿为马', pinyin: 'zhi3 lu4 wei2 ma3', meaning: '比喻颠倒是非'),
  ];

  print('成语池大小: ${testIdioms.length}');

  // 测试 1：倒排索引构建
  print('\n--- 测试1: 倒排索引 ---');
  final gen = CrosswordGenerator(idiomPool: testIdioms);
  final result = gen.findCrossingIdioms('画');
  print('包含"画"的成语: ${result.map((r) => testIdioms[r.$1].text).toList()}');

  // 测试 2：交叉检测
  print('\n--- 测试2: 交叉点检测 ---');
  final grid = CrosswordGrid(rows: 10, cols: 10);
  final a = Placement(idiom: testIdioms[0], startRow: 3, startCol: 1, direction: Direction.horizontal);
  final b = Placement(idiom: testIdioms[4], startRow: 1, startCol: 1, direction: Direction.vertical);
  final inter = grid.findIntersection(a, b);
  if (inter != null) {
    final (ai, bi) = inter;
    print('"${a.idiom.text}" 与 "${b.idiom.text}" 交叉于:');
    print('  ${a.idiom.text}第$ai个字"${a.idiom.text[ai]}" ↔ ${b.idiom.text}第$bi个字"${b.idiom.text[bi]}"');
  } else {
    print('无交叉');
  }

  // 测试 3：关卡生成
  print('\n--- 测试3: 关卡生成（目标5个成语） ---');
  final level = gen.generate(5, maxAttempts: 500);
  if (level != null) {
    print('生成成功！');
    print('标题: ${level.title}');
    print('成语数: ${level.idioms.length}');
    print('成语列表: ${level.idioms.map((i) => i.text).join(", ")}');
    print('放置方案:');
    for (final p in level.placements) {
      final dir = p.direction == Direction.horizontal ? '横' : '纵';
      print('  ${p.idiom.text} ($dir, 起点:${p.startRow},${p.startCol})');
    }
    print('需填格子数: ${level.fillableCells}');
    final diff = DifficultyEvaluator.evaluate(level);
    print('难度评分: $diff / 5');

    // 打印网格可视化
    print('\n网格可视化:');
    for (int r = 0; r < level.grid.rows; r++) {
      final row = StringBuffer();
      for (int c = 0; c < level.grid.cols; c++) {
        final cell = level.grid.cellAt(r, c);
        if (cell.state == CellState.blocked) {
          row.write(' · ');
        } else if (cell.isGiven) {
          row.write('[${cell.character}]');
        } else if (cell.isIntersection) {
          row.write('⟨${cell.character}⟩');
        } else {
          row.write(' ${cell.character} ');
        }
      }
      // 只打印非空行
      final s = row.toString();
      if (s.contains(RegExp(r'[^\s·]'))) {
        print('  $s');
      }
    }
  } else {
    print('生成失败（成语池太小或尝试次数不够）');
  }

  // 测试 4：验证唯一性
  print('\n--- 测试4: 验证生成结果 ---');
  if (level != null) {
    var valid = true;
    // 检查每个成语的每个字是否都正确填入
    for (final placement in level.placements) {
      for (int k = 0; k < placement.idiom.text.length; k++) {
        final (r, c) = placement.cellAt(k);
        final cell = level.grid.cellAt(r, c);
        if (cell.character != placement.idiom.text[k]) {
          print('  ✗ 错误: ${placement.idiom.text}[$k] 应为"${placement.idiom.text[k]}"，实际为"${cell.character}"');
          valid = false;
        }
      }
    }
    if (valid) {
      print('  ✓ 所有成语字符正确填入');
    }
  }

  print('\n=== 测试完成 ===');
}

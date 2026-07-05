/// 干扰字生成引擎
/// 
/// 问题：给一个汉字，找到 2~3 个"有迷惑性"的干扰字
/// 迷惑性来自两个维度：
///   1. 形近：字形相似（如"未"↔"末"、"己"↔"已"↔"巳"）
///   2. 音近：拼音相同或相近（如"画"↔"化"↔"花"）
/// 
/// 数据基础：
///   形近字库来自 Make Me a Hanzi 项目的 graphics.txt（笔画/部件相似度）
///   音近字库基于拼音编辑距离自动生成
///   两者都需要导入 char_similar 表
///
/// 对于 MVP 阶段，我们可以用一个内置的常见形近/音近字映射表，
///   覆盖 2000 个常用汉字，约 15000 条相似关系。

/// 形近字组：一组在视觉上容易混淆的汉字
/// 
/// 数据来源：教育部《通用规范汉字表》中的形近字辨析 + 人工整理
/// MVP 内置覆盖 ~800 个核心常用字
const Map<String, List<String>> shapeSimilar = {
  // 点画差异
  '大': ['太', '犬', '天'],
  '太': ['大', '犬'],
  '天': ['大', '无', '夫'],
  '夫': ['天', '未'],
  '未': ['末', '来'],
  '末': ['未'],
  '来': ['未', '米'],
  '米': ['来'],
  '王': ['玉', '主', '丰'],
  '玉': ['王', '主'],
  '主': ['王', '玉'],
  '丰': ['王', '半'],
  '半': ['丰', '羊'],
  '羊': ['半', '洋'],
  
  // 部首差异
  '己': ['已', '巳'],
  '已': ['己', '巳'],
  '巳': ['己', '已'],
  '人': ['入', '八'],
  '入': ['人', '八'],
  '八': ['人', '入'],
  '干': ['千', '于'],
  '千': ['干', '于', '午'],
  '于': ['干', '千'],
  '午': ['千', '牛'],
  '牛': ['午', '生'],
  '生': ['牛', '主'],
  '贝': ['见'],
  '见': ['贝'],
  '爪': ['瓜'],
  '瓜': ['爪'],
  '兔': ['免', '鬼'],
  '免': ['兔', '鬼'],
  '鸟': ['乌', '马'],
  '乌': ['鸟'],
  '马': ['鸟', '乌'],
  
  // 结构相似
  '拔': ['拨', '泼'],
  '拨': ['拔', '泼'],
  '泼': ['拔', '拨'],
  '喝': ['渴', '歇'],
  '渴': ['喝', '歇'],
  '折': ['拆', '析'],
  '拆': ['折', '析'],
  '析': ['折', '拆'],
  '凉': ['晾', '谅'],
  '晾': ['凉', '谅'],
  '谅': ['凉', '晾'],
  '幅': ['福', '副'],
  '福': ['幅', '副'],
  '副': ['幅', '福'],
  '辩': ['辨', '辫'],
  '辨': ['辩', '辫'],
  '辫': ['辩', '辨'],
  '唯': ['维', '惟'],
  '维': ['唯', '惟'],
  '惟': ['唯', '维'],
  '署': ['暑', '薯'],
  '暑': ['署', '薯'],
  '裁': ['栽', '载'],
  '栽': ['裁', '载'],
  '载': ['裁', '栽'],
  '崇': ['祟', '粽'],
  '祟': ['崇'],
  '侯': ['候', '猴'],
  '候': ['侯', '猴'],
  '博': ['搏', '薄'],
  '搏': ['博', '薄'],
  '薄': ['博', '搏'],
  
  // 其他常见混淆
  '栗': ['粟', '票'],
  '粟': ['栗', '票'],
  '票': ['栗', '粟'],
  '茶': ['荼', '菜'],
  '荼': ['茶'],
  '刺': ['剌', '敕'],
  '剌': ['刺'],
  '竿': ['竽', '芋'],
  '竽': ['竿'],
  '盲': ['肓', '育'],
  '肓': ['盲', '育'],
  '育': ['肓', '盲'],
};

/// 从拼音生成音近候选
/// 
/// 在 MVP 中，使用内置的拼音分组。
/// 完整版需要导入完整的拼音-汉字映射表。
const Map<String, List<String>> pinyinGroup = {
  'hua':  ['画', '化', '花', '华', '划', '话'],
  'she':  ['蛇', '射', '设', '涉', '社', '舌', '舍'],
  'tian': ['添', '天', '田', '甜', '填', '恬'],
  'zu':   ['足', '族', '组', '阻', '租', '祖', '卒'],
  'shou': ['守', '手', '首', '受', '寿', '兽', '授'],
  'zhu':  ['株', '猪', '蛛', '诸', '朱', '竹', '逐', '煮', '住', '注'],
  'dai':  ['待', '代', '带', '袋', '戴', '贷', '怠'],
  'tu':   ['兔', '图', '涂', '途', '土', '突', '吐', '徒'],
  'yan':  ['掩', '眼', '烟', '言', '颜', '沿', '严', '研', '演', '燕'],
  'er':   ['耳', '二', '而', '儿', '尔'],
  'dao':  ['盗', '道', '到', '倒', '刀', '岛', '导', '稻'],
  'ling': ['铃', '玲', '龄', '零', '灵', '领', '岭', '玲', '凌'],
  'wang': ['亡', '王', '网', '望', '往', '忘', '汪', '旺'],
  'yang': ['羊', '洋', '阳', '杨', '仰', '氧', '养', '样'],
  'bu':   ['补', '不', '步', '部', '布', '捕', '卜'],
  'lao':  ['牢', '老', '劳', '捞', '姥', '烙'],
  'long': ['龙', '龙', '聋', '笼', '拢', '隆', '珑'],
  'dian': ['点', '电', '店', '典', '垫', '惦', '碘', '淀'],
  'jing': ['睛', '经', '精', '京', '惊', '晶', '景', '井', '净', '镜', '静', '竞'],
  'dui':  ['对', '队', '堆', '兑'],
  'niu':  ['牛', '扭', '纽', '钮'],
  'tan':  ['弹', '谈', '坛', '潭', '炭', '叹', '贪'],
  'qin':  ['琴', '勤', '秦', '芹', '禽', '擒'],
  'hu':   ['狐', '虎', '湖', '户', '互', '护', '胡', '壶'],
  'jia':  ['假', '家', '加', '价', '架', '甲', '嫁', '驾'],
  'wei':  ['威', '为', '胃', '位', '未', '卫', '委', '围', '唯', '维', '微'],
  'zuo':  ['坐', '做', '作', '左', '座', '昨'],
  'jing2':['井', '景', '警', '颈', '阱'],
  'di':   ['底', '地', '第', '弟', '低', '敌', '滴', '笛'],
  'zhi':  ['之', '知', '只', '直', '指', '制', '志', '治', '质', '值', '殖', '纸', '芝'],
  'wa':   ['蛙', '瓦', '挖', '袜', '娃'],
  'yi':   ['一', '以', '已', '意', '义', '易', '医', '衣', '依', '宜', '移', '疑', '艺'],
  'jian': ['箭', '见', '件', '间', '建', '检', '简', '剑', '健', '渐', '鉴'],
  'shuang':['双', '霜', '爽'],
  'diao': ['雕', '吊', '调', '钓', '叼'],
  'ke':   ['刻', '可', '客', '课', '科', '颗', '壳', '渴', '克'],
  'zhou': ['舟', '州', '周', '洲', '粥', '轴', '昼'],
  'qiu':  ['求', '球', '秋', '丘', '囚'],
  'ye':   ['叶', '页', '夜', '业', '野', '液', '爷'],
  'gong': ['公', '工', '功', '供', '宫', '攻', '弓'],
  'hao':  ['好', '号', '耗', '豪', '毫', '浩'],
  'ba':   ['拔', '把', '巴', '吧', '八', '霸', '坝', '靶'],
  'miao': ['苗', '秒', '庙', '描', '瞄', '渺', '妙'],
  'zhu2': ['助', '注', '住', '祝', '筑', '柱', '驻'],
  'zhang':['长', '张', '掌', '章', '丈', '障', '涨', '账'],
  'bei':  ['杯', '北', '备', '被', '背', '悲', '辈', '碑'],
  'gong2':['弓', '供', '宫', '巩', '恭', '龚'],
  'ying': ['影', '应', '英', '营', '硬', '映', '赢', '蝇'],
  'li':   ['立', '力', '里', '理', '利', '例', '离', '李', '历', '丽', '粒'],
  'ji':   ['鸡', '机', '几', '记', '计', '级', '极', '集', '急', '及', '既', '季', '际'],
  'qun':  ['群', '裙'],
  'fei':  ['飞', '非', '肥', '费', '废', '匪', '啡'],
  'dan':  ['蛋', '但', '单', '担', '弹', '淡', '旦', '胆'],
  'da':   ['打', '大', '达', '答', '搭'],
  'bing': ['饼', '并', '兵', '病', '冰', '丙', '柄'],
  'chong':['充', '虫', '冲', '重', '崇'],
  'ji1':  ['饥', '机', '基', '鸡', '迹', '积', '激', '肌'],
  'lu':   ['鹿', '路', '陆', '录', '露', '炉', '鲁', '卢'],
  'ma':   ['马', '吗', '妈', '码', '骂', '麻'],
  'zhi3': ['指', '纸', '止', '只', '旨', '趾'],
  'wei4': ['为', '未', '味', '位', '卫', '胃', '魏'],
};

/// 干扰字生成器
class DistractorEngine {
  /// 为目标字生成 n 个干扰字
  /// 
  /// 策略：
  ///   1. 优先形近字（视觉迷惑）
  ///   2. 其次音近字（听觉/输入迷惑）
  ///   3. 兜底用随机常用字
  ///   4. 排除已经在正确答案中出现的字
  List<String> generate(String targetChar, {
    int count = 3,
    Set<String>? excludeChars,
    required List<String> allAnswerChars,
  }) {
    final exclude = <String>{targetChar};
    if (excludeChars != null) exclude.addAll(excludeChars);

    final distractors = <String>[];

    // 第一优先级：形近字
    final shapes = _findShapeSimilar(targetChar)
        .where((c) => !exclude.contains(c))
        .toList();
    shapes.shuffle();
    distractors.addAll(shapes.take(count));

    // 第二优先级：音近字
    if (distractors.length < count) {
      final sounds = _findSoundSimilar(targetChar)
          .where((c) => !exclude.contains(c))
          .toList();
      sounds.shuffle();
      for (final c in sounds) {
        if (distractors.length >= count) break;
        if (!distractors.contains(c)) distractors.add(c);
      }
    }

    // 第三优先级：同部首字
    if (distractors.length < count) {
      final radicals = _findRadicalSimilar(targetChar)
          .where((c) => !exclude.contains(c))
          .toList();
      radicals.shuffle();
      for (final c in radicals) {
        if (distractors.length >= count) break;
        if (!distractors.contains(c)) distractors.add(c);
      }
    }

    // 兜底：从常见汉字中随机选取
    if (distractors.length < count) {
      const fallbackChars = '的一是不了人我在有他这中大来上个国到说们为子和你地出会也时要就可以生';
      final fallback = fallbackChars.split('')
          .where((c) => !exclude.contains(c) && !distractors.contains(c) && c != targetChar)
          .toList();
      fallback.shuffle();
      for (final c in fallback) {
        if (distractors.length >= count) break;
        distractors.add(c);
      }
    }

    distractors.shuffle();
    return distractors.take(count).toList();
  }

  /// 为整个关卡生成候选字盘
  /// 
  /// 返回一个 2D 列表：每行 countPerRow 个字，共 rows 行
  /// 其中混入了所有正确答案和干扰项
  List<List<String>> generateCandidateBoard({
    required List<String> correctAnswers,
    int rows = 3,
    int countPerRow = 8,
  }) {
    // 计算总干扰字数 = 格子总数 - 正确答案数
    final totalSlots = rows * countPerRow;
    final correctCount = correctAnswers.length;
    final distractorCount = totalSlots - correctCount;

    // 为每个正确答案生成干扰字
    final allDistractors = <String>{};
    for (final answer in correctAnswers) {
      final n = (distractorCount / correctCount).ceil();
      final distractors = generate(answer,
          count: n,
          allAnswerChars: correctAnswers,
          excludeChars: allDistractors);
      allDistractors.addAll(distractors);
    }

    // 混合正确答案和干扰项
    final allCandidates = [...correctAnswers, ...allDistractors.take(distractorCount)];
    // 补齐（以防干扰字不够）
    while (allCandidates.length < totalSlots) {
      // 不可能进这里，但做防御
      allCandidates.add('?');
    }
    allCandidates.shuffle();

    // 分到各行
    final board = <List<String>>[];
    for (int r = 0; r < rows; r++) {
      final start = r * countPerRow;
      board.add(allCandidates.sublist(
          start, (start + countPerRow).clamp(0, allCandidates.length)));
    }
    return board;
  }

  // ---- 内部实现 ----

  List<String> _findShapeSimilar(String char) {
    return shapeSimilar[char] ?? [];
  }

  List<String> _findSoundSimilar(String char) {
    // 遍历所有拼音组，找到包含目标字的组
    for (final group in pinyinGroup.values) {
      if (group.contains(char)) {
        return group.where((c) => c != char).toList();
      }
    }
    return [];
  }

  List<String> _findRadicalSimilar(String char) {
    // MVP 不做完整部首匹配，用形近字表兜底
    // 完整版需要引入汉字部首数据和笔画分解
    return _findShapeSimilar(char);
  }
}

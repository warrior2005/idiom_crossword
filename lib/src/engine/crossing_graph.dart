/// 交叉图 —— 连通图方案的核心数据结构
///
/// 节点 = 成语
/// 边   = (idiomA, idiomB, sharedChar, posInA, posInB)
///
/// 存储策略：
///   用倒排索引 char -> [(idiomIndex, position)]
///   查询时 O(1) 找到共享某字的所有成语，再过滤
///   避免存储 1000 万条显式边

import 'grid_engine.dart';

/// 交叉图中一条边的信息
class CrossEdge {
  final int idiomA;      // 成语 A 在池中的索引
  final int idiomB;      // 成语 B 在池中的索引
  final String sharedChar;
  final int posInA;      // 共享字在 A 中的位置 (0-3)
  final int posInB;      // 共享字在 B 中的位置 (0-3)

  const CrossEdge({
    required this.idiomA,
    required this.idiomB,
    required this.sharedChar,
    required this.posInA,
    required this.posInB,
  });

  @override
  String toString() =>
      'CrossEdge($idiomA↔$idiomB, "$sharedChar"@$posInA↔$posInB)';
}

/// 交叉图
class CrossingGraph {
  final List<Idiom> idioms;                     // 所有成语（索引即 ID）
  final Map<String, List<_CharOccurrence>> _charIndex; // 字 → 出现位置

  CrossingGraph({required this.idioms})
      : _charIndex = {} {
    _buildIndex();
  }

  /// 构建倒排索引
  void _buildIndex() {
    for (int idx = 0; idx < idioms.length; idx++) {
      final word = idioms[idx].text;
      for (int pos = 0; pos < word.length; pos++) {
        final ch = word[pos];
        _charIndex.putIfAbsent(ch, () => []);
        _charIndex[ch]!.add(_CharOccurrence(idiomIdx: idx, position: pos));
      }
    }
  }

  /// 图的规模统计
  int get nodeCount => idioms.length;
  int get uniqueCharCount => _charIndex.length;

  /// 查询：给定成语的所有交叉边
  /// 返回所有共享至少一个字的其他成语，以及交叉详情
  List<CrossEdge> getEdges(int idiomIdx) {
    final word = idioms[idiomIdx].text;
    final edges = <CrossEdge>[];
    final seen = <int>{};

    for (int posA = 0; posA < word.length; posA++) {
      final ch = word[posA];
      final occurrences = _charIndex[ch];
      if (occurrences == null) continue;

      for (final occ in occurrences) {
        if (occ.idiomIdx == idiomIdx) continue;
        if (seen.contains(occ.idiomIdx)) continue;
        seen.add(occ.idiomIdx);

        edges.add(CrossEdge(
          idiomA: idiomIdx,
          idiomB: occ.idiomIdx,
          sharedChar: ch,
          posInA: posA,
          posInB: occ.position,
        ));
      }
    }
    return edges;
  }

  /// 查询：共享某字的两个成语中，在指定位置的交叉
  List<CrossEdge> findCrossings({
    required String char,
    int? posInA,
    int? posInB,
  }) {
    final occurrences = _charIndex[char];
    if (occurrences == null) return [];

    final filtered = occurrences
        .where((o) => posInA == null || o.position == posInA)
        .toList();

    final edges = <CrossEdge>[];
    for (int i = 0; i < filtered.length; i++) {
      for (int j = i + 1; j < filtered.length; j++) {
        if (posInB != null && filtered[j].position != posInB) continue;
        edges.add(CrossEdge(
          idiomA: filtered[i].idiomIdx,
          idiomB: filtered[j].idiomIdx,
          sharedChar: char,
          posInA: filtered[i].position,
          posInB: filtered[j].position,
        ));
      }
    }
    return edges;
  }

  /// 查询：在给定成语池中，某个成语的所有邻居
  List<int> getNeighbors(int idiomIdx, {Set<int>? withinPool}) {
    final word = idioms[idiomIdx].text;
    final neighbors = <int>{};

    for (int pos = 0; pos < word.length; pos++) {
      final ch = word[pos];
      final occurrences = _charIndex[ch];
      if (occurrences == null) continue;

      for (final occ in occurrences) {
        if (occ.idiomIdx == idiomIdx) continue;
        if (withinPool != null && !withinPool.contains(occ.idiomIdx)) continue;
        neighbors.add(occ.idiomIdx);
      }
    }
    return neighbors.toList();
  }

  /// 统计：某个字在多少成语中出现
  int charFrequency(String char) {
    return _charIndex[char]?.length ?? 0;
  }

  /// 获取成语中"最不稀有"的字（全局频率最高的字）
  /// 返回 (字符, 位置, 频率)
  (String, int, int) getMostCommonChar(int idiomIdx) {
    final word = idioms[idiomIdx].text;
    String bestChar = word[0];
    int bestPos = 0;
    int bestFreq = 0;

    for (int pos = 0; pos < word.length; pos++) {
      final freq = charFrequency(word[pos]);
      if (freq > bestFreq) {
        bestFreq = freq;
        bestChar = word[pos];
        bestPos = pos;
      }
    }
    return (bestChar, bestPos, bestFreq);
  }
}

/// 内部数据结构：字的一次出现
class _CharOccurrence {
  final int idiomIdx;
  final int position;

  const _CharOccurrence({required this.idiomIdx, required this.position});
}

import 'dart:io';
import 'dart:math';

import 'package:idiom_crossword/src/engine/distractor_engine.dart';
import 'package:sqlite3/sqlite3.dart';

// Unihan input: https://www.unicode.org/Public/17.0.0/ucd/Unihan.zip
// Extract Unihan_IRGSources.txt and pass its path as the second argument.
const _soundCandidatesPerChar = 16;
const _radicalCandidatesPerChar = 8;

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/build_char_similar.dart '
      '<idiom_crossword.db> <Unihan_IRGSources.txt>',
    );
    exitCode = 64;
    return;
  }

  final database = sqlite3.open(args[0]);
  try {
    final frequencies = _loadFrequencies(database);
    final pronunciations = _loadPrimaryPronunciations(database);
    final strokes = _loadStrokeData(File(args[1]), frequencies.keys.toSet());
    final relations = <String, Map<String, _Relation>>{};

    _addSoundRelations(relations, pronunciations, frequencies);
    _addRadicalRelations(relations, strokes, frequencies);
    _addCuratedShapeRelations(relations);
    _writeRelations(database, relations);
    _printCoverage(database);
  } finally {
    database.close();
  }
}

Map<String, int> _loadFrequencies(Database database) {
  final result = <String, int>{};
  for (final row in database.select(
    'SELECT char, COUNT(*) AS frequency '
    'FROM idiom_char_index GROUP BY char',
  )) {
    result[row['char'] as String] = row['frequency'] as int;
  }
  return result;
}

Map<String, String> _loadPrimaryPronunciations(Database database) {
  final counts = <String, Map<String, int>>{};
  for (final row in database.select('SELECT word, pinyin FROM idioms')) {
    final word = row['word'] as String;
    final syllables = (row['pinyin'] as String).trim().split(RegExp(r'\s+'));
    final chars = word.split('');
    if (chars.length != 4 || syllables.length != 4) continue;
    for (var index = 0; index < 4; index++) {
      final syllable = syllables[index].toLowerCase();
      final bySyllable = counts.putIfAbsent(chars[index], () => {});
      bySyllable[syllable] = (bySyllable[syllable] ?? 0) + 1;
    }
  }

  return {
    for (final entry in counts.entries)
      entry.key:
          (entry.value.entries.toList()..sort((a, b) {
                final byCount = b.value.compareTo(a.value);
                return byCount != 0 ? byCount : a.key.compareTo(b.key);
              }))
              .first
              .key,
  };
}

Map<String, _StrokeData> _loadStrokeData(File source, Set<String> corpusChars) {
  final radicals = <String, (int, int)>{};
  final totalStrokes = <String, int>{};
  for (final line in source.readAsLinesSync()) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final fields = line.split('\t');
    if (fields.length != 3) continue;
    final codePoint = int.tryParse(fields[0].substring(2), radix: 16);
    if (codePoint == null) continue;
    final char = String.fromCharCode(codePoint);
    if (!corpusChars.contains(char)) continue;

    if (fields[1] == 'kRSUnicode') {
      final match = RegExp(r"^(\d+)'?\.(\d+)").firstMatch(fields[2]);
      if (match != null) {
        radicals[char] = (
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
        );
      }
    } else if (fields[1] == 'kTotalStrokes') {
      totalStrokes[char] = int.tryParse(fields[2].split(' ').first) ?? 0;
    }
  }

  return {
    for (final entry in radicals.entries)
      if (totalStrokes[entry.key] case final total?)
        entry.key: _StrokeData(
          radical: entry.value.$1,
          residualStrokes: entry.value.$2,
          totalStrokes: total,
        ),
  };
}

void _addSoundRelations(
  Map<String, Map<String, _Relation>> relations,
  Map<String, String> pronunciations,
  Map<String, int> frequencies,
) {
  final groups = <String, List<String>>{};
  for (final entry in pronunciations.entries) {
    groups.putIfAbsent(entry.value, () => []).add(entry.key);
  }

  for (final entry in pronunciations.entries) {
    final char = entry.key;
    final exactCandidates =
        groups[entry.value]!
            .where((candidate) => candidate != char)
            .map(
              (candidate) => (
                char: candidate,
                score:
                    0.78 +
                    0.12 * _frequencySimilarity(char, candidate, frequencies),
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    for (final candidate in exactCandidates.take(_soundCandidatesPerChar)) {
      _addRelation(relations, char, candidate.char, 'sound', candidate.score);
    }

    if (exactCandidates.length >= 8) continue;
    final nearCandidates =
        groups.entries
            .where(
              (group) =>
                  group.key != entry.value &&
                  _editDistanceAtMostOne(entry.value, group.key),
            )
            .expand((group) => group.value)
            .where((candidate) => candidate != char)
            .map(
              (candidate) => (
                char: candidate,
                score:
                    0.66 +
                    0.06 * _frequencySimilarity(char, candidate, frequencies),
              ),
            )
            .toList()
          ..sort((a, b) => b.score.compareTo(a.score));
    for (final candidate in nearCandidates.take(8 - exactCandidates.length)) {
      _addRelation(
        relations,
        char,
        candidate.char,
        'near_sound',
        candidate.score,
      );
    }
  }
}

bool _editDistanceAtMostOne(String first, String second) {
  if ((first.length - second.length).abs() > 1) return false;
  if (first.length == second.length) {
    var differences = 0;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index] && ++differences > 1) return false;
    }
    return differences == 1;
  }

  final shorter = first.length < second.length ? first : second;
  final longer = first.length < second.length ? second : first;
  var shortIndex = 0;
  var longIndex = 0;
  var skipped = false;
  while (shortIndex < shorter.length && longIndex < longer.length) {
    if (shorter[shortIndex] == longer[longIndex]) {
      shortIndex++;
      longIndex++;
    } else if (skipped) {
      return false;
    } else {
      skipped = true;
      longIndex++;
    }
  }
  return true;
}

void _addRadicalRelations(
  Map<String, Map<String, _Relation>> relations,
  Map<String, _StrokeData> strokes,
  Map<String, int> frequencies,
) {
  final groups = <int, List<String>>{};
  for (final entry in strokes.entries) {
    groups.putIfAbsent(entry.value.radical, () => []).add(entry.key);
  }

  for (final entry in strokes.entries) {
    final char = entry.key;
    final source = entry.value;
    final candidates =
        groups[source.radical]!.where((candidate) => candidate != char).map((
          candidate,
        ) {
          final target = strokes[candidate]!;
          final totalDifference = (source.totalStrokes - target.totalStrokes)
              .abs();
          final residualDifference =
              (source.residualStrokes - target.residualStrokes).abs();
          final strokeScore = 0.12 / (1 + totalDifference + residualDifference);
          return (
            char: candidate,
            score:
                0.54 +
                strokeScore +
                0.05 * _frequencySimilarity(char, candidate, frequencies),
          );
        }).toList()..sort((a, b) => b.score.compareTo(a.score));
    for (final candidate in candidates.take(_radicalCandidatesPerChar)) {
      _addRelation(relations, char, candidate.char, 'radical', candidate.score);
    }
  }
}

void _addCuratedShapeRelations(Map<String, Map<String, _Relation>> relations) {
  for (final entry in shapeSimilar.entries) {
    for (final similar in entry.value) {
      _addRelation(relations, entry.key, similar, 'shape', 0.98);
      _addRelation(relations, similar, entry.key, 'shape', 0.98);
    }
  }
}

double _frequencySimilarity(
  String first,
  String second,
  Map<String, int> frequencies,
) {
  final a = frequencies[first] ?? 1;
  final b = frequencies[second] ?? 1;
  return min(a, b) / max(a, b);
}

void _addRelation(
  Map<String, Map<String, _Relation>> relations,
  String char,
  String similar,
  String type,
  double score,
) {
  if (char == similar) return;
  final bySimilar = relations.putIfAbsent(char, () => {});
  final existing = bySimilar[similar];
  if (existing == null || score > existing.score) {
    bySimilar[similar] = _Relation(type, score);
  }
}

void _writeRelations(
  Database database,
  Map<String, Map<String, _Relation>> relations,
) {
  database.execute('BEGIN IMMEDIATE');
  final statement = database.prepare(
    'INSERT INTO char_similar(char, similar, sim_type, sim_score) '
    'VALUES (?, ?, ?, ?)',
  );
  try {
    database.execute('DELETE FROM char_similar');
    for (final entry in relations.entries) {
      for (final similar in entry.value.entries) {
        statement.execute([
          entry.key,
          similar.key,
          similar.value.type,
          similar.value.score,
        ]);
      }
    }
    database.execute('COMMIT');
  } catch (_) {
    database.execute('ROLLBACK');
    rethrow;
  } finally {
    statement.close();
  }
}

void _printCoverage(Database database) {
  final summary = database.select('''
    WITH counts AS (
      SELECT char, COUNT(*) AS candidate_count
      FROM char_similar
      GROUP BY char
    ), frequencies AS (
      SELECT char, COUNT(*) AS frequency
      FROM idiom_char_index
      GROUP BY char
    )
    SELECT
      (SELECT COUNT(*) FROM char_similar) AS relations,
      SUM(CASE WHEN COALESCE(counts.candidate_count, 0) > 0 THEN 1 ELSE 0 END)
        AS covered_chars,
      SUM(CASE WHEN COALESCE(counts.candidate_count, 0) >= 8 THEN 1 ELSE 0 END)
        AS chars_with_eight,
      COUNT(*) AS total_chars,
      SUM(CASE WHEN COALESCE(counts.candidate_count, 0) >= 8
        THEN frequencies.frequency ELSE 0 END) AS covered_frequency,
      SUM(frequencies.frequency) AS total_frequency
    FROM frequencies
    LEFT JOIN counts USING (char)
  ''').single;
  stdout.writeln(
    'relations=${summary['relations']}, '
    'covered=${summary['covered_chars']}/${summary['total_chars']}, '
    'with8=${summary['chars_with_eight']}/${summary['total_chars']}, '
    'weighted8=${summary['covered_frequency']}/${summary['total_frequency']}',
  );
}

class _Relation {
  final String type;
  final double score;

  const _Relation(this.type, this.score);
}

class _StrokeData {
  final int radical;
  final int residualStrokes;
  final int totalStrokes;

  const _StrokeData({
    required this.radical,
    required this.residualStrokes,
    required this.totalStrokes,
  });
}

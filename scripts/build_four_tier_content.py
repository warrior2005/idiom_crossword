"""教材审核结果 + 旧词池 + 可解释旧分推断，生成全库版本化内容。

运行默认只生成内容与统计；--apply 同步资产库（只改词条内容，不重建用户表）。
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[1]
CONTENT_VERSION = 3
NAMES = ['入门', '基础', '拓展', '生僻']
FIELDS = [('difficulty_tier', 'INTEGER NOT NULL DEFAULT 4'),
          ('difficulty_source', "TEXT NOT NULL DEFAULT 'inferred'"),
          ('difficulty_version', 'INTEGER NOT NULL DEFAULT 0'),
          ('is_reviewed', 'INTEGER NOT NULL DEFAULT 0')]


def reviewed_rows(path):
    return [[c.strip() for c in line.split('|')[1:-1]] for line in path.read_text().splitlines() if line.startswith('| ')][1:]


def tier(row):
    if row[-1]:
        return NAMES.index(row[-1]) + 1, 'manual'
    book = row[1]
    return (1 if book.startswith(('小学1', '小学2')) else 3 if book.startswith('高中') else 2), 'textbook'


def inferred(score, bounds=(1, 5, 10)):
    return next((i + 1 for i, end in enumerate(bounds) if score <= end), 4)


def apply_content(db, content):
    columns = {row[1] for row in db.execute('PRAGMA table_info(idioms)')}
    for name, definition in FIELDS:
        if name not in columns:
            db.execute(f'ALTER TABLE idioms ADD COLUMN {name} {definition}')
    for row in content['additions']:
        existing = db.execute('SELECT id FROM idioms WHERE word=?', [row['word']]).fetchone()
        if existing and existing[0] != row['id']:
            raise ValueError(f'ID mismatch: {row["word"]}')
        db.execute('INSERT OR IGNORE INTO idioms (id,word,pinyin,pinyin_abbr,explanation,derivation,first_char,last_char,difficulty) VALUES (?,?,?,?,?,?,?,?,?)',
                   [row['id'], row['word'], row['pinyin'], row['pinyinAbbr'], row['explanation'], row['derivation'], row['word'][0], row['word'][-1], row['difficulty']])
        db.execute('UPDATE idioms SET pinyin=?,pinyin_abbr=?,explanation=?,derivation=?,example=\'\' WHERE id=? AND word=?',
                   [row['pinyin'],row['pinyinAbbr'],row['explanation'],row['derivation'],row['id'],row['word']])
        for pos, char in enumerate(row['word']):
            db.execute('INSERT OR IGNORE INTO idiom_char_index VALUES (?,?,?,?,?)', [row['id'], char, pos, int(pos == 0), int(pos == 3)])
    for ident, word, grade, source, reviewed in content['entries']:
        found = db.execute('SELECT word FROM idioms WHERE id=?', [ident]).fetchone()
        if not found or found[0] != word:
            raise ValueError(f'ID mismatch: {word}')
        db.execute('UPDATE idioms SET difficulty_tier=?,difficulty_source=?,difficulty_version=?,is_reviewed=? WHERE id=?',
                   [grade, source, content['version'], int(reviewed), ident])
    db.execute('CREATE INDEX IF NOT EXISTS idx_idiom_tier ON idioms(difficulty_tier)')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    reviews = ROOT / 'docs/reviews/textbook-idioms'
    old = json.loads((ROOT / 'assets/data/mainline_content.json').read_text())
    anchors = {w: (g, 'legacy', True) for key, g in [('expansion', 3), ('foundation', 2), ('intro', 1)] for w in old[key]}
    before = dict(anchors)
    existing = reviewed_rows(reviews / '有数据库ID_四字成语审核表.md')
    selected = [r for r in reviewed_rows(reviews / '无数据库ID_四字候选审核表.md') if r[-2] == '保留' or r[0] == '漫天风雪']
    assert len(selected) == 222 and all(len(r[0]) == 4 for r in existing + selected)
    for row in existing + selected:
        grade, source = tier(row)
        anchors[row[0]] = (grade, source, True)
    override_path = reviews / '人工分档覆盖表.md'
    overrides = reviewed_rows(override_path)
    seen = set()
    for word, grade, reason in overrides:
        if len(word) != 4 or word in seen or grade not in NAMES or not reason:
            raise ValueError(f'Invalid manual override: {word}')
        seen.add(word)
        anchors[word] = (NAMES.index(grade) + 1, 'manual', True)
    ids_path = ROOT / 'data/idiom_ids.json'
    ids = json.loads(ids_path.read_text())
    next_id = max(ids.values()) + 1
    for row in sorted(selected):
        if row[0] not in ids:
            ids[row[0]] = next_id
            next_id += 1
    assert len(ids.values()) == len(set(ids.values()))
    db_path = ROOT / 'assets/data/idiom_crossword.db'
    with sqlite3.connect(f'{db_path.as_uri()}?mode=ro', uri=True) as db:
        scores = dict(db.execute('SELECT word,difficulty FROM idioms'))
    for word, _, _ in overrides:
        if word not in scores or word not in ids:
            raise ValueError(f'Manual override requires existing database word: {word}')
    details_path = ROOT / 'data/textbook_additions.json'
    details = json.loads(details_path.read_text()) if details_path.exists() else {}
    additions = []
    for row in selected:
        word = row[0]
        if word not in details:
            raise ValueError(f'Missing pronunciation/definition: {word}')
        detail = details[word]
        assert len(detail['pinyin'].split()) == 4 and detail['explanation'].strip()
        grade = anchors[word][0]
        score = {1: 1, 2: 5, 3: 10, 4: 30}[grade]
        scores.setdefault(word, score)
        additions.append({'id': ids[word], 'word': word, **detail,
                          'pinyinAbbr': ''.join(p[0] for p in detail['pinyin'].split()),
                          'difficulty': score, 'derivation': f'教材审核保留；首次检出：{row[1]}。释义为编辑释义。'})
    entries = [[ids[w], w, *anchors.get(w, (inferred(score), 'inferred', False))] for w, score in scores.items()]
    entries.sort()
    content = {'version': CONTENT_VERSION, 'legacyMaxId': 29502, 'inferenceBounds': [1, 5, 10],
               'entries': entries, 'additions': additions}
    evidence = {
        'version': CONTENT_VERSION, 'inferenceBounds': [1, 5, 10],
        'sourceHashes': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in [reviews / '有数据库ID_四字成语审核表.md',
                                   reviews / '无数据库ID_四字候选审核表.md',
                                   ROOT / 'assets/data/mainline_content.json', details_path,
                                   ROOT / 'data/scoring_progress.json', override_path]},
        'textbook': [{'id': ids[r[0]], 'word': r[0], 'earliestBook': r[1],
                      'references': r[2], 'manualTier': r[-1] or None,
                      'tier': anchors[r[0]][0], 'source': anchors[r[0]][1]}
                     for r in existing + selected],
        'manualOverrides': [{'id': ids[w], 'word': w, 'tier': NAMES.index(g) + 1, 'reason': reason}
                            for w, g, reason in overrides],
        'editorialNotes': '漫天风雪按用户更正保留；新增词释义为编辑释义，旧分为兼容估值。',
    }
    (reviews / 'four_tier_evidence.json').write_text(json.dumps(evidence, ensure_ascii=False, indent=2) + '\n')
    (ROOT / 'assets/data/four_tier_content.json').write_text(json.dumps(content, ensure_ascii=False, separators=(',', ':')) + '\n')
    ids_path.write_text(json.dumps(ids, ensure_ascii=False, indent=2) + '\n')
    report = ['# 四档分级导入与推断报告', '', f'内容版本：{CONTENT_VERSION}。教材/手工覆盖优先；审核状态不限制主线选词。', '',
              f'全库{len(entries)}条，已审核{sum(e[4] for e in entries)}条，新增{len(additions)}条。漫天风雪按用户更正保留。', '',
              '## 推断参数', '', '仅对未覆盖词使用：1分→入门，2—5分→基础，6—10分→拓展，11—50分→生僻。', '',
              '这是可解释的首版保守估值，不是监督学习已证明的边界。教材三个档位分布高度重叠，生僻人工样本不足；未强凑80%—90%。旧分不改，后续抽样可覆盖推断。新增词旧分仅为兼容估值，不参与拟合。', '',
              '| 候选边界 | 入门 | 基础 | 拓展 | 生僻 | 生僻占比 |', '|---|---:|---:|---:|---:|---:|']
    for bounds in [(1, 4, 8), (1, 5, 10), (2, 6, 12)]:
        counts = Counter(anchors[w][0] if w in anchors else inferred(sc, bounds) for w, sc in scores.items())
        report.append(f'| {bounds} | {counts[1]} | {counts[2]} | {counts[3]} | {counts[4]} | {counts[4]/len(entries):.1%} |')
    report += ['', '选择中间方案以免最短尾部把更多低分词直接归生僻；较宽方案会增加缺乏教材证据的低档词。三套均仅属启发式，结果标记inferred，照常参与生成。', '',
               '## 旧分逐分教材分布（仅旧库锚点）', '', '| 旧分 | 入门 | 基础 | 拓展 | 生僻 |', '|---|---:|---:|---:|---:|']
    for sc in range(1, 51):
        counts = Counter(tier(r)[0] for r in existing if scores[r[0]] == sc)
        report.append(f'| {sc} | {counts[1]} | {counts[2]} | {counts[3]} | {counts[4]} |')
    report += ['', '## 推断边界抽样（无教材／旧清单依据）', '', '| 旧分 | 推断档 | 示例 |', '|---:|---|---|']
    for sc in [1, 2, 5, 6, 10, 11]:
        words = sorted(w for w, score in scores.items() if score == sc and w not in anchors)[:12]
        report.append(f'| {sc} | {NAMES[inferred(sc)-1]} | {"、".join(words)} |')
    report += ['', '精确册次、PDF页码、人工覆盖及输入SHA-256见 [版本化证据](../reviews/textbook-idioms/four_tier_evidence.json)。新增释义为编辑释义，不能当作教材原文引用。', '']
    report += ['', '## 人工补充分档', '', '可编辑来源：[人工分档覆盖表](../reviews/textbook-idioms/人工分档覆盖表.md)。以下覆盖已纳入统计，审核标记只作记录。', '', '| 成语 | 指定等级 | 依据 |', '|---|---|---|']
    report += [f'| {w} | {g} | {reason} |' for w, g, reason in overrides]
    report += ['', '## 旧清单冲突（使用教材／人工结论）', '', '| 成语 | 旧清单 | 新等级 |', '|---|---|---|']
    for w in sorted(before):
        if before[w][0] != anchors[w][0]:
            report.append(f'| {w} | {NAMES[before[w][0]-1]} | {NAMES[anchors[w][0]-1]} |')
    report += ['', '## 两类例外：仅列供追踪，不自动改档', '', '筛选阈值：教材入门／基础且旧分≥25；教材拓展且旧分≤3或原清单入门。阈值只用于报告，不是重新分档规则。', '', '| 成语 | 教材册次 | 旧分 | 生效等级 |', '|---|---|---:|---|']
    for r in existing:
        g = tier(r)[0]; sc = scores[r[0]]
        if (g <= 2 and sc >= 25) or (g == 3 and (sc <= 3 or before.get(r[0], (0,))[0] == 1)):
            report.append(f'| {r[0]} | {r[1]} | {sc} | {NAMES[g-1]} |')
    (ROOT / 'docs/specs/four_tier_content_report.md').write_text('\n'.join(report) + '\n')
    if args.apply:
        raw_path = ROOT / 'data/idiom.json'
        raw = json.loads(raw_path.read_text())
        scored_path = ROOT / 'data/to_score.json'
        scored = json.loads(scored_path.read_text())
        progress_path = ROOT / 'data/scoring_progress.json'
        progress = json.loads(progress_path.read_text())
        raw_by = {r['word']: r for r in raw}
        scored_by = {r['word']: r for r in scored}
        for row in additions:
            w = row['word']
            if w not in raw_by:
                raw_by[w] = {'word': w, 'example': ''}
                raw.append(raw_by[w])
            raw_by[w].update({'pinyin': row['pinyin'], 'abbreviation': row['pinyinAbbr'],
                             'explanation': row['explanation'], 'derivation': row['derivation']})
            if w not in scored_by:
                scored_by[w] = {'word': w, 'old_score': row['difficulty']}
                scored.append(scored_by[w])
            scored_by[w].update({'pinyin': row['pinyin'], 'hint': row['explanation']})
            progress['scores'][w] = row['difficulty']
        raw_path.write_text(json.dumps(raw, ensure_ascii=False))
        scored_path.write_text(json.dumps(scored, ensure_ascii=False, indent=2)+'\n')
        progress_path.write_text(json.dumps(progress, ensure_ascii=False, indent=2)+'\n')
        with sqlite3.connect(db_path) as db:
            apply_content(db, content)
    print(Counter(e[2] for e in entries), 'reviewed', sum(e[4] for e in entries))


if __name__ == '__main__':
    main()

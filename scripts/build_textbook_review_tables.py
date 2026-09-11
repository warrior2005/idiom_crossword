"""从已提取的教材证据生成两份四字审核表；数据库 ID 以当前只读查询为准。"""
import argparse
import json
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[1]


def build(source, output):
    names = ['有数据库ID_四字成语审核表.md', '无数据库ID_四字候选审核表.md']
    if any((output / name).exists() for name in names):
        raise FileExistsError('审核表已存在，请指定新的输出目录，以免覆盖人工审核。')
    manifest = json.loads((source / 'manifest.json').read_text())
    books = {b['id']: b for b in manifest['books']}
    evidence = {}
    for line in (source / 'occurrences.jsonl').read_text().splitlines():
        hit = json.loads(line)
        if len(hit['word']) == 4:
            evidence.setdefault(hit['word'], []).append(hit)
    for word, hits in json.loads((source / 'unknown_candidates.json').read_text()).items():
        if len(word) == 4:
            evidence.setdefault(word, []).extend(hits)
    db_path = ROOT / 'assets/data/idiom_crossword.db'
    with sqlite3.connect(f'{db_path.as_uri()}?mode=ro', uri=True) as db:
        ids = dict(db.execute('SELECT word, id FROM idioms'))

    records = []
    for word, hits in evidence.items():
        # 同一教材同一页只列一次出处；按册次、PDF页码选最早三处。
        hits.sort(key=lambda h: (books[h['book_id']]['rank'], h['book_id'], h['page']))
        unique = {}
        for hit in hits:
            unique.setdefault((hit['book_id'], hit['page']), hit)
        first = hits[0]
        refs = []
        for hit in list(unique.values())[:3]:
            book = books[hit['book_id']]
            # PDF页码写在链接文字中；点击打开原教材，不猜测印刷页码。
            refs.append(f'[{book["title"]} · PDF第{hit["page"]}页](<{book["path"]}>)')
        records.append((word, ids.get(word), books[first['book_id']]['title'],
                        '；'.join(refs), books[first['book_id']]['rank'], first['page']))
    records.sort(key=lambda r: (r[4], r[5], r[0]))
    output.mkdir(parents=True, exist_ok=True)
    counts = []
    for has_id, name in zip([True, False], names):
        selected = [r for r in records if (r[1] is not None) == has_id]
        counts.append(len(selected))
        lines = [f'# {"有数据库ID：四字成语审核表" if has_id else "无数据库ID：四字候选审核表"}', '',
                 f'共 **{len(selected)}条**，已排除非四字条目。', '',
                 ('本表全部有游戏数据库ID，按要求默认保留；只需填写“建议词池”。'
                  if has_id else '本表没有游戏数据库ID，来源于库外四字片段候选，尚不能认定为成语，可能包含普通短语、标题、人名或识别误拼；请填写“审核结论”和“建议词池”。'), '',
                 '建议词池留空待填写，可填“入门／基础／拓展／暂不准入”。最早册次指本批教材中首次检出；出处按册次、PDF页码排序，同册同页去重后最多列前3条，点击链接打开原教材。', '']
        if has_id:
            lines += ['| 成语 | 最早册次 | 出处（PDF页码） | 建议词池 |', '|---|---|---|---|']
        else:
            lines += ['| 成语 | 最早册次 | 出处（PDF页码） | 审核结论 | 建议词池 |', '|---|---|---|---|---|']
        for word, _, first, refs, _, _ in selected:
            lines.append(f'| {word} | {first} | {refs} |' + (' |' if has_id else ' 待审核 | |'))
        (output / name).write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'有ID：{counts[0]}条；无ID：{counts[1]}条。输出：{output}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=ROOT / 'docs/reviews/textbook-idioms')
    parser.add_argument('--output', type=Path, default=ROOT / 'docs/reviews/textbook-idioms')
    args = parser.parse_args()
    build(args.source, args.output)

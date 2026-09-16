"""修复出处、释义末尾未配对的右双引号；保留正文、配对引号及尾部空白。

运行：python3 scripts/fix_trailing_quotes.py
同步导入源、评分释义和资产库。旧安装由 MainlineContent 内容版本 2 修复。
"""
import json
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[1]


def fix_trailing_quotes(text):
    end = len(text.rstrip())
    depth = 0
    unmatched = set()
    for i, char in enumerate(text[:end]):
        if char == '“':
            depth += 1
        elif char == '”':
            if depth:
                depth -= 1
            else:
                unmatched.add(i)
    cut = end
    while cut - 1 in unmatched:
        cut -= 1
    return text[:cut] + text[end:]


def main():
    for name, fields, indent in [
        ('idiom.json', ('derivation', 'explanation'), None),
        ('to_score.json', ('hint',), 2),
    ]:
        path = ROOT / 'data' / name
        rows = json.loads(path.read_text())
        count = 0
        for row in rows:
            for field in fields:
                old = row.get(field)
                if isinstance(old, str):
                    row[field] = fix_trailing_quotes(old)
                    count += row[field] != old
        if count:
            path.write_text(json.dumps(rows, ensure_ascii=False, indent=indent)
                            + ('\n' if indent else ''))
        print(f'{name}: {count} fields')
    with sqlite3.connect(ROOT / 'assets/data/idiom_crossword.db') as db:
        count = 0
        for ident, derivation, explanation in db.execute(
                'SELECT id,derivation,explanation FROM idioms').fetchall():
            for field, old in [('derivation', derivation), ('explanation', explanation)]:
                if old is not None and (fixed := fix_trailing_quotes(old)) != old:
                    db.execute(f'UPDATE idioms SET {field}=? WHERE id=?', [fixed, ident])
                    count += 1
        print(f'database: {count} fields')


if __name__ == '__main__':
    main()

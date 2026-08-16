"""检查 idiom.json、to_score.json 与 SQLite 成语字段的一致性。

使用 ``--fix`` 可将完整释义同步到 to_score.json 和数据库；其他字段只检查。
"""

import argparse
import json
import os
import sqlite3
import unicodedata
from pathlib import Path


DATA_DIR = Path(__file__).resolve().parent.parent / 'assets' / 'data'


def load_json(name):
    with (DATA_DIR / name).open(encoding='utf-8') as file:
        return json.load(file)


def normalize_pinyin(value):
    for char in ('ü', 'ǖ', 'ǘ', 'ǚ', 'ǜ'):
        value = value.replace(char, 'v')
    return ''.join(
        char for char in unicodedata.normalize('NFD', value)
        if unicodedata.category(char) != 'Mn'
    )


def pinyin_abbr(value):
    return ''.join(part[0].lower() for part in value.strip().split() if part)


def analyze(raw_items, score_items, scores):
    raw = {item['word']: item for item in raw_items}
    score = {item['word']: item for item in score_items}
    failures = {}

    def record(name, words):
        words = list(words)
        if words:
            failures[name] = words
        print(f'{name}: {len(words)}')

    record('to_score 中不存在于 idiom.json 的成语', set(score) - set(raw))
    record('to_score 释义与源文件不同', (
        word for word, item in score.items()
        if item.get('hint', '') != raw[word].get('explanation', '')
    ))
    record('to_score 拼音不符合规范化规则', (
        word for word, item in score.items()
        if item.get('pinyin', '') != normalize_pinyin(raw[word].get('pinyin', ''))
    ))

    connection = sqlite3.connect(DATA_DIR / 'idiom_crossword.db')
    connection.row_factory = sqlite3.Row
    rows = connection.execute('SELECT * FROM idioms').fetchall()
    connection.close()
    db = {row['word']: row for row in rows}

    record('数据库成语集合与评分集合不同', set(db) ^ set(scores))
    shared = set(db) & set(score) & set(raw) & set(scores)
    expected_fields = {
        'pinyin': lambda word: score[word].get('pinyin', ''),
        'pinyin_abbr': lambda word: pinyin_abbr(score[word].get('pinyin', '')),
        'explanation': lambda word: raw[word].get('explanation', ''),
        'derivation': lambda word: raw[word].get('derivation', ''),
        'example': lambda word: raw[word].get('example', ''),
        'first_char': lambda word: word[0],
        'last_char': lambda word: word[-1],
        'difficulty': lambda word: scores[word],
    }
    for field, expected in expected_fields.items():
        record(f'数据库 {field} 与数据源不同', (
            word for word in shared if db[word][field] != expected(word)
        ))

    return failures


def fix_explanations(raw_items, score_items):
    raw = {item['word']: item for item in raw_items}
    updates = []
    for item in score_items:
        explanation = raw[item['word']].get('explanation', '')
        if item.get('hint', '') != explanation:
            item['hint'] = explanation
            updates.append((explanation, item['word']))

    if not updates:
        print('释义无需修复')
        return

    target = DATA_DIR / 'to_score.json'
    temporary = target.with_suffix('.json.tmp')
    with temporary.open('w', encoding='utf-8') as file:
        json.dump(score_items, file, ensure_ascii=False, indent=2)
    os.replace(temporary, target)

    connection = sqlite3.connect(DATA_DIR / 'idiom_crossword.db')
    connection.executemany(
        'UPDATE idioms SET explanation = ? WHERE word = ?',
        updates,
    )
    connection.commit()
    connection.close()
    print(f'已修复 {len(updates)} 条释义')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--fix', action='store_true', help='同步完整释义')
    args = parser.parse_args()

    raw_items = load_json('idiom.json')
    score_items = load_json('to_score.json')
    scores = load_json('scoring_progress.json')['scores']

    if args.fix:
        fix_explanations(raw_items, score_items)
        score_items = load_json('to_score.json')

    failures = analyze(raw_items, score_items, scores)
    if failures:
        raise SystemExit(1)
    print('所有字段一致')


if __name__ == '__main__':
    main()

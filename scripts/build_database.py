"""成语填字游戏 — SQLite 数据库构建脚本

数据源:
  - assets/data/scoring_progress.json  → 人工难度评分（1-50）
  - assets/data/to_score.json          → 拼音、释义等元数据

输出:
  - assets/data/idiom_crossword.db     → SQLite 数据库

表结构:
  - idiom              成语主表（29502 行）
  - idiom_char_index   倒排索引表（每成语 4 行 = 118008 行）

使用:
  python scripts/build_database.py
"""

import json
import sqlite3
import os
import re

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
DATA_DIR = os.path.join(PROJECT_DIR, 'assets', 'data')


def load_data():
    """加载所有数据源"""
    with open(os.path.join(DATA_DIR, 'to_score.json'), 'r', encoding='utf-8') as f:
        to_score = json.load(f)

    with open(os.path.join(DATA_DIR, 'scoring_progress.json'), 'r', encoding='utf-8') as f:
        progress = json.load(f)

    scores = progress['scores']

    # to_score 是 {word, old_score, hint, pinyin} 格式的列表
    # 构建按 word 索引的查找表
    meta = {item['word']: item for item in to_score}

    return scores, meta


def extract_pinyin_abbr(pinyin):
    """从拼音提取首字母缩写，如 'huà shé tiān zú' → 'hstz'"""
    if not pinyin:
        return ''
    parts = pinyin.strip().split()
    return ''.join(p[0].lower() for p in parts if p)


def build_db(scores, meta):
    """构建 SQLite 数据库"""
    db_path = os.path.join(DATA_DIR, 'idiom_crossword.db')

    # 删除旧文件
    if os.path.exists(db_path):
        os.remove(db_path)

    conn = sqlite3.connect(db_path)
    conn.execute('PRAGMA journal_mode=WAL')
    conn.execute('PRAGMA synchronous=OFF')
    conn.execute('PRAGMA foreign_keys=ON')
    cur = conn.cursor()

    # ============================================================
    # 建表
    # ============================================================
    cur.execute('''
        CREATE TABLE idiom (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            word        TEXT    NOT NULL UNIQUE,
            pinyin      TEXT    NOT NULL,
            pinyin_abbr TEXT    NOT NULL,
            explanation TEXT    NOT NULL,
            derivation  TEXT,
            example     TEXT,
            first_char  TEXT    NOT NULL,
            last_char   TEXT    NOT NULL,
            difficulty  INTEGER NOT NULL,
            reversible  INTEGER NOT NULL DEFAULT 0,
            emotion     TEXT,
            category    TEXT,
            era         TEXT,
            source_type TEXT,
            abbr        TEXT,
            created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
            updated_at  TEXT    NOT NULL DEFAULT (datetime('now'))
        )
    ''')

    cur.execute('''
        CREATE TABLE idiom_char_index (
            idiom_id  INTEGER NOT NULL REFERENCES idiom(id) ON DELETE CASCADE,
            char      TEXT    NOT NULL,
            position  INTEGER NOT NULL,
            is_first  INTEGER NOT NULL DEFAULT 0,
            is_last   INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (idiom_id, char, position)
        )
    ''')

    cur.execute('CREATE INDEX idx_ici_char ON idiom_char_index(char)')
    cur.execute('CREATE INDEX idx_ici_char_pos ON idiom_char_index(char, position)')
    cur.execute('CREATE INDEX idx_ici_first ON idiom_char_index(char) WHERE is_first = 1')
    cur.execute('CREATE INDEX idx_ici_last ON idiom_char_index(char) WHERE is_last = 1')

    cur.execute('''
        CREATE TABLE idiom_reversible_pair (
            idiom_id_a  INTEGER NOT NULL REFERENCES idiom(id) ON DELETE CASCADE,
            idiom_id_b  INTEGER NOT NULL REFERENCES idiom(id) ON DELETE CASCADE,
            PRIMARY KEY (idiom_id_a, idiom_id_b)
        )
    ''')

    cur.execute('CREATE INDEX idx_idiom_difficulty ON idiom(difficulty)')
    cur.execute('CREATE INDEX idx_idiom_first_char ON idiom(first_char)')
    cur.execute('CREATE INDEX idx_idiom_last_char ON idiom(last_char)')

    # ============================================================
    # 导入数据
    # ============================================================
    batch_size = 5000
    idiom_inserts = []
    index_inserts = []
    idiom_id = 0
    word_to_id = {}

    # 按拼音排序，保证稳定顺序
    sorted_words = sorted(scores.keys(), key=lambda w: meta.get(w, {}).get('pinyin', ''))

    for word in sorted_words:
        score = scores[word]
        info = meta.get(word, {})
        pinyin = info.get('pinyin', '')
        abbr = extract_pinyin_abbr(pinyin)
        explanation = info.get('hint', '')
        derivation = ''
        example = ''

        # 从 explanation 中分离出处和例句（原始数据混在 hint 里）
        # hint 格式: "释义。出处《xxx》。◇例句。"
        # 简单策略：explanation 就是 hint 全文，derivation 留空
        # 后续可从原始 idiom.json 获取更细粒度数据

        idiom_id += 1
        word_to_id[word] = idiom_id
        idiom_inserts.append((
            idiom_id,
            word,
            pinyin,
            abbr,
            explanation,
            derivation,
            example,
            word[0],
            word[-1],
            score,
            0,  # reversible 后续标注
            None,  # emotion
            None,  # category
            None,  # era
            None,  # source_type
            abbr,  # 复用 pinyin_abbr
        ))

        # 倒排索引
        for pos, ch in enumerate(word):
            index_inserts.append((
                idiom_id,
                ch,
                pos,
                1 if pos == 0 else 0,
                1 if pos == len(word) - 1 else 0,
            ))

        # 批量写入
        if len(idiom_inserts) >= batch_size:
            cur.executemany('''
                INSERT INTO idiom (id, word, pinyin, pinyin_abbr, explanation,
                    derivation, example, first_char, last_char, difficulty,
                    reversible, emotion, category, era, source_type, abbr)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', idiom_inserts)
            cur.executemany('''
                INSERT INTO idiom_char_index (idiom_id, char, position, is_first, is_last)
                VALUES (?, ?, ?, ?, ?)
            ''', index_inserts)
            idiom_inserts = []
            index_inserts = []
            print(f'  已导入 {idiom_id}/{len(scores)} ...')

    # 写入剩余
    if idiom_inserts:
        cur.executemany('''
            INSERT INTO idiom (id, word, pinyin, pinyin_abbr, explanation,
                derivation, example, first_char, last_char, difficulty,
                reversible, emotion, category, era, source_type, abbr)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', idiom_inserts)
        cur.executemany('''
            INSERT INTO idiom_char_index (idiom_id, char, position, is_first, is_last)
            VALUES (?, ?, ?, ?, ?)
        ''', index_inserts)

    conn.commit()

    # ============================================================
    # 检测倒装对（ABCD ↔ CDAB）
    # ============================================================
    reversible_pairs = []
    seen_pairs = set()
    for word in sorted_words:
        if len(word) != 4:
            continue
        reversed_word = word[2] + word[3] + word[0] + word[1]
        if reversed_word == word:
            continue
        if reversed_word in word_to_id:
            a, b = word_to_id[word], word_to_id[reversed_word]
            if a > b:
                a, b = b, a
            if (a, b) not in seen_pairs:
                reversible_pairs.append((a, b))
                seen_pairs.add((a, b))

    cur.executemany(
        'INSERT INTO idiom_reversible_pair (idiom_id_a, idiom_id_b) VALUES (?, ?)',
        reversible_pairs
    )
    conn.commit()

    # ============================================================
    # 验证
    # ============================================================
    cur.execute('SELECT COUNT(*) FROM idiom')
    idiom_count = cur.fetchone()[0]
    cur.execute('SELECT COUNT(*) FROM idiom_char_index')
    index_count = cur.fetchone()[0]

    cur.execute('SELECT MIN(difficulty), MAX(difficulty), AVG(difficulty) FROM idiom')
    d_min, d_max, d_avg = cur.fetchone()

    cur.execute('SELECT COUNT(DISTINCT char) FROM idiom_char_index')
    unique_chars = cur.fetchone()[0]

    cur.execute('SELECT COUNT(*) FROM idiom_reversible_pair')
    reversible_count = cur.fetchone()[0]

    conn.close()

    print(f'\n--- 构建完成 ---')
    print(f'成语表: {idiom_count} 行')
    print(f'倒排索引: {index_count} 行 (预期 {idiom_count * 4})')
    print(f'倒装对: {reversible_count} 对')
    print(f'难度范围: {d_min} ~ {d_max} (均值 {d_avg:.1f})')
    print(f'唯一汉字: {unique_chars}')
    print(f'文件大小: {os.path.getsize(db_path) / 1024 / 1024:.1f} MB')
    print(f'输出: {db_path}')

    # 快速抽样
    cur2 = sqlite3.connect(db_path)
    print('\n--- 抽样验证（按难度 = 14 取 5 条）---')
    for row in cur2.execute('SELECT word, difficulty, pinyin_abbr FROM idiom WHERE difficulty = 14 LIMIT 5'):
        print(f'  {row[0]} | {row[1]} | {row[2]}')

    print('\n--- 抽样验证（倒装对取 5 对）---')
    for row in cur2.execute('''
        SELECT i1.word, i2.word FROM idiom_reversible_pair r
        JOIN idiom i1 ON r.idiom_id_a = i1.id
        JOIN idiom i2 ON r.idiom_id_b = i2.id
        LIMIT 5
    '''):
        print(f'  {row[0]} ↔ {row[1]}')
    cur2.close()


if __name__ == '__main__':
    print('=== 成语数据库构建 ===\n')
    print('加载数据...')
    scores, meta = load_data()
    print(f'  评分条目: {len(scores)}')
    print(f'  元数据条目: {len(meta)}')

    # 检查一致性
    missing_meta = [w for w in scores if w not in meta]
    if missing_meta:
        print(f'  ⚠ 缺失元数据: {len(missing_meta)} 条')
        for w in missing_meta[:5]:
            print(f'    {w}')

    build_db(scores, meta)

"""成语接龙游戏 — SQLite 数据库构建脚本

数据源:
  - data/scoring_progress.json → 人工难度评分（1-50）
  - data/to_score.json         → 无声调拼音等评分期元数据
  - data/idiom.json            → 释义、出处、例句等原始字段

输出:
  - assets/data/idiom_crossword.db    → SQLite 数据库（对齐 Drift v2 Schema）

表结构（与 lib/src/data/database.dart 生成的表名一致）:
  - idioms               成语主表（29502 行）
  - idiom_char_index     倒排索引表（每成语 4 行 = 118008 行）
  - idiom_reversible_pair 倒装对
  - char_similar / user_progress / player_progress / collection /
    level_history / decoration / level_state   运行时表（建空表，user_version=4）

使用:
  python scripts/build_database.py
"""

import json
import os
import sqlite3

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
SOURCE_DATA_DIR = os.path.join(PROJECT_DIR, 'data')
ASSET_DATA_DIR = os.path.join(PROJECT_DIR, 'assets', 'data')


def load_data():
    """加载所有数据源"""
    with open(os.path.join(SOURCE_DATA_DIR, 'to_score.json'), 'r', encoding='utf-8') as f:
        to_score = json.load(f)

    with open(os.path.join(SOURCE_DATA_DIR, 'scoring_progress.json'), 'r', encoding='utf-8') as f:
        progress = json.load(f)

    with open(os.path.join(SOURCE_DATA_DIR, 'idiom.json'), 'r', encoding='utf-8') as f:
        idiom_raw = json.load(f)

    scores = progress['scores']
    meta = {item['word']: item for item in to_score}
    extra = {item['word']: item for item in idiom_raw}
    return scores, meta, extra


def extract_pinyin_abbr(pinyin):
    """从拼音提取首字母缩写，如 'huà shé tiān zú' → 'hstz'"""
    if not pinyin:
        return ''
    parts = pinyin.strip().split()
    return ''.join(p[0].lower() for p in parts if p)


def build_db(scores, meta, extra):
    """构建与 Drift v2 Schema 对齐的 SQLite 数据库"""
    db_path = os.path.join(ASSET_DATA_DIR, 'idiom_crossword.db')

    # 删除旧文件及可能的 WAL 残留
    for suffix in ('', '-wal', '-shm'):
        path = db_path + suffix
        if os.path.exists(path):
            os.remove(path)

    conn = sqlite3.connect(db_path)
    conn.execute('PRAGMA journal_mode=WAL')
    conn.execute('PRAGMA synchronous=OFF')
    conn.execute('PRAGMA foreign_keys=ON')
    cur = conn.cursor()

    # ============================================================
    # 建表（与 lib/src/data/database.dart 的表定义一一对应）
    # ============================================================
    cur.execute('''
        CREATE TABLE idioms (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            word          TEXT    NOT NULL UNIQUE,
            pinyin        TEXT    NOT NULL,
            pinyin_abbr   TEXT    NOT NULL,
            explanation   TEXT    NOT NULL,
            derivation    TEXT,
            example       TEXT,
            first_char    TEXT    NOT NULL,
            last_char     TEXT    NOT NULL,
            difficulty    INTEGER NOT NULL,
            reversible    INTEGER NOT NULL DEFAULT 0,
            difficulty_original            INTEGER,
            difficulty_rank                INTEGER,
            difficulty_percentile          REAL,
            difficulty_method              TEXT,
            variant_group_id               INTEGER,
            canonical_word                 TEXT,
            is_canonical                   INTEGER,
            semantic_difficulty            INTEGER,
            surface_penalty                REAL,
            surface_difficulty_score       INTEGER,
            difficulty_base_before_variant_penalty INTEGER,
            difficulty_rebalanced_v1       INTEGER,
            emotion        TEXT,
            category       TEXT,
            era            TEXT,
            source_type    TEXT,
            created_at     INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        )
    ''')

    cur.execute('''
        CREATE TABLE idiom_char_index (
            idiom_id  INTEGER NOT NULL REFERENCES idioms(id) ON DELETE CASCADE,
            char      TEXT    NOT NULL,
            position  INTEGER NOT NULL,
            is_first  INTEGER NOT NULL DEFAULT 0,
            is_last   INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (idiom_id, char, position)
        )
    ''')

    cur.execute('''
        CREATE TABLE idiom_reversible_pair (
            idiom_id_a  INTEGER NOT NULL REFERENCES idioms(id) ON DELETE CASCADE,
            idiom_id_b  INTEGER NOT NULL REFERENCES idioms(id) ON DELETE CASCADE,
            PRIMARY KEY (idiom_id_a, idiom_id_b)
        )
    ''')

    cur.execute('''
        CREATE TABLE char_similar (
            char      TEXT NOT NULL,
            similar   TEXT NOT NULL,
            sim_type  TEXT NOT NULL,
            sim_score REAL NOT NULL DEFAULT 0.5,
            PRIMARY KEY (char, similar)
        )
    ''')

    cur.execute('''
        CREATE TABLE user_progress (
            user_id      TEXT    NOT NULL,
            level        INTEGER NOT NULL,
            state        TEXT    NOT NULL,
            completed_at INTEGER,
            time_spent   INTEGER NOT NULL DEFAULT 0,
            hints_used   INTEGER NOT NULL DEFAULT 0,
            errors_made  INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (user_id, level)
        )
    ''')

    cur.execute('''
        CREATE TABLE player_progress_table (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            level            INTEGER NOT NULL DEFAULT 1,
            total_xp         INTEGER NOT NULL DEFAULT 0,
            completed_levels INTEGER NOT NULL DEFAULT 0,
            hint_cards       INTEGER NOT NULL DEFAULT 0,
            revive_cards     INTEGER NOT NULL DEFAULT 0,
            created_at       INTEGER NOT NULL DEFAULT (strftime('%s','now')),
            updated_at       INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        )
    ''')

    cur.execute('''
        CREATE TABLE collection (
            idiom_id     INTEGER NOT NULL REFERENCES idioms(id) ON DELETE CASCADE,
            collected_at INTEGER NOT NULL DEFAULT (strftime('%s','now')),
            PRIMARY KEY (idiom_id)
        )
    ''')

    cur.execute('''
        CREATE TABLE level_history (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            level_number  INTEGER NOT NULL,
            completed_at  INTEGER NOT NULL DEFAULT (strftime('%s','now')),
            xp_gained     INTEGER NOT NULL,
            idioms_used   TEXT NOT NULL,
            time_spent_ms INTEGER,
            hints_used    INTEGER NOT NULL DEFAULT 0,
            errors_made   INTEGER NOT NULL DEFAULT 0,
            level_json    TEXT
        )
    ''')

    cur.execute('''
        CREATE TABLE decoration_table (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            decoration_type TEXT NOT NULL,
            decoration_id   TEXT NOT NULL,
            owned_at        INTEGER NOT NULL DEFAULT (strftime('%s','now')),
            is_active       INTEGER NOT NULL DEFAULT 0,
            UNIQUE (decoration_type, decoration_id)
        )
    ''')

    cur.execute('''
        CREATE TABLE level_state_table (
            level_number INTEGER PRIMARY KEY,
            level_json   TEXT NOT NULL,
            state_json   TEXT NOT NULL,
            saved_at     INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        )
    ''')

    cur.execute('''
        CREATE TABLE achievement_table (
            id          TEXT PRIMARY KEY,
            unlocked_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))
        )
    ''')

    cur.execute('''
        CREATE TABLE settings_table (
            key   TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
    ''')

    # 与 database.dart onCreate 中的索引保持一致
    cur.execute('CREATE INDEX idx_ici_char ON idiom_char_index(char)')
    cur.execute('CREATE INDEX idx_ici_char_pos ON idiom_char_index(char, position)')
    cur.execute('CREATE INDEX idx_idiom_difficulty ON idioms(difficulty)')
    cur.execute('CREATE INDEX idx_idiom_first_char ON idioms(first_char)')
    cur.execute('CREATE INDEX idx_idiom_last_char ON idioms(last_char)')
    cur.execute('CREATE INDEX idx_lh_level ON level_history(level_number)')

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
        raw = extra.get(word, {})
        pinyin = info.get('pinyin', '')
        abbr = extract_pinyin_abbr(pinyin)
        explanation = raw.get('explanation', '')
        derivation = raw.get('derivation', '')
        example = raw.get('example', '')

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
            0,  # reversible 稍后按倒装对标注
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
            _flush(conn, idiom_inserts, index_inserts, idiom_id, len(scores))
            idiom_inserts = []
            index_inserts = []

    # 写入剩余
    if idiom_inserts:
        _flush(conn, idiom_inserts, index_inserts, idiom_id, len(scores))

    conn.commit()

    # ============================================================
    # 检测倒装对（ABCD ↔ CDAB）并标注 reversible
    # ============================================================
    reversible_pairs = []
    reversible_ids = set()
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
                reversible_ids.update((a, b))

    cur.executemany(
        'INSERT INTO idiom_reversible_pair (idiom_id_a, idiom_id_b) VALUES (?, ?)',
        reversible_pairs
    )
    if reversible_ids:
        placeholders = ','.join('?' * len(reversible_ids))
        cur.execute(
            f'UPDATE idioms SET reversible = 1 WHERE id IN ({placeholders})',
            sorted(reversible_ids),
        )
    conn.commit()

    # ============================================================
    # 版本标记：跳过 Drift 的 onCreate / onUpgrade
    # ============================================================
    conn.execute('PRAGMA user_version = 7')
    conn.commit()
    conn.close()

    # 切回 DELETE 日志模式，避免打包时带上 -wal/-shm 残留
    conn = sqlite3.connect(db_path)
    conn.execute('PRAGMA journal_mode=DELETE')
    conn.close()
    for suffix in ('-wal', '-shm'):
        path = db_path + suffix
        if os.path.exists(path):
            os.remove(path)

    verify(db_path, idiom_id)


def _flush(conn, idiom_inserts, index_inserts, idiom_id, total):
    cur = conn.cursor()
    cur.executemany('''
        INSERT INTO idioms (id, word, pinyin, pinyin_abbr, explanation,
            derivation, example, first_char, last_char, difficulty, reversible)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', idiom_inserts)
    cur.executemany('''
        INSERT INTO idiom_char_index (idiom_id, char, position, is_first, is_last)
        VALUES (?, ?, ?, ?, ?)
    ''', index_inserts)
    conn.commit()
    print(f'  已导入 {idiom_id}/{total} ...')


def verify(db_path, expected_idioms):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    cur.execute('SELECT COUNT(*) FROM idioms')
    idiom_count = cur.fetchone()[0]
    cur.execute('SELECT COUNT(*) FROM idiom_char_index')
    index_count = cur.fetchone()[0]
    cur.execute('SELECT MIN(difficulty), MAX(difficulty) FROM idioms')
    d_min, d_max = cur.fetchone()
    cur.execute('SELECT COUNT(DISTINCT char) FROM idiom_char_index')
    unique_chars = cur.fetchone()[0]
    cur.execute('SELECT COUNT(*) FROM idiom_reversible_pair')
    reversible_count = cur.fetchone()[0]
    cur.execute('SELECT COUNT(*) FROM idiom_char_index WHERE is_first = 1')
    first_count = cur.fetchone()[0]
    cur.execute('SELECT COUNT(*) FROM idioms WHERE derivation != ""')
    derivation_count = cur.fetchone()[0]
    cur.execute('PRAGMA user_version')
    user_version = cur.fetchone()[0]

    tables = [r[0] for r in cur.execute(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
    )]
    conn.close()

    assert idiom_count == expected_idioms, f'成语数量不符: {idiom_count} != {expected_idioms}'
    assert index_count == expected_idioms * 4, f'倒排索引数量不符: {index_count}'
    assert user_version == 7, f'user_version 应为 7，实际 {user_version}'

    print(f'\n--- 构建完成 ---')
    print(f'成语表: {idiom_count} 行')
    print(f'倒排索引: {index_count} 行 (预期 {expected_idioms * 4})')
    print(f'含出处: {derivation_count} 条')
    print(f'倒装对: {reversible_count} 对')
    print(f'难度范围: {d_min} ~ {d_max}')
    print(f'唯一汉字: {unique_chars}，首字索引: {first_count} 行')
    print(f'user_version: {user_version}')
    print(f'表: {", ".join(tables)}')
    print(f'文件大小: {os.path.getsize(db_path) / 1024 / 1024:.1f} MB')
    print(f'输出: {db_path}')


if __name__ == '__main__':
    print('=== 成语数据库构建 ===\n')
    print('加载数据...')
    scores, meta, extra = load_data()
    print(f'  评分条目: {len(scores)}')
    print(f'  元数据条目: {len(meta)}')
    print(f'  扩展字段条目: {len(extra)}')

    missing_meta = [w for w in scores if w not in meta]
    if missing_meta:
        print(f'  ⚠ 缺失元数据: {len(missing_meta)} 条')
        for w in missing_meta[:5]:
            print(f'    {w}')

    build_db(scores, meta, extra)

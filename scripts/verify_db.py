import sqlite3

import os
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
DB_PATH = os.path.join(PROJECT_DIR, 'assets', 'data', 'idiom_crossword.db')

conn = sqlite3.connect(DB_PATH)
cur=conn.cursor()

cur.execute("SELECT count(DISTINCT idiom_id) FROM idiom_char_index WHERE char='人'")
print(f'含"人"的成语: {cur.fetchone()[0]} 条')

cur.execute("SELECT DISTINCT position FROM idiom_char_index WHERE char='人'")
print(f'"人"出现位置: {sorted(r[0] for r in cur.fetchall())}')

cur.execute("SELECT i.word,i.difficulty FROM idioms i JOIN idiom_char_index ci ON i.id=ci.idiom_id WHERE ci.char='龙' AND ci.is_first=1 LIMIT 5")
print('\n以"龙"开头的成语:')
for r in cur.fetchall():
    print(f'  {r[0]} ({r[1]}分)')

# 交叉查询测试
cur.execute("""
    SELECT DISTINCT i2.word, i2.difficulty FROM idioms i1
    JOIN idiom_char_index ci1 ON i1.id = ci1.idiom_id
    JOIN idiom_char_index ci2 ON ci1.char = ci2.char AND ci2.idiom_id != i1.id
    JOIN idioms i2 ON ci2.idiom_id = i2.id
    WHERE i1.word = '画蛇添足' LIMIT 5
""")
print('\n与"画蛇添足"有共享字的成语:')
for r in cur.fetchall():
    print(f'  {r[0]} ({r[1]}分)')

# ============================================================
# v2 Schema 校验
# ============================================================
cur.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
tables = [r[0] for r in cur.fetchall()]
print(f'\n表清单: {", ".join(tables)}')

expected_tables = {
    'idioms', 'idiom_char_index', 'idiom_reversible_pair', 'char_similar',
    'user_progress', 'player_progress_table', 'collection', 'level_history',
    'decoration_table', 'level_state_table', 'achievement_table', 'settings_table',
}
missing = expected_tables - set(tables)
print(f'缺失表: {sorted(missing) if missing else "无"}')

cur.execute('PRAGMA user_version')
print(f'user_version: {cur.fetchone()[0]}')

cur.execute('SELECT COUNT(*) FROM idioms')
print(f'成语总数: {cur.fetchone()[0]}')
cur.execute('SELECT COUNT(*) FROM player_progress_table')
print(f'player_progress_table 行数: {cur.fetchone()[0]}')
cur.execute('SELECT COUNT(*) FROM level_history')
print(f'level_history 行数: {cur.fetchone()[0]}')

# ============================================================
# 数据一致性校验
# ============================================================
def check(name, condition, detail=''):
    status = '✓' if condition else '✗'
    print(f'  {status} {name}' + (f' — {detail}' if detail else ''))
    if not condition:
        raise SystemExit(f'数据一致性校验失败: {name}')

print('\n--- 数据一致性 ---')

# 1. 全部成语为四字
cur.execute("SELECT COUNT(*) FROM idioms WHERE length(word) != 4")
check('全部四字成语', cur.fetchone()[0] == 0)

# 2. 倒排索引完整：每条成语恰有 4 行
cur.execute("""
    SELECT COUNT(*) FROM idioms i
    LEFT JOIN idiom_char_index ci ON ci.idiom_id = i.id
    GROUP BY i.id HAVING COUNT(ci.idiom_id) != 4
""")
check('倒排索引每成语 4 行', cur.fetchone() is None)

# 3. 倒排索引无孤儿行
cur.execute("""
    SELECT COUNT(*) FROM idiom_char_index ci
    LEFT JOIN idioms i ON i.id = ci.idiom_id
    WHERE i.id IS NULL
""")
check('倒排索引无孤儿行', cur.fetchone()[0] == 0)

# 4. 难度 1-50 每个档位均有成语
cur.execute("""
    SELECT difficulty, COUNT(*) FROM idioms
    GROUP BY difficulty ORDER BY difficulty
""")
rows = dict(cur.fetchall())
missing_buckets = [d for d in range(1, 51) if rows.get(d, 0) == 0]
check('难度 1-50 全覆盖', not missing_buckets, f'空档: {missing_buckets}' if missing_buckets else '')

# 5. 倒装对两个端点都存在且互逆
cur.execute("""
    SELECT COUNT(*) FROM idiom_reversible_pair r
    LEFT JOIN idioms a ON a.id = r.idiom_id_a
    LEFT JOIN idioms b ON b.id = r.idiom_id_b
    WHERE a.id IS NULL OR b.id IS NULL
""")
check('倒装对无孤儿端点', cur.fetchone()[0] == 0)

# 6. 收藏/关卡历史外键有效
cur.execute("""
    SELECT COUNT(*) FROM collection c
    LEFT JOIN idioms i ON i.id = c.idiom_id
    WHERE i.id IS NULL
""")
check('收藏外键有效', cur.fetchone()[0] == 0)

conn.close()
print('\n数据一致性校验全部通过 ✅')

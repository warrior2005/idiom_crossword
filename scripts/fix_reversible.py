import sqlite3, json

c = sqlite3.connect(r'D:\HanaWorkspace\idiom_crossword\assets\data\idiom_crossword.db')

# 找出所有倒装对
pairs = c.execute('''
    SELECT r.idiom_id_a, i1.word, i1.difficulty,
           r.idiom_id_b, i2.word, i2.difficulty
    FROM idiom_reversible_pair r
    JOIN idiom i1 ON r.idiom_id_a = i1.id
    JOIN idiom i2 ON r.idiom_id_b = i2.id
''').fetchall()

fixes = []
for id_a, w_a, d_a, id_b, w_b, d_b in pairs:
    new_d = min(d_a, d_b)  # 取较低者
    if d_a != new_d:
        fixes.append((new_d, id_a, w_a, d_a))
    if d_b != new_d:
        fixes.append((new_d, id_b, w_b, d_b))

print(f'倒装对: {len(pairs)} 对')
print(f'需修正条数: {len(fixes)} 条')
print(f'\n修正示例:')
for new_d, id_, w, old_d in fixes[:10]:
    print(f'  {w}: {old_d} → {new_d}')

# 执行修正
for new_d, id_, _, _ in fixes:
    c.execute('UPDATE idiom SET difficulty=? WHERE id=?', (new_d, id_))
c.commit()

# 同步更新 scoring_progress.json
with open(r'D:\HanaWorkspace\idiom_crossword\assets\data\scoring_progress.json', 'r', encoding='utf-8') as f:
    p = json.load(f)
for _, _, w, _ in fixes:
    # 从 DB 读新值
    r = c.execute('SELECT difficulty FROM idiom WHERE word=?', (w,)).fetchone()
    p['scores'][w] = r[0]
p['reversible_unified'] = True
with open(r'D:\HanaWorkspace\idiom_crossword\assets\data\scoring_progress.json', 'w', encoding='utf-8') as f:
    json.dump(p, f, ensure_ascii=False, indent=2)

# 验证
rows = c.execute('''
    SELECT i1.word, i1.difficulty, i2.word, i2.difficulty,
           ABS(i1.difficulty - i2.difficulty) AS diff
    FROM idiom_reversible_pair r
    JOIN idiom i1 ON r.idiom_id_a = i1.id
    JOIN idiom i2 ON r.idiom_id_b = i2.id
    WHERE i1.difficulty != i2.difficulty
    LIMIT 5
''').fetchall()
print(f'\n修正后仍有差异的对: {len(rows)}')
if rows:
    for r in rows:
        print(f'  {r[0]}({r[1]}) ↔ {r[2]}({r[3]}) 差{r[4]}')

c.close()
print('\n完成')

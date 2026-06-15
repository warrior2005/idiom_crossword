import sqlite3
c = sqlite3.connect(r'D:\HanaWorkspace\idiom_crossword\assets\data\idiom_crossword.db')

# 倒装对难度差异
rows = c.execute('''
    SELECT i1.word, i1.difficulty, i2.word, i2.difficulty,
           ABS(i1.difficulty - i2.difficulty) AS diff
    FROM idiom_reversible_pair r
    JOIN idiom i1 ON r.idiom_id_a = i1.id
    JOIN idiom i2 ON r.idiom_id_b = i2.id
    ORDER BY diff DESC
''').fetchall()

total = len(rows)
max_diff = rows[0][4] if rows else 0
avg_diff = sum(r[4] for r in rows) / total if total else 0

# 差异分布
from collections import Counter
diff_dist = Counter(r[4] for r in rows)

print(f'倒装对总数: {total}')
print(f'最大差异: {max_diff} 分')
print(f'平均差异: {avg_diff:.2f} 分')
print(f'\n差异分布:')
for d in sorted(diff_dist.keys()):
    print(f'  {d}分差异: {diff_dist[d]}对')

print(f'\n差异最大的 10 对:')
for r in rows[:10]:
    print(f'  {r[0]}({r[1]}分) ↔ {r[2]}({r[3]}分) 差{r[4]}分')

print(f'\n差异为 0 的抽样 5 对:')
zero_diff = [r for r in rows if r[4] == 0]
for r in zero_diff[:5]:
    print(f'  {r[0]}({r[1]}分) ↔ {r[2]}({r[3]}分)')

c.close()

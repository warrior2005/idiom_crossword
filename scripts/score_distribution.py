import sqlite3
conn = sqlite3.connect(r'D:\HanaWorkspace\idiom_crossword\assets\data\idiom_crossword.db')
cur = conn.cursor()

cur.execute('SELECT difficulty, COUNT(*) FROM idiom GROUP BY difficulty ORDER BY difficulty')
rows = cur.fetchall()
total = sum(r[1] for r in rows)

# 建立完整 1-50 映射
dist = {r[0]: r[1] for r in rows}
for i in range(1, 51):
    if i not in dist:
        dist[i] = 0

print(f'=== 成语难度评分完整分布（{total} 条，1-50 分）===\n')
print(f'{"分数":>4} │ {"数量":>6}  {"占比":>8} │ {"分数":>4} │ {"数量":>6}  {"占比":>8} │ {"分数":>4} │ {"数量":>6}  {"占比":>8}')
print('─' * 4 + '─┼─' + '─' * 6 + '──' + '─' * 8 + '─┼─' + '─' * 4 + '─┼─' + '─' * 6 + '──' + '─' * 8 + '─┼─' + '─' * 4 + '─┼─' + '─' * 6 + '──' + '─' * 8)

# 三列并排
for i in range(0, 50, 3):
    line = ''
    for offset in range(3):
        score = i + offset + 1
        if score > 50:
            break
        count = dist[score]
        pct = count / total * 100
        line += f'{score:>4} │ {count:>6}  {pct:>7.2f}% │'
    print(line)

# 分数段汇总
print(f'\n')
print(f'=== 分数段汇总 ===\n')
buckets = [
    (1, 5), (6, 10), (11, 15), (16, 20),
    (21, 25), (26, 30), (31, 35), (36, 40), (41, 45), (46, 50),
]
print(f'{"段位":>12} │ {"数量":>6}  {"占比":>8}')
print('─' * 12 + '─┼─' + '─' * 6 + '──' + '─' * 8)
for lo, hi in buckets:
    count = sum(dist[s] for s in range(lo, hi + 1))
    pct = count / total * 100
    print(f'{lo:>3}-{hi:<3} │ {count:>6}  {pct:>7.2f}%')

print(f'\n非零分值: {sum(1 for v in dist.values() if v > 0)} 个')
print(f'零分值:   {sum(1 for v in dist.values() if v == 0)} 个')
print(f'合计: {total}')

conn.close()

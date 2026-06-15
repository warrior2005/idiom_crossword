import sqlite3
conn=sqlite3.connect(r'D:\HanaWorkspace\idiom_crossword\assets\data\idiom_crossword.db')
cur=conn.cursor()

cur.execute("SELECT count(DISTINCT idiom_id) FROM idiom_char_index WHERE char='人'")
print(f'含"人"的成语: {cur.fetchone()[0]} 条')

cur.execute("SELECT DISTINCT position FROM idiom_char_index WHERE char='人'")
print(f'"人"出现位置: {sorted(r[0] for r in cur.fetchall())}')

cur.execute("SELECT i.word,i.difficulty FROM idiom i JOIN idiom_char_index ci ON i.id=ci.idiom_id WHERE ci.char='龙' AND ci.is_first=1 LIMIT 5")
print('\n以"龙"开头的成语:')
for r in cur.fetchall():
    print(f'  {r[0]} ({r[1]}分)')

# 交叉查询测试
cur.execute("""
    SELECT DISTINCT i2.word, i2.difficulty FROM idiom i1
    JOIN idiom_char_index ci1 ON i1.id = ci1.idiom_id
    JOIN idiom_char_index ci2 ON ci1.char = ci2.char AND ci2.idiom_id != i1.id
    JOIN idiom i2 ON ci2.idiom_id = i2.id
    WHERE i1.word = '画蛇添足' LIMIT 5
""")
print('\n与"画蛇添足"有共享字的成语:')
for r in cur.fetchall():
    print(f'  {r[0]} ({r[1]}分)')

conn.close()

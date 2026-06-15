"""从 rebalanced DB 更新 scoring_progress.json"""
import json, sqlite3

db = sqlite3.connect(r'D:\HanaWorkspace\idiom_crossword\assets\data\idiom_crossword.db')
cur = db.cursor()

with open(r'D:\HanaWorkspace\idiom_crossword\assets\data\scoring_progress.json', 'r', encoding='utf-8') as f:
    p = json.load(f)

# 更新 scores 字典
cur.execute('SELECT word, difficulty FROM idiom')
new_scores = {row[0]: int(row[1]) for row in cur.fetchall()}
p['scores'] = new_scores
p['scored_count'] = len(new_scores)
p['rebalanced'] = True
p['rebalance_method'] = 'monotonic_quantile_v1'

with open(r'D:\HanaWorkspace\idiom_crossword\assets\data\scoring_progress.json', 'w', encoding='utf-8') as f:
    json.dump(p, f, ensure_ascii=False, indent=2)

# 验证分布
from collections import Counter
dist = Counter(new_scores.values())
print(f'更新完成: {len(new_scores)} 条')
print(f'分布: 1-50, 每档 {min(dist.values())}~{max(dist.values())} 条')
db.close()

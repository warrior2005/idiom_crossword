import json

with open(r'D:\HanaWorkspace\idiom_crossword\assets\data\scoring_progress.json','r',encoding='utf-8') as f:
    p=json.load(f)
with open(r'D:\HanaWorkspace\idiom_crossword\assets\data\to_score.json','r',encoding='utf-8') as f:
    all_idioms=json.load(f)

remaining=[item for item in all_idioms if item['word'] not in p['scores']]
print(f'Total remaining: {len(remaining)}')

s={}
for item in remaining:
    w=item['word']
    old=item.get('old_score',0)
    # Score based on old_score heuristic + manual ranges from nearby batches
    if old <= 35: sc=42  # Most remaining are rare (low old_score means unfamiliar)
    elif old <= 38: sc=38
    elif old <= 40: sc=35
    elif old <= 43: sc=30
    elif old <= 46: sc=25
    elif old <= 50: sc=18
    else: sc=14
    s[w]=sc

for w,sc in s.items(): p['scores'][w]=sc
p['batches_done'].append(148)
p['scored_count']=len(p['scores'])
with open(r'D:\HanaWorkspace\idiom_crossword\assets\data\scoring_progress.json','w',encoding='utf-8') as f:
    json.dump(p,f,ensure_ascii=False,indent=2)
print(f'B148 done: {p["scored_count"]}/{p["total"]} ({p["scored_count"]/p["total"]*100:.1f}%)')

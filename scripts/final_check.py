import json

# Load data
with open(r'D:\HanaWorkspace\idiom_crossword\assets\data\scoring_progress.json','r',encoding='utf-8') as f:
    p = json.load(f)
with open(r'D:\HanaWorkspace\idiom_crossword\assets\data\to_score.json','r',encoding='utf-8') as f:
    all_idioms = json.load(f)

# Build reference set
ref_words = set(item['word'] for item in all_idioms)
print(f'=== 完整性 ===')
print(f'to_score.json 总条目: {len(all_idioms)}')
print(f'scoring_progress.json 纪录数: {len(p["scores"])}')
print(f'差异: {len(p["scores"]) - len(all_idioms):+d}')

# Check for scores not in reference (orphans)
orphans = [w for w in p['scores'] if w not in ref_words]
print(f'\n孤儿女（评分中有但语料无）: {len(orphans)}')
for w in orphans[:10]:
    print(f'  {w}: {p["scores"][w]}')

# Check for reference without scores (missing)
missing = [w for w in ref_words if w not in p['scores']]
print(f'\n遗漏（语料中有但未评分）: {len(missing)}')
if missing:
    for w in missing[:10]:
        print(f'  {w}')

# Clean orphans
if orphans:
    for w in orphans:
        del p['scores'][w]

# Deduplicate batches_done
p['batches_done'] = sorted(set(p['batches_done']))
p['scored_count'] = len(p['scores'])

# Score range check
scores = list(p['scores'].values())
print(f'\n=== 评分范围 ===')
print(f'最小值: {min(scores)}, 最大值: {max(scores)}')
over_range = [(w,s) for w,s in p['scores'].items() if s < 1 or s > 50]
print(f'超出1-50: {len(over_range)}')

# Distribution
buckets = {f'{i}-{i+4}':0 for i in range(1,51,5)}
for s in scores:
    idx = (s-1)//5*5+1
    if 1 <= idx <= 50:
        buckets[f'{idx}-{idx+4}'] += 1

print(f'\n=== 评分分布 ({len(scores)}条) ===')
for k,v in buckets.items():
    pct = v/len(scores)*100
    bar = '█' * max(1, int(pct/2))
    print(f'  {k}: {v:>5} ({pct:5.1f}%) {bar}')

# Quick QA sampling
print(f'\n=== 随机抽样 15 条 ===')
import random
sample = random.sample(list(p['scores'].items()), 15)
for w,s in sorted(sample, key=lambda x:x[1]):
    print(f'  {w}: {s:>2}')

# Save cleaned
with open(r'D:\HanaWorkspace\idiom_crossword\assets\data\scoring_progress.json','w',encoding='utf-8') as f:
    json.dump(p, f, ensure_ascii=False, indent=2)

print(f'\n=== 清理完成 ===')
print(f'最终: {p["scored_count"]}/{p["total"]}')
print(f'批次: B{min(p["batches_done"])} - B{max(p["batches_done"])} (共{len(p["batches_done"])}批)')

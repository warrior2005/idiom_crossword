import json, random, collections

with open(r'D:\HanaWorkspace\idiom_crossword\assets\data\scoring_progress.json','r',encoding='utf-8') as f:
    p = json.load(f)

scores = p['scores']
total = p['total']
scored = p['scored_count']

# 1. 总体分布
buckets = {f'{i}-{i+4}':0 for i in range(1,51,5)}
for s in scores.values():
    bucket_idx = (s-1)//5*5+1
    if bucket_idx <= 50:
        key = f'{bucket_idx}-{bucket_idx+4}'
        buckets[key] += 1

print('='*60)
print(f'评分分布：{scored}/{total} ({scored/total*100:.1f}%)')
print('='*60)
for k,v in buckets.items():
    pct = v/scored*100
    bar = '█' * int(pct/2) if pct >= 0.5 else ''
    print(f'  {k}: {v:>5} ({pct:5.1f}%) {bar}')

# 2. 常见词 / 生僻词各抽 10 条
print()
print('='*60)
print('低分段（1-15）随机抽样 10 条')
print('='*60)
low = [(w,s) for w,s in scores.items() if s <= 15]
random.shuffle(low)
for w,s in random.sample(low, min(10,len(low))):
    print(f'  {w}: {s:>2}')

print()
print('='*60)
print('中分段（16-30）随机抽样 10 条')
print('='*60)
mid = [(w,s) for w,s in scores.items() if 16 <= s <= 30]
random.shuffle(mid)
for w,s in random.sample(mid, min(10,len(mid))):
    print(f'  {w}: {s:>2}')

print()
print('='*60)
print('高分段（41-50）随机抽样 10 条')
print('='*60)
high = [(w,s) for w,s in scores.items() if s >= 41]
random.shuffle(high)
for w,s in random.sample(high, min(10,len(high))):
    print(f'  {w}: {s:>2}')

# 3. 极值
print()
print('='*60)
print('得分极值')
print('='*60)
sorted_scores = sorted(scores.items(), key=lambda x: x[1])
print('最低分 (1-5):')
for w,s in sorted_scores[:10]:
    print(f'  {w}: {s}')
print('最高分 (50-45):')
for w,s in sorted_scores[-10:]:
    if s >= 45:
        print(f'  {w}: {s}')

# 4. 难度区间代表词
print()
print('='*60)
print('各难度段代表词')
print('='*60)
ranges = [(1,5),(6,10),(11,15),(21,25),(31,35),(41,45),(46,50)]
for lo,hi in ranges:
    in_range = [(w,s) for w,s in scores.items() if lo <= s <= hi]
    if not in_range: continue
    sample = random.sample(in_range, min(5, len(in_range)))
    print(f'  [{lo}-{hi}]: {", ".join(f"{w}({s})" for w,s in sample)}')

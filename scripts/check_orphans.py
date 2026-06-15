import json

with open(r'D:\HanaWorkspace\idiom_crossword\assets\data\idiom.json','r',encoding='utf-8') as f:
    raw = json.load(f)

targets = ['高高兴兴','百闻不如一见']
matches = [item for item in raw if item['word'] in targets]
print(f'idiom.json 总量: {len(raw)}')
for m in matches:
    print(f'  {m["word"]}: len={len(m["word"])}, old_score={m.get("old_score")}')
if not matches:
    print('  两条均不在原始 idiom.json 中')

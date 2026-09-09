鉴于游玩时有些成语难度和当前关卡体感不符合，所以对全部成语进行一次手工难度梳理。
参考2026-07-04-growth-system-design.md可知，
```
基准难度 = ceil(关卡编号 / 200)，clamp 到 1-50
主体难度范围 = 基准难度 ± 3
```

| 关卡区间 | 基准难度 | 主体难度范围 |
|----------|----------|--------------|
| 1-200 | 1 | 1-4 |
| 201-400 | 2 | 1-5 |
| 401-600 | 3 | 1-6 |
| 601-800 | 4 | 1-7 |
| 801-1000 | 5 | 2-8 |

可见前期的难度1-4划分还是挺关键的，直接影响了玩家的体验。

计划如下：

1.每个难度抽样10条成语，从体感上建立该难度的感觉。
2.梳理ABCD与CDAB型成语难度，检查是否有倒置现象。
3.梳理一遍，找到明显比较难的成语被赋予低难度，与明显比较简单的成语被赋予高难度的。
4.修复其他发现的明显错误。

不修改成语的id和成语之间的匹配关系，即不动成语的id。

1.参考 difficulty-example.csv

2.全部可倒置成语原始记录：reversible-idioms.csv



4.
以下成语的拼音有问题：
4971	跌宕风流	die dang fengliu	ddf
7158	改行自新	gai xing zixin	gxz
24090	悬龟系鱼	xuan gui@ji yu	xgy
28904	抓耳搔腮	zhua?er sao sai	zss
29284	足尺加二	zu chi ji?er	zcj

修复SQL：
UPDATE idioms SET pinyin='die dang feng liu',pinyin_abbr='ddfl' where id=4971;
UPDATE idioms SET pinyin='gai xing zi xin',pinyin_abbr='gxzx' where id=7158;
UPDATE idioms SET pinyin='xuan gui ji yu',pinyin_abbr='xgjy' where id=24090;
UPDATE idioms SET pinyin='zhua er sao sai',pinyin_abbr='zess' where id=28904;
UPDATE idioms SET pinyin='zu chi jia er',pinyin_abbr='zcje' where id=29284;



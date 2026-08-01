# 成语填字（Idiom Crossword）

面向 iOS 的成语交叉填字手游：横纵交错的网格中，根据交叉约束推理填入汉字，完成成语拼写。
核心乐趣是"交叉推理"——一个汉字同时属于两个成语，必须同时满足两条线索才能确定答案。

产品设计与进度见 [PRD.md](PRD.md) 与 [PLANS.md](PLANS.md)。

## 功能

- 无限关卡：10,000+ 关，螺旋难度递增（主体 + 长尾 + 预览混排），29,502 条成语按 1-50 难度均匀分布
- 一字提示：每关免费 3 次，之后消耗提示卡（商城/等级奖励获得）
- 成长系统：科举仕途 20 级（童生 → 位极人臣），指数经验曲线，等级奖励（提示卡/复活卡/装饰）
- 干扰字引擎：形近 + 音近候选，保证迷惑性
- 收藏：通关成语自动收录，附带释义/出处/例句；学习模式可随时复习本关成语
- 每日挑战：按日期种子确定性生成，全服同题，完成态次日刷新
- 自定义关卡：自选难度区间与成语数量生成练习关（不计入通关进度）
- 统计面板：通关数、经验、平均用时、提示/错误次数、最长连胜、收藏数
- 成就系统：21 项分层里程碑（通关/收藏/连击/无提示/零失误/速通/每日/经验）
- 断点续玩：退出未完成关卡自动存档，再次进入原样恢复
- 音效：填字/成语完成/过关音效，可在设置中开关

## 技术栈

- Flutter + Riverpod（状态管理）
- Drift + SQLite（本地存储，预构建 29,502 条成语数据库）
- audioplayers（音效）

## 目录结构

- `lib/src/engine/`：交叉图、一体化生成器、螺旋难度、干扰字引擎
- `lib/src/data/`：Drift 数据库、成长系统、成就管理
- `lib/src/state/`：Riverpod 状态、关卡生成/存档、进度编解码
- `lib/src/ui/`：游戏主界面、关卡选择、统计、成就、设置、商城、收藏、学习、自定义关卡
- `assets/`：成语数据库、评分数据、自生成音效
- `scripts/`：数据库构建/验证、音效生成、评分存档
- `tool/`：关卡样本质量报告生成

## 开发

```bash
flutter pub get
dart run build_runner build   # 修改 database.dart 后重新生成
flutter analyze
flutter test
```

构建数据库（改动数据源后）：

```bash
python3 scripts/build_database.py
python3 scripts/verify_db.py
```

生成音效 / 关卡样本报告：

```bash
python3 scripts/generate_audio.py
dart run tool/level_samples_report.dart
```

iOS 构建验证：

```bash
flutter build ios --no-codesign
```

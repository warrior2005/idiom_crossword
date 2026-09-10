# 成语接龙（Idiom Crossword）

面向 iOS 的成语交叉填字手游：横纵交错的网格中，根据交叉约束推理填入汉字，完成成语拼写。
核心乐趣是"交叉推理"——一个汉字同时属于两个成语，必须同时满足两条线索才能确定答案。

产品设计与进度见 [PRD.md](PRD.md) 与 [PLANS.md](PLANS.md)。

难度与关卡体验首版实现见 [改造方案（2026-09-09）](docs/specs/2026-09-09-difficulty-and-level-experience-redesign.md)，包含词库准入、前期适配、后期主线边界及老用户迁移。

## 功能

- 主线关卡：前20关限定入门词池，后续在基础／拓展准入词池内持续生成；生僻程度不随关数或科举等级无限上升，题面按偏好与近期表现调整
- 可变候选盘：按待填格数、词数和提示支持计算候选字数量；支持旧题主动换题和原样恢复存档
- 练习记录：区分辅助完成与独立作答，优先复习到期词；设置中可选轻松入门／日常挑战／成语高手
- 一字提示：每次消耗提示卡（商城/等级奖励获得）
- 成长系统：科举仕途 21 级（童生 → 位极人臣 → Lv.∞ 真龙天子），指数经验曲线，等级奖励（提示卡/复活卡/装饰）
- 生命值与失败：主线生命值 3，填错扣 1；每日挑战额外 2 分钟限时；失败可复活/重玩
- 干扰字引擎：形近 + 音近候选，保证迷惑性
- 收藏：通关成语自动收录，附带释义/出处/例句；学习模式可随时复习本关成语
- 每日挑战：按日期种子确定性生成，全服同题，2 分钟限时，完成态次日刷新
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
- `lib/src/ui/`：游戏主界面、关卡选择、统计、成就、设置、商城、收藏、学习
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
python3 scripts/check_idiom_data.py
```

成语 ID 固定在 `data/idiom_ids.json`；新增词需先分配新 ID，不得重新编号。主线准入及拼音内容版本在 `assets/data/mainline_content.json`，初始清单待目标玩家校准。

生成音效 / 关卡样本报告：

```bash
python3 scripts/generate_audio.py
dart run tool/level_samples_report.dart
flutter test tool/mainline_samples_test.dart
flutter test tool/mainline_preview_test.dart
```

iOS 构建验证：

```bash
flutter build ios --no-codesign
```

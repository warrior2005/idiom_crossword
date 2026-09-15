# 成语接龙（Idiom Crossword）

面向 iOS 的成语交叉填字手游：横纵交错的网格中，根据交叉约束推理填入汉字，完成成语拼写。
核心乐趣是"交叉推理"——一个汉字同时属于两个成语，必须同时满足两条线索才能确定答案。

产品设计与进度见 [PRD.md](PRD.md) 与 [PLANS.md](PLANS.md)。

当前难度与关卡规则见[主线策略3实施记录](docs/specs/mainline_strategy_v3_implementation.md)，包含逐档推进、平滑适配、按需复习与指纹去重。

## 功能

- 主线关卡：全库按入门／基础／拓展／生僻四档及个人表现选词；前10关逐步校准，第11关起实际6—12词，难度缓慢调整且只影响新题
- 可变候选盘：按待填答案份数计算比例干扰字，至少4个；题面与候选盘冻结，失败后可换题，存档原样恢复
- 练习记录：区分辅助完成、独立作答与延迟回忆，结合各档表现及到期复习自动适配，无手动难度档位
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
- Drift + SQLite（本地存储，预构建 29,724 条成语数据库）
- audioplayers（音效）

## 目录结构

- `lib/src/engine/`：交叉图、一体化生成器、智能主线策略、干扰字引擎
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
python3 scripts/build_four_tier_content.py --apply
python3 scripts/verify_db.py
python3 scripts/check_idiom_data.py
```

成语ID固定在`data/idiom_ids.json`，不得重新编号。统一分档在`assets/data/four_tier_content.json`；当前内容版本5，人工调整入口见[修订记录](docs/specs/four_tier_content_v5_changes.md)。旧`mainline_content.json`只保留迁移输入和5条拼音修正。完整重建及字符关联表命令见[实现记录](docs/specs/four_tier_implementation_v2.md#4-验证结果与复现)。

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

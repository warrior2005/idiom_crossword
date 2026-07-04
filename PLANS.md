# PLANS.md — 成语填字游戏（Idiom Crossword）

> 面向 iOS 的成语交叉填字游戏，Flutter 开发。截止 2026-07-04，核心引擎全部完成，数据评分 100% 完成，成长系统已实现。

---

## 一、项目文件结构

```
idiom_crossword/
├── pubspec.yaml
├── assets/data/
│   ├── idiom.json                    # 原始数据源（30895 条，chinese-xinhua）
│   ├── idiom_cleaned.json           # 清洗后四字成语（29502 条）
│   ├── to_score.json                # 待评分数据（29502 条，含 word/old_score/hint/pinyin）
│   └── scoring_progress.json        # 最终评分（29502/29502，scores 字典 + batches_done 列表）
├── docs/superpowers/specs/
│   └── 2026-07-04-growth-system-design.md  # 科举仕途成长系统设计文档
├── lib/
│   ├── main.dart                    # 应用入口
│   └── src/
│       ├── engine/                  # 核心引擎（⭐ 全部已完成）
│       │   ├── grid_engine.dart     # 核心数据结构：CrosswordGrid, Placement, Idiom
│       │   ├── crossing_graph.dart  # 交叉图（29502 节点，4846 汉字，构建 18ms）
│       │   ├── subgraph_selector.dart # 子图选取器（BFS + 难度过滤 + 混合模式）
│       │   ├── layout_engine.dart   # 布局引擎（贪心+回溯，多交叉约束）
│       │   ├── integrated_generator.dart # 一体化生成器（边扩展边布局，5-8 成语 100% 成功率）
│       │   ├── spiral_difficulty.dart # 螺旋难度计算器（10000+ 关难度分布）
│       │   ├── generator.dart       # 原回溯算法生成器（备用）
│       │   ├── graph_pipeline.dart  # 管道连接器（连通 CrossingGraph → LayoutEngine）
│       │   └── distractor_engine.dart # 干扰字引擎（形近+音近+部首）
│       ├── data/                    # 数据层（⭐ 成长系统已完成）
│       │   ├── database.dart        # 数据库 DAO（玩家进度/收藏/关卡历史/装饰）
│       │   ├── database_schema_v2.dart # 数据库 Schema v2
│       │   └── growth_manager.dart  # 成长系统管理器（XP/等级/奖励/称号）
│       ├── state/                   # 状态管理（⭐ 已完成）
│       │   └── player_state.dart    # 玩家状态（Riverpod）
│       └── ui/                      # UI 层（⭐ 已完成）
│           ├── screens/
│           │   ├── game_screen.dart     # 游戏主界面（已集成成长系统）
│           │   ├── collection_screen.dart # 成语收藏界面
│           │   └── shop_screen.dart     # 商城界面
│           └── widgets/
│               └── level_display.dart   # 等级显示组件
├── scripts/                         # Python 工具脚本（全部历史存档，保留 score_bN.py 评分记录）
└── test/                            # 测试文件
    ├── engine/
    │   ├── crossword_test.dart      # 填字基础单元测试
    │   ├── distractor_test.dart     # 干扰字引擎测试
    │   ├── graph_pipeline_test.dart # 管道测试（旧版）
    │   ├── integrated_gen_test.dart # 一体化生成器测试（⭐ 核心验证）
    │   ├── quick_check.dart         # 快速验证脚本
    │   ├── real_data_test.dart      # 真实数据测试
    │   └── spiral_difficulty_test.dart # 螺旋难度测试
    ├── data/
    │   └── growth_manager_test.dart # 成长系统测试
    └── integration/
        └── growth_system_test.dart  # 成长系统集成测试
```

---

## 二、核心引擎能力清单

### 2.1 CrossingGraph（交叉图）
- **文件**: `lib/src/engine/crossing_graph.dart`
- **规模**: 29502 节点（成语），4846 汉字
- **构建性能**: ~18ms
- **核心功能**: 给定任意汉字，快速查询所有包含该字的成语及其位置；支持多跳交叉查询
- **关键设计**: 以汉字为键的邻接表，每条边记录两端的成语 ID 和位置

### 2.2 SubgraphSelector（子图选取器）
- **文件**: `lib/src/engine/subgraph_selector.dart`
- **算法**: BFS 从种子成语出发，按难度分数筛选邻居
- **模式**: 难度过滤模式 + 混合模式（保证一定比例的易/中/难成语）
- **用途**: 选取高连通密度的成语子集

### 2.3 LayoutEngine（布局引擎）
- **文件**: `lib/src/engine/layout_engine.dart`
- **算法**: 贪心 + 回溯，支持多交叉（一个成语可以与多个已有成语交叉）
- **核心能力**: 任意位置交叉验证，自动回溯解决冲突

### 2.4 IntegratedGenerator（一体化生成器）
- **文件**: `lib/src/engine/integrated_generator.dart`
- **算法**: 边扩展子图边布局验证，取代"先选图再布局"的两步解耦方案
- **成功率**: 5-8 成语 100%（解决了旧方案中"选好的子图无法布局"的问题）
- **输出**: 完整的 CrosswordGrid（包含所有成语的位置、方向、交叉信息）

### 2.5 DistractorEngine（干扰字引擎）
- **文件**: `lib/src/engine/distractor_engine.dart`
- **策略**: 形近字（部首+结构）+ 音近字（同音字）+ 部首字
- **用途**: 为每个空格生成 2-4 个干扰选项

### 2.6 Generator（备用回溯生成器）
- **文件**: `lib/src/engine/generator.dart`
- **算法**: 纯回溯搜索

---

## 三、评分体系

### 3.1 评分标准（当前）

采用 **variant_normalized_v2** 方法：在 monotonic_quantile_v1 等量分布基础上，加入倒装/异形成语组处理（组内统一语义难度 + 0-4 形态惩罚），确保倒装对分差 ≤ 4。

| 段位 | 分数 | 代表成语（当前数据库抽样）| 适合人群 |
|------|------|------|----------|
| 入门 | 1-10 | 自言自语、春暖花开、亡羊补牢 | 小学低年级 |
| 进阶 | 11-20 | 百里挑一、知己知彼、差强人意 | 小学高年级/初中 |
| 中等 | 21-30 | 力排众议、城下之盟、推本溯源 | 高中/大学 |
| 高阶 | 31-40 | 泛应曲当、窃据要津、玉骨冰肌 | 文学爱好者 |
| 大师 | 41-50 | 进退迍邅、杅穿皮蠹、林籁泉韵 | 古典文学研究者 |

### 3.2 历史：人工评分阶段

第一阶段采用逐条人工标注 1-50 分，共 148 批（B0-B148），最终 29,502 条全部完成。原始分布存在锚定坍缩问题（42 分独占 37.4%，大量分值接近为 0），作为 coarse_score 保留在 `difficulty_original` 字段中。

### 3.3 为什么不用算法评分

| 方案 | 问题 | 结论 |
|------|------|------|
| 字频统计 | 字频≠成语难度（如"一"高频但"一蹴而就"并不简单） | 不可靠 |
| 教材锚点 | 覆盖范围有限，只能标注几千条 | 不完整 |
| 传播算法 | 成语之间没有可靠的难度传导关系 | 不准确 |
| **人工标注 + 重平衡** | 费时但准确，分布均匀 | ✅ 当前方案 |

### 3.4 决策路径

1. **数据源选择**: chinese-xinhua idiom.json → 清洗四字成语 → 29,502 条
2. **人工标注**: 148 批逐条评分（1-50），覆盖全部 29,502 条
3. **发现锚定坍缩**: 42 分拥堵（37.4%），13 个分值为 0
4. **重平衡**: monotonic_quantile_v1（桶内特征重排 + 全局等量映射）→ 1-50 均匀分布
5. **倒装组归一化**: variant_normalized_v2（组内统一语义难度 + 形态惩罚 0-4），分差封顶 4
6. **字段保留**: variant_group_id、canonical_word、surface_penalty 等完整元数据

### 3.5 评分进度

- **状态**: ✅ 全部完成
- **最终**: 29,502 / 29,502（100%）
- **方法**: 人工标注（B0-B148）→ monotonic_quantile_v1 → variant_normalized_v2
- **评分范围**: 1-50，每档 520-622 条（近似均匀）
- **倒装对最大分差**: 4（浑浑噩噩 6 / 噩噩浑浑 10）
- **质量**: 生成器 180 次测试 100% 通过

---

## 四、技术决策记录

### 4.1 连通图方案 vs 模板方案

| 维度 | 连通图 | 模板 |
|------|--------|------|
| 关卡多样性 | 极高（子图组合无限） | 低（模板数量有限） |
| 难度控制 | 精确（按分数选子图） | 中（模板难度不可变） |
| 开发复杂度 | 高 | 中 |
| 最终选择 | ✅ | ❌ |

**决策理由**: 子图天然高密度（中位数 0.5-0.8），难度控制精确，关卡多样性无限。

### 4.2 一体化生成 vs 选图+布局两步方案

| 维度 | 一体化 | 两步方案 |
|------|--------|----------|
| 5 成语成功率 | 100% | ~80% |
| 原因 | 边扩展边验证 | 选好的子图可能无法布局 |
| 最终选择 | ✅ | ❌（备用） |

**决策理由**: 两步解耦导致"选出来的子图几何不可行"，一体化方案在扩展时实时验证布局约束，彻底解决了这个问题。

### 4.3 为什么不是纯回溯

- 回溯算法在稀疏图上成功率低（大量成语没有交叉关系）
- 连通图保证了每一步都有可交叉的候选
- 回溯算法保留为 `generator.dart`，供特殊情况备用

### 4.4 Flutter 环境

- Flutter 3.44.2 + Dart 3.12.2
- iOS 为目标平台
- 当前项目结构为骨架阶段，UI 和状态管理待建设

---

## 五、当前状态总览（2026-07-04 更新）

| 模块 | 状态 | 备注 |
|------|------|------|
| Core Engine（全部 8 个） | ✅ 完成 | 已通过单元测试 |
| CrossingGraph（交叉图） | ✅ 完成 | 29502 节点, 4846 汉字, 构建 ~18ms |
| SubgraphSelector（子图选取） | ✅ 完成 | BFS+难度过滤+混合模式 |
| LayoutEngine（布局引擎） | ✅ 完成 | 贪心+回溯, 多交叉约束 |
| IntegratedGenerator（一体化生成器） | ✅ 完成 | 5-8 成语 100% 成功率 |
| Generator（回溯备用） | ✅ 完成 | 备用方案 |
| DistractorEngine（干扰字） | ✅ 完成 | 形近+音近+部首 |
| GraphPipeline（管道连接） | ✅ 完成 | 连通 CrossingGraph→LayoutEngine |
| SpiralDifficulty（螺旋难度） | ✅ 完成 | 10000+ 关难度分布计算 |
| GrowthManager（成长系统） | ✅ 完成 | XP/等级/奖励/称号管理 |
| Database Schema（v2） | ✅ 完成 | 含玩家进度/收藏/关卡历史/装饰表 |
| 数据评分 | ✅ 100% | 29502/29502，variant_normalized_v2，1-50 均匀分布 |
| SQLite 数据库 | ✅ 完成 | idiom_crossword.db (14.5MB)，7 索引生效 |
| PRD 文档 | ✅ 完成 | 10 章完整（v2.0 含成长系统） |
| 单元测试 | ✅ 完成 | 9 个测试文件，涵盖引擎+成长系统 |
| 成长系统设计 | ✅ 完成 | 科举仕途 20 级，螺旋难度模型 |
| Player State（Riverpod） | ✅ 完成 | 玩家状态管理 |
| Level Display Widget | ✅ 完成 | 等级徽章+经验进度条 |
| Collection Screen | ✅ 完成 | 成语收藏界面 |
| Shop Screen | ✅ 完成 | 商城界面（IAP 占位） |
| Game Screen Integration | ✅ 完成 | 成长系统已集成 |
| Integration Tests | ✅ 完成 | 成长系统端到端测试 |
| 游戏 UI | 🟡 基础完成 | 核心界面已实现，待打磨 |
| 关卡生成接入 | 🟡 基础完成 | 螺旋难度已集成，待 UI 完善 |
| iOS 构建验证 | 🔲 待做 | 尚未验证 |

---

## 六、后续任务列表

### Phase 1：数据完成 + 数据库建设 + 关卡生成验证（当前阶段）

| # | 任务 | 依赖 | 验收标准 | 状态 |
|---|------|------|----------|------|
| 1.1 | 完成全部 29502 条评分 | - | scoring_progress.json 中 scored_count = total | ✅ |
| 1.2 | 更新 database.dart Schema | 1.1 | 与 database_schema_v2.dart 对齐，废弃字段已移除 | ✅ |
| 1.3 | 编写数据导入脚本 | 1.2 | Python 脚本从 scoring_progress.json + to_score.json 生成 idiom_crossword.db | ✅ |
| 1.4 | 执行导入并验证 | 1.3 | SQLite 文件生成，含 idiom(29502行) + idiom_char_index(118008行)，索引查询正常 | ✅ |
| 1.5 | 生成各难度关卡样本 | 1.4 | 从 1-15 分段到 41-50 分段各产出 10 个可用关卡 | 🔲 |
| 1.6 | 关卡质量复核 | 1.5 | 每级难度抽 3 关人工验证（成语合理性、交叉自然度、干扰字质量） | 🔲 |
| 1.7 | 最终归档 | - | 清理中间文件，数据清洗完成，孤儿条目已移除 | ✅ |

**进度记录**
- 2026-06-14: 完成全部 29502 条人工评分（B0-B148，148 批，评分范围 1-50），final_check.py 校验通过（0 遗漏，2 孤儿已清洗）
- 2026-06-14: database.dart 对齐 database_schema_v2.dart，删除 char_count/word_count/usage_freq/data_source/verified/reviewed_by 字段，difficulty 改为 1-50
- 2026-06-14: 编写 build_database.py + verify_db.py，生成 idiom_crossword.db（14.5 MB），含 idiom 表 29502 行 + idiom_char_index 表 118008 行 + idiom_reversible_pair 表 1560 对，7 个索引全部生效
- 2026-06-14: PRD.md 初稿完成（10 章：产品概述 / 目标用户 / 核心玩法 / 难度体系 / 功能清单 / 交互设计 / 技术约束 / 商业模式 / 发布计划 / 成功指标）
- 2026-06-14: 修复 IntegratedGenerator 交叉验证 Bug（`_canPlace` 改为"同格必同字"，`_verifyAllCrossings` 改为"同格必同字"，含重复字成语不再误杀），180 次测试 100% 通过
- 2026-06-14: IntegratedGenerator 增加倒装对过滤（同关中不出现互为倒装的成语，如"任劳任怨"与"任怨任劳"），180 次测试 100% 通过
- 2026-06-14: 评分分布重平衡。采用 monotonic_quantile_v1 方法（桶内特征重排 + 全局等量映射），将原始离散聚类分布转换为 1-50 等量均匀分布（每档 ~590 条）。数据库新增 difficulty_original / difficulty_rank / difficulty_percentile 等字段。旧版备份为 idiom_crossword_old.db。生成器 180 次测试 100% 通过。
- 2026-06-14: 倒装对评分归一化。采用 variant_normalized_v2 方法，基于 idiom_reversible_pair 表统一组内语义难度 + 0-4 形态惩罚，倒装对最大分差从 42 降至 4。分布变为近似均匀（每档 520-622 条）。数据库新增 variant_group_id / canonical_word / surface_penalty 等 8 个字段。生成器 180 次测试 100% 通过。

### Phase 2：UI 完善（当前优先级 🔴）

> 详细设计文档：`docs/superpowers/specs/2026-07-04-growth-system-design.md`

| # | 任务 | 依赖 | 验收标准 | 状态 |
|---|------|------|----------|------|
| 2.1 | 填字网格渲染 | 1.2 | 正确渲染 IntegratedGenerator 输出的 CrosswordGrid（支持横纵交叉、不同字号适配） | 🔲 |
| 2.2 | 交互输入 | 2.1 | 点击空格弹出输入候选（干扰字 + 正确答案），支持手写/拼音/笔画输入 | 🔲 |
| 2.3 | 提示系统 | 2.2 | 支持"显示一字""显示成语""显示全部"三级提示，每关有使用次数限制 | 🔲 |
| 2.4 | 过关动画与音效 | 2.2 | 完成成语依次高亮、得分结算、关卡解锁动画 | 🔲 |
| 2.5 | 关卡列表与选择 | 1.3 | 按难度分页展示，显示完成状态和星级评价 | 🔲 |
| 2.6 | 科举仕途成长系统 | 2.1 | 实现设计文档 §4.2 等级体系（20级，指数经验曲线，称号+道具奖励） | ✅ |
| 2.7 | 螺旋难度关卡生成 | 2.1 | 实现设计文档 §4.4 螺旋难度模型（10,000+ 关，8-12 条成语/关） | ✅ |
| 2.8 | 收藏系统 | 2.1 | 所有已完成成语自动收录，附带释义出处 | ✅ |
| 2.9 | 道具系统 | 2.6 | 实现设计文档 §5 道具系统（功能道具+装饰道具） | ✅ |
| 2.10 | 内购系统 | 2.9 | 实现设计文档 §5.3 内购设计（始终可访问商城） | ✅ |

**进度记录**
- 2026-07-04: 项目状态评审，确认 UI 层为当前核心缺失（3 个空目录 state/ widgets/ painters/，game_screen.dart 仅骨架）
- 2026-07-04: 完成科举仕途成长系统设计（20 级，指数经验曲线，螺旋难度模型）
- 2026-07-04: 完成成长系统实现（10 个任务，使用 Subagent-Driven Development）
  - Task 1: SpiralDifficulty 螺旋难度计算器
  - Task 2: GrowthManager 成长系统管理器（XP/等级/奖励/称号）
  - Task 3: Database Schema v2（玩家进度/收藏/关卡历史/装饰表）
  - Task 4: IntegratedGenerator 螺旋难度集成
  - Task 5: Player State（Riverpod 状态管理）
  - Task 6: Level Display Widget（等级徽章+经验进度条）
  - Task 7: Game Screen Integration（成长系统集成）
  - Task 8: Collection Screen（成语收藏界面）
  - Task 9: Shop Screen（商城界面，IAP 占位）
  - Task 10: Integration Tests（成长系统端到端测试）

### Phase 3：状态管理 + 数据持久化

| # | 任务 | 依赖 | 验收标准 | 状态 |
|---|------|------|----------|------|
| 3.1 | SQLite 数据库集成 | Phase 2 | 存储用户进度、关卡通关数据、设置偏好 | ✅ |
| 3.2 | 关卡数据导入 | 1.4, 3.1 | 将评分完成的成语和生成关卡批量导入 SQLite | 🔲 |
| 3.3 | 存档/读档 | 3.1 | 支持保存未完成关卡状态，重启后恢复 | 🔲 |

**进度记录**
- 2026-07-04: 确认 drift + sqlite3_flutter_libs 已在 pubspec.yaml 中配置，待 Phase 2 完成后接入
- 2026-07-04: 完成数据库 Schema v2（玩家进度/收藏/关卡历史/装饰表），Player State 已集成

### Phase 4：打磨与发布

| # | 任务 | 依赖 | 验收标准 | 状态 |
|---|------|------|----------|------|
| 4.1 | 性能优化 | Phase 2-3 | 关卡生成 < 100ms，UI 渲染 60fps | 🔲 |
| 4.2 | iOS 适配测试 | 4.1 | iPhone SE ~ Pro Max 屏幕适配，刘海屏/灵动岛安全区 | 🔲 |
| 4.3 | TestFlight 内测 | 4.2 | 至少 5 人完整通关 20 关无崩溃 | 🔲 |
| 4.4 | App Store 提交 | 4.3 | 通过审核上线 | 🔲 |

**进度记录**
- 2026-07-04: 确认 Flutter 3.44.2 + Dart 3.12.2 环境，iOS 为目标平台，最低版本 iOS 15.0

---

## 七、评分操作手册（已完成，留存参考）

### 评分参考锚点（重平衡后抽样，1-50 等量分布）

```
自言自语: 1,   东张西望: 1,   春暖花开: 1,   五颜六色: 1,   成群结队: 1
万紫千红: 1,   亡羊补牢: 1,   无缘无故: 1,   恋恋不舍: 1,   浩浩荡荡: 1
百里挑一: 11,  知己知彼: 11,  朝朝暮暮: 11,  力排众议: 21,  城下之盟: 21
推本溯源: 30,  泛应曲当: 31,  窃据要津: 31,  玉骨冰肌: 40,  进退迍邅: 41
杅穿皮蠹: 50,  林籁泉韵: 50,  簟纹如水: 50,  足音跫然: 50,  邯郸匍匐: 50
```

---

## 八、关键文件速查

| 用途 | 路径 |
|------|------|
| 最终评分 | `assets/data/scoring_progress.json` |
| 待评分数据 | `assets/data/to_score.json` |
| SQLite 数据库 | `assets/data/idiom_crossword.db`（variant_normalized_v2） |
| 旧版备份 | `assets/data/idiom_crossword_v1.db`（重平衡 v1）、`idiom_crossword_old.db`（原始 LLM 评分） |
| 数据库构建脚本 | `scripts/build_database.py` |
| 数据库验证脚本 | `scripts/verify_db.py` |
| 核心生成器 | `lib/src/engine/integrated_generator.dart` |
| 交叉图 | `lib/src/engine/crossing_graph.dart` |
| 布局引擎 | `lib/src/engine/layout_engine.dart` |
| 干扰字引擎 | `lib/src/engine/distractor_engine.dart` |
| 螺旋难度计算器 | `lib/src/engine/spiral_difficulty.dart` |
| 成长系统管理器 | `lib/src/data/growth_manager.dart` |
| 玩家状态管理 | `lib/src/state/player_state.dart` |
| 生成器测试 | `test/engine/integrated_gen_test.dart` |
| 螺旋难度测试 | `test/engine/spiral_difficulty_test.dart` |
| 成长系统测试 | `test/data/growth_manager_test.dart` |
| 集成测试 | `test/integration/growth_system_test.dart` |
| 评分分布 | `assets/data/score_distribution.md` |
| 最终校验 | `scripts/final_check.py` |
| 成长系统设计 | `docs/superpowers/specs/2026-07-04-growth-system-design.md` |
| 实现计划 | `docs/superpowers/plans/2026-07-04-growth-system-implementation.md` |

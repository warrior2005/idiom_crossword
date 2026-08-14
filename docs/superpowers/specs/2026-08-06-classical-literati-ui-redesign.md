# 古典文人风 UI 改造设计

> 依据 `design-style-prompt.md`（视觉契约）与 `idiom-crossword-prototype.html`（信息结构基准），将 Flutter 客户端整体改造为「宣纸 + 墨 + 朱砂」的古典文人风。
> 目标平台：iOS 竖屏手游。日期：2026-08-06。

---

## 1. 已确认决策

| # | 决策 |
|---|------|
| 1 | 导航重构为底部五 Tab（首页/关卡/收藏/商城/我的），子页面带返回箭头推入 |
| 2 | 覆盖全部 11 个视图（含新建「我的」「每日挑战」） |
| 3 | 新增功能（今日一读/每日挑战/我的等级条/商城钱包）全部接真实数据 |
| 4 | 展示字体用 iOS 系统宋体（`Songti SC`），不内嵌 Noto 字体 |
| 5 | 图标用 `flutter_svg` 内嵌设计稿 monoline SVG path |
| 6 | 游戏主界面保留常驻候选字盘交互，仅做视觉改造 |
| 7 | 关卡页筛选 chips 删除；主线区改左右滑动翻页；长尾区删除 |
| 8 | 「螺旋难度」「万关螺旋」等内部词不在 UI 展示，替换为「由浅入深」等 |
| 9 | 统计正确率通过新增填字统计功能（`totalFills` 字段）真实计算 |
| 10 | 游戏主界面保留「已完成成语条」；「一字提示」改名「提示」；不加线索卡 |

## 2. 设计 Token（`lib/src/ui/theme/app_colors.dart`）

| Dart 常量 | 值 | 用途 |
|---|---|---|
| `AppColors.bg` | `0xFFF3EDE1` | 页面底色（宣纸） |
| `AppColors.bgDeep` | `0xFFEAE0CC` | 交叉格/xing 格 |
| `AppColors.surface` | `0xFFFBF7EE` | 卡片面 |
| `AppColors.surface2` | `0xFFEFE7D4` | 灰底/交叉格加深 |
| `AppColors.fg` | `0xFF2B2922` | 正文（墨） |
| `AppColors.muted` | `0xFF857C68` | 次级文字（灰褐） |
| `AppColors.faint` | `0xFFB3A98E` | 弱文字/禁用 |
| `AppColors.border` | `0xFFE2D8BE` | 分隔线/卡边界 |
| `AppColors.borderStrong` | `0xFFC9BB9A` | 强边框 |
| `AppColors.accent` | `0xFFB33B27` | 唯一强调色（朱砂） |
| `AppColors.accentDeep` | `0xFF8F2C1B` | 下压阴影/深红文字 |
| `AppColors.accentSoft` | `0xFFE8CFC0` | 红系浅底（选中格/已通关） |
| `AppColors.accentPale` | `0xFFF4E3D8` | 红系更浅底（图标方块） |
| `AppColors.gold` | `0xFFB08A28` | 每日挑战/科举点缀（克制使用） |
| `AppColors.goldSoft` | `0xFFF0E3B8` | 金系浅底 |
| `AppColors.leaf` | `0xFF4E6E45` | 正确反馈（松青绿） |
| `AppColors.leafSoft` | `0xFFDDE6D4` | 绿系浅底 |

**纪律**：每屏可见 accent ≤ 2 处；衬线大字红色多用 `accentDeep` 保证对比；禁用态用 `surface2` + `faint`。

`main.dart` `ThemeData`：`ColorScheme.fromSeed(seedColor: accent)` + `useMaterial3`；`scaffoldBackgroundColor` = `bg`。

## 3. 字体（`lib/src/ui/theme/app_text.dart`）

- `const kSerif = 'Songti SC'`，回退 `STSong`。
- 展示样式：衬线、`height: 1.3–1.35`、`letterSpacing: 0`（CJK 禁止负字距）。
- `kicker`：11px、`muted`、字距 `letterSpacing: 2.8`。
- 正文 `height: 1.7`；大数字一律衬线 900。

## 4. 图标（`lib/src/ui/widgets/app_icons.dart` + `flutter_svg`）

从 `idiom-crossword-prototype.html` 提取 monoline SVG path，内嵌字符串，`AppIcon(name, size)` 渲染。清单：首页/关卡/收藏/商城/我的/返回/声音/灯泡/撤销/清空/奖杯/图表/滑杆/齿轮/列表/火焰/时钟/闪电/印章纹样等。全部 `strokeWidth 1.7–1.9`、无填充。
新增依赖 `flutter_svg`。

## 5. 通用组件（`lib/src/ui/widgets/`）

- `AppSeal` — 印章：朱砂实底 / 空心描边 / 灰底三态，圆角、竖排书写（1–2 字），用于「日/横/纵/通/士」。
- `XpTrack` — 经验/进度条：`surface2` 底 + 朱砂渐增满 + 文字「经验 N / 离某衔还差 M」。
- `PrimaryButton` — 主按钮（朱砂底 + `boxShadow 0 8px accentDeep` 下压、按压缩回）＋ `ghost`（surface 底朱砂字）＋ `small` 三变体。
- `AppCard` — surface 底、18px 圆角、细边框、轻投影。
- `SectionTitle`（含右侧链接）、`KickerText`、`BadgeSoft`（红/金/绿 pill）、`Chip`。

## 6. 导航架构（`lib/src/ui/screens/root_screen.dart` 新）

- `RootScreen`：`Scaffold` + `bottomNavigationBar`（5 Tab：首页/关卡/收藏/商城/我的；monoline SVG + 红点，选中朱砂）+ `IndexedStack` 保持各 Tab 状态。
- 子页面（成就/统计/设置/每日挑战）`Navigator.push` 进入，顶部返回箭头（`AppIcon.back`）。
- `main.dart` home 改为 `RootScreen`；原 `HomeScreen` 重构为首页 Tab，保留 `_startGame`/`_startDaily` 逻辑。

## 7. 页面改造

### 7.1 首页 Tab（重构 `home_screen.dart`）
- 头部：日期 + 「成语填字」（衬线大标题）+ 头像印章（随等级变化：士/官/卿/相/公/龙，→ 我的 Tab）。
- **科举仕途卡**：kicker「科举仕途」+ `Lv.X · 称号`（衬线 900 深红）+ `XpTrack`「经验 N / 离「X」还差 M」+ 背景水印 `Lv.X`（accent 10%）；Lv.∞ 满级时右侧显示「经验持续累计」。
- **每日挑战卡**：金 kicker「每日挑战 · 全服同题」+ 每日成语大字（衬线 900）+「第 N 期」暗金徽章 + 难度/成语数/时长/经验 + 「开始挑战」/「往期回顾」。
  - 数据：`FutureProvider` 按 `epochDay()` 确定性生成今日关卡（固定 12 条成语），读首条成语为每日成语、成语数、平均难度→难度文案；时长固定 2 分钟，经验固定 300。
- 「继续第 N 关」主按钮（复用 `_startGame`）。
- **书卷小径**：2 tile（选择关卡 → 关卡 Tab；成语收藏 → 收藏 Tab），描述文案替换内部词（如「由浅入深 · 循序渐进」）。
- **今日一读**卡：竖排成语（衬线 900）+ 出处（`derivation`）+ 释义。数据：按日期确定性取成语（新增 DB 方法 `getIdiomAtOffset`）。
- footnote「交叉推理 · 一字双关 · 循序渐进」。

### 7.2 关卡 Tab（重构 `level_select_screen.dart`）
- `h1 选择关卡` + kicker「由浅入深 · 每关按等级分段 8–12 条成语」。
- 每日挑战置顶卡：朱砂「日」印章 + 标题 + 「挑战」badge；今日已完成时整卡隐藏。
- **主线区**：`PageView` 左右滑动翻页，每页 24 关（4 列 × 6 行，固定页高），页码指示（如「第 25-48 关」），最多只能向右滑动到当前关卡所在页。单元格三态：
  - 已完成：`accentSoft` 底 + 旋转 6° 红「通」角标；
  - 当前关：朱砂底白字 + 投影；
  - 未解锁：`surface2` 淡灰。
- 无长尾区、无筛选 chips。

### 7.3 收藏 Tab（重构 `collection_screen.dart`）
- 搜索框改设计样式（surface 底 + 圆角 + 放大镜）。
- 计数行「共 N 则」+「本周新增」松绿徽章（数据：`getCollectionWithDetails` 时间戳统计本周新增）。
- `col-card`：左衬线大字（24px 900）＋ 拼音（`pinyin`，小字距）/释义（13px 行高 1.7）/出处（`derivation`）。
- 保留搜索/分页/空态逻辑与文案。

### 7.4 商城 Tab（重构 `shop_screen.dart`）
- 去掉双 Tab，改单列滚动分区：
- 标题旁「积分说明」入口：弹窗说明积分累计规则（激励广告完成 +3/次、插页式激励广告完成 +2、横幅广告 1 分钟 +1 且每日上限 120）。
- **积分卡**：展示当前积分 + 「赚取积分」激励广告按钮（视频图标）。点击后观看激励广告 +3 积分；广告完成后进入冷却倒计时（前 10 次 1 分钟、之后 2 分钟，每天上限 100 次），冷却期按钮显示剩余时间并禁用。
- **钱包**：提示卡 / 复活卡 小卡，读 `player.functionalItems`。
- **功能道具**：提示卡×1 / 复活卡×1 / 备考礼盒（提示×3 + 复活×1）pack 卡（图标方块 + 名称 + 描述 + 积分价格 + 购买）→ 扣除积分后增加玩家库存，积分不足提示；积分定价初值见成长系统设计文档 5.4。
- **装饰藏品**：网格皮肤列表（预览 + 名称 + 状态），分为「等级皮肤」与「广告兑换」两组，按真实逻辑锁定：
  - 等级皮肤：达到对应等级获得升级奖励后解锁（竹简 Lv.3 / 宣纸 Lv.7 / 青花 Lv.11 / 金箔 Lv.15 / 九五至尊 Lv.19），未解锁时点击提示解锁等级；
  - 广告兑换皮肤：按各自积分价格购买后解锁（秋香 1000 / 墨玉 2000 / 朱砂 2500 / 黛蓝 3000 / 藕荷 4000 / 绛紫 5000），已拥有点击直接切换，立即作用于游戏网格。
- **头像框 / 称号特效**：头像框分「等级奖励」与「积分购买」（东坡巾 1000 / 翼善冠 5000）；等级奖励为四方平定巾 Lv.2 / 乌纱帽 Lv.5 / 獬豸冠 Lv.13 / 忠靖冠 Lv.18 / 天子冕冠 Lv.21；称号特效为金榜题名 Lv.9 / 天子门生 Lv.17，已拥有可点击切换；头像框作用于首页/我的印章，特效作用于科举等级标题。
- 页面底部为横幅广告（`BannerAdView`），同一时刻仅当前可见 Tab 累计横幅观看积分。
- footnote「广告与积分不影响关卡难度与成语选择」。

选择关卡页与收藏页底部同样接入 `BannerAdView`；每关胜利结算弹框前有 40% 概率提供插页式激励广告，展示前明确说明 +2 积分奖励并允许跳过，只有达到奖励条件才发积分。

首页每日挑战卡：未达 Lv.3 时两个按钮合并为「到达Lv.3·廪生后开启」提示；关卡页置顶卡同步显示「Lv.3 开启」。

### 7.5 我的 Tab（新建 `mine_screen.dart`）
- `h1 我的`。
- **头像卡**：黑底金字印章方块（随等级变化：士/官/卿/相/公/龙）+ `Lv.X · 称号`（衬线深红）+「已获 N 关 · X 经验」+「再通关 M 关，晋升「X」」。
- **科举等级条**：横向滚动，最多 21 级（童生→位极人臣→Lv.∞ 真龙天子，`GrowthManager` 数据）。Lv∞ 前一个节点不是 Lv20 时插入「···」省略号。三态：
  - 已完成：`accentSoft` 底（不显示「通」角标）；
  - 当前级：朱砂底白字 +「当前」角标；
  - 未解锁：surface 底。
- **学问一览**：4 stat 卡（累计通关/成语收藏/最长连胜/平均用时），读 `statsProvider`。
- **更多** menu 行：成就/统计/设置（图标方块 + 标题 + hint + ›）。

### 7.6 成就（重构 `achievements_screen.dart`）
- hero 卡：解锁数衬线大字 + 进度条 + 下一条提示文案。
- 分组列表（按 `AchievementId` 类别分组：通关/连击/无提示/收藏/速通/每日/经验）。
- 每行：左侧「通」实底印章（已解锁）/ 虚线灰印章（未解锁）+ 名称/描述 + 进度。

### 7.7 统计（重构 `stats_screen.dart`）
- **正确率环形图**（CustomPaint，accent 描边）：正确率 = (totalFills − errorsMade) / totalFills；无数据（老记录）显示「—」+「通关后生成正确率」。
- 连胜卡（金）+ 明细行（累计通关/累计经验/平均用时/失误次数/使用提示/成语收藏，全部读 `getLevelHistory`）。

### 7.8 自定义（删除）
- 删除自定义关卡功能与页面（`custom_level_screen.dart`）。
- 连带移除：首页与「我的」页的自定义关卡入口；`GameScreen` 的 `isCustom` 参数与 `_showCustomCompleteDialog`；相关测试用例同步清理。

### 7.9 设置（重构 `settings_screen.dart`）
- 分组行：
  - **通用**：音效（接 `soundEnabledKey`）/ 触感反馈（新增持久化开关，键 `haptic_enabled`，接入 `HapticFeedback` 判定）。
  - **偏好**：显示拼音 / 每日提醒 ——本轮仅持久化开关状态（新增 settings 键 `show_pinyin`、`daily_reminder`），不引入通知调度与网格拼音渲染等行为变更，避免范围膨胀。
  - **关于**：当前版本（从 `pubspec`）/ 用户协议与隐私（toast 占位）。

### 7.10 每日挑战页（`daily_review_screen.dart`）
- 标题为「每日挑战」；quiz-hero：暖色渐变底 + 朱砂「日」印章 + 第 N 期 · 每日成语 + 完成态。
- 今日已完成时小字显示「全服同题 · 已完成 · 明日刷新」。
- 今日成语竖排卡（成语 + 释义）——**不展示「全服平均时间」等外部数据**。
- 历期回顾：从 `getLevelHistory` 取 `levelNumber >= dailyLevelOffset` 记录，解码 `levelJson` 得成语/释义列表；每页 10 条，支持上一页/下一页翻页。
- 页面底部固定「重玩今日挑战」按钮（已通关时带 `noReward`，不再获得经验）和「次日 0 点刷新」。

### 7.11 游戏主界面（重构 `game_screen.dart`）
- **顶栏**：返回按钮 + `第 N 关`（衬线 900）+ 声音开关（无「主线/每日挑战」徽章）。
- **进度条**：`本关进度 N/8 字`（衬线红字）+ `XpTrack`。
- **状态行**：候选字盘上方居中显示「生命值：X」；每日挑战额外显示「倒计时：MM:SS」。
- **网格**（改 `GridPainter` 配色）：given（surface2 + 右上朱砂角点）/ 交叉格（加深 10%）/ blank（透明）/ focus（朱红描边 + 外光晕）/ filled（accentPale 底 + accent 描边 + 深红字）/ wrong（朱砂底白字 + shake）/ correct（leafSoft 底 leaf 字）。
- 网格配色读取当前 `activeGridSkin` 主题（宣纸/竹简/青花/金箔/九五至尊）。
- **已完成成语条**（保留现有功能，样式对齐设计）：surface 卡左右撑满，成语 tag 横向滚动，释义超 2 行时纵向滚动。
- **候选字盘**：保留常驻 3×10 交互，改设计样式；单元格与字号比旧版略大，小屏用 `FittedBox` 等比缩放。
- **工具栏**：「提示」（右上角角标显示剩余提示卡，不撑高按钮）/ 撤销 / 清空，按钮可点击区域 88×64。
- **失败机制**：初始生命值 3，填错扣 1，归零失败；每日挑战额外 2 分钟倒计时，时间耗尽同样失败。失败弹框包含「复活(剩余 X)」（无卡时弹出购买框）/「重玩本关」/「返回主页」；每日挑战重玩不获得经验。
- 不加线索卡、不加候选标题、不加「为 X 字选字」。

### 7.12 过关窗（重做 4 个完成对话框）
统一为 `win-card` 母题：旋转 -4° 朱砂印章（86px）+ 标题 + 副标题 + `获得经验 +N` + 本关成语释义列表 + 按钮组（下一关 / 学习本关成语 / 返回主页）。升级奖励/通关/重玩/失败共用该组件。
- 过关弹窗只展示本局填错过的成语（最多 3 个），没填错过则不展示；成语名用朱砂边框强调，后接中文冒号与释义。

## 8. 数据变更

### 8.1 `LevelHistory.totalFills`（schema v7 → v8）
- `database.dart`：`LevelHistory` 加 `IntColumn get totalFills => integer().nullable()();`。
- 当时 `currentSchemaVersion` 为 8，现已演进到 9；迁移含 `if (from < 8)` 添加 `totalFills`。
- 老数据该列为 NULL → 正确率显示「—」占位。
- `addLevelHistory` 签名加 `totalFills` 参数。

### 8.2 跨关卡连胜（schema v8 → v9）
- `PlayerProgressTable` 新增 `currentCorrectStreak` / `bestCorrectStreak` 两列。
- `currentSchemaVersion` 9；`onUpgrade` 加 `if (from < 9)` 迁移。
- 最长连胜按“连续答对字数、跨关卡累计”统计。

### 8.3 游戏内统计
- 每次玩家点击候选字（`_onCandidateTap`，无论正误，凡落字即计一次尝试）`totalFills++`；提示填入（`_showHint`/`_applyAnswer`）不计。
- 正确次数 = `totalFills − errorsMade`（`errorsMade` 为错误尝试数）。
- 断点续玩存档 codec（`SavedGameState`）加 `totalFills` / `lives` / `remainingSeconds` / `revived` 字段，恢复/保存同步。
- 达成 `_onLevelComplete` 时写入 `addLevelHistory`。

### 8.4 每日一读
- `AppDatabase` 新增 `getIdiomAtOffset(int offset)`：按 id 偏移取一条成语（`word/pinyin/explanation/derivation`）。

## 9. 文案

- 删除内部词：「螺旋难度」「万关螺旋」。
- 替换：「由浅入深」；footnote「交叉推理 · 一字双关 · 循序渐进」。
- 「一字提示」→「提示」。
- 文言基调沿用：「科举仕途」「书卷小径」「今日一读」。

## 10. 测试策略

- 同步更新现有 `test/ui/screens_test.dart`、`test/ui/game_flow_test.dart` 中受结构/文案影响的断言（空态文案保留则不动）。
- 新增测试：
  - 关卡页 PageView 翻页。
  - 我的页等级条三态渲染。
  - 首页每日卡（mock 每日生成）与今日一读。
  - 每日挑战页（历史含每日挑战时渲染历期、分页与重玩）。
  - `totalFills` 迁移与正确率计算（新增/老数据 NULL）。
- 验证命令：`flutter analyze` + `flutter test`。

## 11. 实现验收清单

- [ ] 全案仅一个强调色 accent，每屏可见 ≤2 次。
- [ ] 中文大标题行高 ≥1.3；CJK 无负字距；大数字衬线。
- [ ] 底部五 Tab 完整导航，无横向滚动溢出。
- [ ] 视觉母题「印章」贯穿通关/完成/成就/每日达成态。
- [ ] 过关窗统一 win-card 母题。
- [ ] `flutter analyze` 无新增告警；`flutter test` 全绿。

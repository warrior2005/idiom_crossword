# Game Center 配置

> Game Center ID 上线后不可修改。以下 ID 必须与代码完全一致。

## iCloud 卸载恢复

GameKit Saved Games 使用 iCloud Documents 保存用户存档。Apple Developer
后台需要为 App ID `com.sunnywarrior.idiomCrossword` 开启 iCloud，并创建或选择
容器 `iCloud.com.sunnywarrior.idiomCrossword`。Xcode 的 Runner target 需同时启用：

- Game Center
- iCloud → iCloud Documents

真机验证时，设备必须登录 Game Center 和 iCloud，并开启 iCloud Drive。测试流程：

1. 完成关卡或修改商城资产，等待 20 秒或将 App 切到后台。
2. 删除 App 后重新安装。
3. 使用同一 Game Center/iCloud 账号启动。
4. 确认 Lv、经验、积分、提示卡、复活卡、关卡、收藏和商城解锁状态恢复。

云存档名固定为 `player_snapshot_v1`。该版本仅用于卸载恢复，不支持两台设备
同时游玩时的存档合并。

## 排行榜

| 名称 | ID | 类型 | 排序 | 提交方式 | 分数含义 |
|---|---|---|---|---|---|
| 天下英雄榜 | `high_score` | 经典 | 从高到低 | 最佳成绩 | 玩家累计总经验 |
| 每周英雄榜 | `weekly_score` | 周期性，每 7 天 | 从高到低 | 最佳成绩 | 当前自然周累计经验 |

“每周英雄榜”的周期开始时间设置为周一 00:00（中国标准时间），周期 7 天。分数格式使用整数，后缀可填写“经验”。两榜的分数下限建议设为 0，上限建议使用 App Store Connect 允许的最大整数。

## 成就

所有成就均为一次性、非隐藏成就，总计 1000 点。

| 名称   | ID                                                         | 解锁条件          |  点数 | 获得成就前的描述        | 获得成就后的描述    |
| ---- | ---------------------------------------------------------- | ------------- | --: | --------------- | ----------- |
| 初露锋芒 | `com.sunnywarrior.idiomcrossword.achievement.first_level`  | 累计通关 1 关      |  10 | 完成你的第一关         | 首关告捷 初露锋芒   |
| 小试牛刀 | `com.sunnywarrior.idiomcrossword.achievement.level_10`     | 累计通关 10 关     |  10 | 累计通关 10 关       | 十关已破 小试牛刀   |
| 渐入佳境 | `com.sunnywarrior.idiomcrossword.achievement.level_50`     | 累计通关 50 关     |  20 | 累计通关 50 关       | 五十关过 渐入佳境   |
| 百尺竿头 | `com.sunnywarrior.idiomcrossword.achievement.level_100`    | 累计通关 100 关    |  30 | 累计通关 100 关      | 百关已成 百尺竿头   |
| 熟能生巧 | `com.sunnywarrior.idiomcrossword.achievement.level_500`    | 累计通关 500 关    |  40 | 累计通关 500 关      | 五百关成 熟能生巧   |
| 千锤百炼 | `com.sunnywarrior.idiomcrossword.achievement.level_1000`   | 累计通关 1000 关   |  50 | 累计通关 1000 关     | 千关历练 千锤百炼   |
| 炉火纯青 | `com.sunnywarrior.idiomcrossword.achievement.level_5000`   | 累计通关 5000 关   |  80 | 累计通关 5000 关     | 五千关过 炉火纯青   |
| 登峰造极 | `com.sunnywarrior.idiomcrossword.achievement.level_10000`  | 累计通关 10000 关  | 100 | 累计通关 10000 关    | 万关功成 登峰造极   |
| 集腋成裘 | `com.sunnywarrior.idiomcrossword.achievement.collect_50`   | 收集 50 个成语     |  20 | 收集 50 个成语       | 点滴积累 集腋成裘   |
| 博闻强识 | `com.sunnywarrior.idiomcrossword.achievement.collect_200`  | 收集 200 个成语    |  40 | 收集 200 个成语      | 两百成语 博闻强识   |
| 汗牛充栋 | `com.sunnywarrior.idiomcrossword.achievement.collect_1000` | 收集 1000 个成语   |  80 | 收集 1000 个成语     | 千条入藏 汗牛充栋   |
| 一气呵成 | `com.sunnywarrior.idiomcrossword.achievement.streak_10`    | 连续答对 10 个字    |  20 | 连续答对 10 个字      | 十字连中 一气呵成   |
| 势如破竹 | `com.sunnywarrior.idiomcrossword.achievement.streak_30`    | 连续答对 30 个字    |  40 | 连续答对 30 个字      | 三十连中 势如破竹   |
| 百发百中 | `com.sunnywarrior.idiomcrossword.achievement.streak_100`   | 连续答对 100 个字   |  80 | 连续答对 100 个字     | 百字连中 百发百中   |
| 自力更生 | `com.sunnywarrior.idiomcrossword.achievement.no_hint_10`   | 累计 10 次无提示通关  |  30 | 累计 10 次不使用提示通关  | 十次独力通关 自力更生 |
| 独当一面 | `com.sunnywarrior.idiomcrossword.achievement.no_hint_100`  | 累计 100 次无提示通关 |  60 | 累计 100 次不使用提示通关 | 百次独力通关 独当一面 |
| 精益求精 | `com.sunnywarrior.idiomcrossword.achievement.flawless_10`  | 累计 10 次零失误通关  |  30 | 累计 10 次零失误通关    | 十次完美通关 精益求精 |
| 无懈可击 | `com.sunnywarrior.idiomcrossword.achievement.flawless_100` | 累计 100 次零失误通关 |  60 | 累计 100 次零失误通关   | 百次完美通关 无懈可击 |
| 闻鸡起舞 | `com.sunnywarrior.idiomcrossword.achievement.daily_1`      | 完成 1 次每日挑战    |  10 | 完成 1 次每日挑战      | 每日一试 闻鸡起舞   |
| 七步成诗 | `com.sunnywarrior.idiomcrossword.achievement.daily_7`      | 累计完成 7 次每日挑战  |  30 | 累计完成 7 次每日挑战    | 七次挑战 七步成诗   |
| 持之以恒 | `com.sunnywarrior.idiomcrossword.achievement.daily_30`     | 累计完成 30 次每日挑战 |  50 | 累计完成 30 次每日挑战   | 三十次挑战 持之以恒  |
| 积少成多 | `com.sunnywarrior.idiomcrossword.achievement.xp_10000`     | 累计获得 1 万经验    |  20 | 累计获得 1 万经验      | 万点经验 积少成多   |
| 厚积薄发 | `com.sunnywarrior.idiomcrossword.achievement.xp_100000`    | 累计获得 10 万经验   |  30 | 累计获得 10 万经验     | 十万积淀 厚积薄发   |
| 功成名就 | `com.sunnywarrior.idiomcrossword.achievement.xp_1000000`   | 累计获得 100 万经验  |  60 | 累计获得 100 万经验    | 百万经验 功成名就   |

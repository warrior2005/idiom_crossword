# Game Center 配置

> Game Center ID 上线后不可修改。以下 ID 必须与代码完全一致。

## 排行榜

| 名称 | ID | 类型 | 排序 | 提交方式 | 分数含义 |
|---|---|---|---|---|---|
| 天下英雄榜 | `high_score` | 经典 | 从高到低 | 最佳成绩 | 玩家累计总经验 |
| 每周英雄榜 | `weekly_score` | 周期性，每 7 天 | 从高到低 | 最佳成绩 | 当前自然周累计经验 |

“每周英雄榜”的周期开始时间设置为周一 00:00（中国标准时间），周期 7 天。分数格式使用整数，后缀可填写“经验”。两榜的分数下限建议设为 0，上限建议使用 App Store Connect 允许的最大整数。

## 成就

所有成就均为一次性、非隐藏成就，总计 1000 点。

| 名称 | ID | 解锁条件 | 点数 |
|---|---|---|---:|
| 初露锋芒 | `com.sunnywarrior.idiomcrossword.achievement.first_level` | 累计通关 1 关 | 10 |
| 小试牛刀 | `com.sunnywarrior.idiomcrossword.achievement.level_10` | 累计通关 10 关 | 10 |
| 渐入佳境 | `com.sunnywarrior.idiomcrossword.achievement.level_50` | 累计通关 50 关 | 20 |
| 百尺竿头 | `com.sunnywarrior.idiomcrossword.achievement.level_100` | 累计通关 100 关 | 30 |
| 熟能生巧 | `com.sunnywarrior.idiomcrossword.achievement.level_500` | 累计通关 500 关 | 40 |
| 千锤百炼 | `com.sunnywarrior.idiomcrossword.achievement.level_1000` | 累计通关 1000 关 | 50 |
| 炉火纯青 | `com.sunnywarrior.idiomcrossword.achievement.level_5000` | 累计通关 5000 关 | 80 |
| 登峰造极 | `com.sunnywarrior.idiomcrossword.achievement.level_10000` | 累计通关 10000 关 | 100 |
| 集腋成裘 | `com.sunnywarrior.idiomcrossword.achievement.collect_50` | 收藏 50 个成语 | 20 |
| 博闻强识 | `com.sunnywarrior.idiomcrossword.achievement.collect_200` | 收藏 200 个成语 | 40 |
| 汗牛充栋 | `com.sunnywarrior.idiomcrossword.achievement.collect_1000` | 收藏 1000 个成语 | 80 |
| 一气呵成 | `com.sunnywarrior.idiomcrossword.achievement.streak_10` | 连续答对 10 个字 | 20 |
| 势如破竹 | `com.sunnywarrior.idiomcrossword.achievement.streak_30` | 连续答对 30 个字 | 40 |
| 百发百中 | `com.sunnywarrior.idiomcrossword.achievement.streak_100` | 连续答对 100 个字 | 80 |
| 自力更生 | `com.sunnywarrior.idiomcrossword.achievement.no_hint_10` | 累计 10 次无提示通关 | 30 |
| 独当一面 | `com.sunnywarrior.idiomcrossword.achievement.no_hint_100` | 累计 100 次无提示通关 | 60 |
| 精益求精 | `com.sunnywarrior.idiomcrossword.achievement.flawless_10` | 累计 10 次零失误通关 | 30 |
| 无懈可击 | `com.sunnywarrior.idiomcrossword.achievement.flawless_100` | 累计 100 次零失误通关 | 60 |
| 闻鸡起舞 | `com.sunnywarrior.idiomcrossword.achievement.daily_1` | 完成 1 次每日挑战 | 10 |
| 七步成诗 | `com.sunnywarrior.idiomcrossword.achievement.daily_7` | 累计完成 7 次每日挑战 | 30 |
| 持之以恒 | `com.sunnywarrior.idiomcrossword.achievement.daily_30` | 累计完成 30 次每日挑战 | 50 |
| 积少成多 | `com.sunnywarrior.idiomcrossword.achievement.xp_10000` | 累计获得 1 万经验 | 20 |
| 厚积薄发 | `com.sunnywarrior.idiomcrossword.achievement.xp_100000` | 累计获得 10 万经验 | 30 |
| 功成名就 | `com.sunnywarrior.idiomcrossword.achievement.xp_1000000` | 累计获得 100 万经验 | 60 |

# 成语难度评分分布（variant_normalized_v2）

> 数据源: idiom_crossword.db | 总数: 29,502 条 | 方法: variant_normalized_v2

## 处理方法

1. monotonic_quantile_v1：原始 LLM 分 → 桶内特征重排 → 全局等量 1-50 映射
2. variant_normalized_v2：基于 `idiom_reversible_pair` 表，倒装/异形组内统一语义难度 + 有限形态惩罚

## 最终分布

- 每档平均: 590 条
- 每档范围: 520 - 622 条
- 标准差: 19.19

## 新增字段

| 字段 | 含义 |
|------|------|
| difficulty | 最终 1-50 游戏难度 |
| difficulty_rebalanced_v1 | 上一版重平衡难度 |
| variant_group_id | 倒装组 ID（0=非倒装） |
| canonical_word | 组内标准形式 |
| is_canonical | 是否标准形式 |
| semantic_difficulty | 语义难度 |
| surface_penalty | 倒装/罕见形式惩罚（0-4） |
| surface_difficulty_score | 语义 + 形态 |
| difficulty_base_before_variant_penalty | 加惩罚前的基础分 |

## 倒装对分差

| 阶段 | 平均分差 | 中位分差 | 最大分差 |
|------|:---:|:---:|:---:|
| 处理前（v1）| 9.21 | 7 | 42 |
| 处理后（v2）| 1.84 | 2 | **4** |

## 关键倒装对示例

| 标准形式 | 倒装形式 | 标准分 | 倒装分 | 分差 |
|------|------|:---:|:---:|:---:|
| 浑浑噩噩 | 噩噩浑浑 | 6 | 10 | 4 |
| 幸灾乐祸 | 乐祸幸灾 | 1 | 5 | 4 |
| 蛛丝马迹 | 马迹蛛丝 | 5 | 9 | 4 |
| 明枪暗箭 | 暗箭明枪 | 7 | 11 | 4 |

## 历史版本

| 文件 | 说明 |
|------|------|
| idiom_crossword_old.db | 原始 LLM 评分（离散分布） |
| idiom_crossword_v1.db | 重平衡 v1（等量分布，倒装未处理） |
| idiom_crossword.db | **当前：v2（倒装一致性 + 近似均匀）** |

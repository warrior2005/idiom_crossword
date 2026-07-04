/// 成语数据库设计 v2
/// 
/// 设计目标：
///   1. 当前填字游戏（交叉查询、难度分级、倒装支持）
///   2. 未来可扩展为接龙游戏（首尾字匹配）、成语消消乐（组词匹配）等
///   3. 数据治理：每条成语的元数据完整可追溯
///   4. 成长系统（玩家进度、收藏、关卡历史、装饰）
///
/// 设计原则：
///   - 宽表为主，多表索引辅助。SQLite 的 JOIN 成本偏高，
///     高频查询字段冗余到主表，低频详情字段独立

// ============================================================
// 主表：成语核心表
// ============================================================
/*
  TABLE idiom (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    word            TEXT    NOT NULL UNIQUE,    -- 成语原文，如"画蛇添足"
    pinyin          TEXT    NOT NULL,           -- 拼音，如"huà shé tiān zú"
    pinyin_abbr     TEXT    NOT NULL,           -- 拼音首字母缩写，如"hstz"
    explanation     TEXT    NOT NULL,           -- 释义
    derivation      TEXT,                       -- 出处原文
    example         TEXT,                       -- 例句
    first_char      TEXT    NOT NULL,           -- 首字（冗余，加速查询）
    last_char       TEXT    NOT NULL,           -- 末字（冗余，加速查询）
    -- === Warrior 提到的字段 ===
    difficulty      INTEGER NOT NULL DEFAULT 25, -- 游戏难度 1-50（等量均匀分布，每档 ~590 条）
    reversible      INTEGER NOT NULL DEFAULT 0, -- 是否允许倒装（ABCD ↔ CDAB）

    -- === 难度元数据 ===
    difficulty_original             INTEGER,   -- 原始 LLM 难度分
    difficulty_rank                 INTEGER,   -- 全局难度排名（1=最简单）
    difficulty_percentile           REAL,      -- 全局难度百分位（0-1）
    difficulty_method               TEXT,      -- 处理方法：variant_normalized_v2
    -- === 倒装/异形组（variant_normalized_v2）===
    variant_group_id                INTEGER,   -- 倒装组 ID（0=非倒装组）
    canonical_word                  TEXT,      -- 组内标准形式
    is_canonical                    INTEGER,   -- 是否标准形式（0/1）
    semantic_difficulty             INTEGER,   -- 语义难度
    surface_penalty                 REAL,      -- 倒装/罕见形式惩罚（0-4）
    surface_difficulty_score        INTEGER,   -- semantic_difficulty + surface_penalty
    difficulty_base_before_variant_penalty INTEGER, -- 加惩罚前的基础难度
    difficulty_rebalanced_v1        INTEGER,   -- 上一版重平衡难度备份

    -- === 扩展字段 ===
    emotion         TEXT,                         -- 情感色彩：褒/贬/中
    category        TEXT,                         -- 语义类别：哲理/军事/自然/情感/...
    era             TEXT,                         -- 年代：先秦/汉/唐/宋/明/清/近现代
    source_type     TEXT,                         -- 来源类型：史书/寓言/诗词/佛经/口语
    abbr            TEXT,                         -- 原始 JSON 中的 abbreviation，如"hstz"
    
    created_at      TEXT    NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT    NOT NULL DEFAULT (datetime('now'))
  );
*/

// ============================================================
// 倒排索引表：字 → 成语（高频查询）
// ============================================================
/*
  TABLE idiom_char_index (
    idiom_id   INTEGER NOT NULL REFERENCES idiom(id) ON DELETE CASCADE,
    char       TEXT    NOT NULL,    -- 单个汉字
    position   INTEGER NOT NULL,   -- 该字在成语中的位置（0-based）
    is_first   INTEGER NOT NULL DEFAULT 0,  -- 是否首字
    is_last    INTEGER NOT NULL DEFAULT 0,  -- 是否末字
    PRIMARY KEY (idiom_id, char, position)
  );
  -- 索引
  CREATE INDEX idx_ici_char ON idiom_char_index(char);
  CREATE INDEX idx_ici_char_pos ON idiom_char_index(char, position);
  CREATE INDEX idx_ici_first ON idiom_char_index(char) WHERE is_first = 1;
  CREATE INDEX idx_ici_last ON idiom_char_index(char) WHERE is_last = 1;
  
  -- 说明：is_first / is_last 的冗余让"接龙"类查询直接走索引，
  -- 不用在运行时算 position = 0 或 position = word.length - 1
*/

// ============================================================
// 倒装映射表（ABCD ↔ CDAB）
// ============================================================
/*
  Warrior 提的这个需求非常有意思。倒装不是简单的字符串反转，
  而是语序颠倒后仍然成立的成语对。典型如：
    "千山万水" ↔ "万水千山"    (AABB ↔ BBAA)
    "海角天涯" ↔ "天涯海角"    (ABAB 式倒装)
    "博览群书" ↔ "群书博览"    (谓宾倒装)
  
  这个表记录"互逆"关系，使得填字游戏中两个方向都能接受。
*/
/*
  TABLE idiom_reversible_pair (
    idiom_id_a  INTEGER NOT NULL REFERENCES idiom(id) ON DELETE CASCADE,
    idiom_id_b  INTEGER NOT NULL REFERENCES idiom(id) ON DELETE CASCADE,
    PRIMARY KEY (idiom_id_a, idiom_id_b)
  );
  -- 约束：idiom_id_a < idiom_id_b (保证每对只存一次)
*/

// ============================================================
// 形近字/音近字表（干扰字生成用）
// ============================================================
/*
  这个表是 UI 方向你提到的"干扰字要具有迷惑性"的数据基础。
  没有这个表，系统只能随机选字，用户一眼就能排除。
*/
/*
  TABLE char_similar (
    char       TEXT    NOT NULL,    -- 基准字
    similar    TEXT    NOT NULL,    -- 形近或音近字
    sim_type   TEXT    NOT NULL CHECK (sim_type IN ('shape', 'sound')),
    sim_score  REAL    NOT NULL DEFAULT 0.5, -- 相似度 0-1
    PRIMARY KEY (char, similar)
  );
  -- 数据来源：
  --   形近字：开源汉字笔画/部件数据库（如 Make Me a Hanzi）
  --   音近字：基于拼音编辑距离算法自动生成
*/

// ============================================================
// 扩展：近/反义词表（用于未来的消消乐、匹配类游戏）
// ============================================================
/*
  TABLE idiom_relation (
    idiom_id_a  INTEGER NOT NULL REFERENCES idiom(id) ON DELETE CASCADE,
    idiom_id_b  INTEGER NOT NULL REFERENCES idiom(id) ON DELETE CASCADE,
    rel_type    TEXT    NOT NULL CHECK (rel_type IN ('synonym', 'antonym', 'related')),
    PRIMARY KEY (idiom_id_a, idiom_id_b, rel_type)
  );
*/

// ============================================================
// 成长系统表
// ============================================================

// ============================================================
// 玩家进度表
// ============================================================
/*
  TABLE player_progress (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    level           INTEGER NOT NULL DEFAULT 1,
    total_xp        INTEGER NOT NULL DEFAULT 0,
    completed_levels INTEGER NOT NULL DEFAULT 0,
    hint_cards      INTEGER NOT NULL DEFAULT 0,
    revive_cards    INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now'))
  );
*/

// ============================================================
// 收藏成语表
// ============================================================
/*
  TABLE collection (
    idiom_id        INTEGER NOT NULL REFERENCES idiom(id) ON DELETE CASCADE,
    collected_at    TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (idiom_id)
  );
*/

// ============================================================
// 关卡通关记录表
// ============================================================
/*
  TABLE level_history (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    level_number    INTEGER NOT NULL,
    completed_at    TEXT NOT NULL DEFAULT (datetime('now')),
    xp_gained       INTEGER NOT NULL,
    idioms_used     TEXT NOT NULL,  -- JSON array of idiom IDs
    time_spent_ms   INTEGER,
    hints_used      INTEGER DEFAULT 0
  );
  CREATE INDEX idx_lh_level ON level_history(level_number);
*/

// ============================================================
// 装饰道具拥有状态表
// ============================================================
/*
  TABLE decoration (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    decoration_type TEXT NOT NULL,  -- 'grid_skin', 'avatar_frame', 'title_effect'
    decoration_id   TEXT NOT NULL,  -- 'bamboo', 'wusha', 'jinbang'
    owned_at        TEXT NOT NULL DEFAULT (datetime('now')),
    is_active       INTEGER DEFAULT 0,  -- 是否当前使用
    UNIQUE(decoration_type, decoration_id)
  );
*/

// ============================================================
// 数据导入脚本思路
// ============================================================
/// 从 chinese-xinhua/idiom.json 导入的流程：
/// 
/// 1. 读取 JSON，遍历每条：
///    - word → idiom.word
///    - pinyin → idiom.pinyin
///    - explanation → idiom.explanation
///    - derivation → idiom.derivation
///    - example → idiom.example
///    - abbreviation → idiom.abbr
/// 
/// 2. 自动计算：
///    - first_char = word[0]
///    - last_char = word[-1]
///    - pinyin_abbr = 从 pinyin 提取声母
///
/// 3. 导入难度评分：
///    - difficulty 从 assets/data/to_score.json 读取（已完成人工标注 → 重平衡，1-50 等量分布）
///    - difficulty_original / difficulty_rank 等元数据一并导入
/// 
/// 4. 逐字插入 idiom_char_index（每条成语 4 行）
///
/// 5. 数据已清洗：原始 idiom.json 30895 条 → 四字成语 29502 条（assets/data/to_score.json）



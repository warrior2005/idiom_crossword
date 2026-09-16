# 新增词条的词典内容补录

## 范围与结果

- 审核表标记“保留”的 221 条，以及同批已批准的“漫天风雪”，共 222 条。
- 释义：207 条采用在线词典、相关词条释义或原文译注；15 条保留原释义并列明。
- 出处：153 条有内容，69 条留空。
- 例句：158 条有内容，64 条留空。
- 查询日期：2026-09-15。找到可用条目即采用，不要求每条都有出处和例句。
- 部分文言短语使用词典相关字词的引证或原文译注；英文释义译为中文，繁体转为简体，长释义作简要整理。
- 出处记录文献及引文，不再写教材范围或审核说明；没有独立例句时，可采用含该词的文献原句。
- 来源仅用于追溯本次采用的内容，不声称均为最早出处。

## 未检得可用整词释义

以下条目已检索，保留原释义；能查到的出处、例句仍已补录：

人影绰绰、官迫民反、鸣钟击磬、长虹饮涧、固不待言、矫首昂视、虎啸猿啼、国弊民穷、烛幽索隐、文采藻饰、书生意气、恰恰相反、技经肯綮、以乱易整、威振四海。

## 数据与升级验证

- `data/textbook_additions.json` 保存拼音及三个正文内容字段；逐字段 URL 与处理备注保存在 [dictionary_enrichment_sources.json](dictionary_enrichment_sources.json)。
- 内容版本升至 6，构建脚本同步 JSON 与 SQLite；应用在升级已有数据库时更新这批词条的三个内容字段。
- 验证通过：数据源与数据库逐字段一致、3 项 Python 测试、29 项 Flutter 回归测试（新安装、已有内容版本升级、用户数据保留、关卡生成）。最后补录数据后，再次验证数据一致性及内容升级测试。
- 数据库前后对比：仅这 222 条的词典字段及全库内容版本发生变化；ID、拼音、难度、分档及其他表内容不变，SQLite 完整性检查通过。

## 逐条来源及缺失情况

| 词条 | 释义来源 | 出处来源 | 例句来源 | 说明 |
| --- | --- | --- | --- | --- |
| 大雪纷飞 | [来源](https://www.hanyuguoxue.com/chengyu/ci-681cae8c4) | [来源](https://www.hanyuguoxue.com/chengyu/ci-681cae8c4) | [来源](https://www.hanyuguoxue.com/chengyu/ci-681cae8c4) | — |
| 遮遮掩掩 | [来源](https://www.hanyuguoxue.com/chengyu/ci-a80ca5d1c) | [来源](https://www.hanyuguoxue.com/chengyu/ci-a80ca5d1c) | [来源](https://www.hanyuguoxue.com/chengyu/ci-a80ca5d1c) | — |
| 奔流不息 | [来源](https://www.hanyuguoxue.com/chengyu/ci-14571c7964) | 缺失，留空 | [来源](https://www.moedict.tw/uni/%E5%A5%94%E6%B5%81%E4%B8%8D%E6%81%AF) | — |
| 见善则迁 | [来源](https://www.hanyuguoxue.com/chengyu/ci-1fb6ac159) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1fb6ac159) | 缺失，留空 | — |
| 兵来将挡 | [来源](https://www.zgjizhu.com/bljdslty.html) | [来源](https://www.zgjizhu.com/bljdslty.html) | [来源](https://www.zgjizhu.com/bljdslty.html) | 词典收录完整说法“兵来将挡，水来土掩”。 |
| 眼见为实 | [来源](https://zdic.net/hans/耳聽為虛，眼見為實) | [来源](https://c.obsky.com/chengyu/ci-1406bf21db.html) | [来源](https://zdic.net/hans/耳聽為虛，眼見為實) | 词典收录完整说法“耳听为虚，眼见为实”，释义取相应分句。 |
| 耳听为虚 | [来源](https://zdic.net/hans/耳聽為虛，眼見為實) | [来源](https://c.obsky.com/chengyu/ci-1406bf21db.html) | [来源](https://zdic.net/hans/耳聽為虛，眼見為實) | 词典收录完整说法“耳听为虚，眼见为实”，释义取相应分句。 |
| 近墨者黑 | [来源](https://www.hanyuguoxue.com/chengyu/ci-80d9f0943) | 缺失，留空 | 缺失，留空 | — |
| 近朱者赤 | [来源](https://www.hanyuguoxue.com/chengyu/ci-18c90acbae) | [来源](https://www.hanyuguoxue.com/chengyu/ci-18c90acbae) | [来源](https://www.hanyuguoxue.com/chengyu/ci-18c90acbae) | — |
| 但愿如此 | [来源](https://www.hanyuguoxue.com/chengyu/ci-5671d79ba) | [来源](https://www.hanyuguoxue.com/chengyu/ci-5671d79ba) | [来源](https://www.hanyuguoxue.com/chengyu/ci-5671d79ba) | — |
| 惩恶扬善 | [来源](https://www.hao86.com/ciyu_view_9dfdcf43ac9dfdcf/) | 缺失，留空 | [来源](https://www.hao86.com/ciyu_view_9dfdcf43ac9dfdcf/) | — |
| 各显神通 | [来源](https://www.hanyuguoxue.com/chengyu/ci-9c9c8c630) | [来源](https://www.hanyuguoxue.com/chengyu/ci-9c9c8c630) | [来源](https://www.moedict.tw/uni/%E5%90%84%E9%A1%AF%E7%A5%9E%E9%80%9A) | — |
| 差之毫厘 | [来源](https://www.hanyuguoxue.com/cidian/ci-1751342a5) | 缺失，留空 | 缺失，留空 | — |
| 志存高远 | [来源](https://www.hanyuguoxue.com/chengyu/ci-1b858dfdeb) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1b858dfdeb) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1b858dfdeb) | — |
| 秉公执法 | [来源](https://zdic.net/hans/秉公) | 缺失，留空 | 缺失，留空 | 汉典“秉公”条以“秉公执法”为用例，释义据该条补足。 |
| 人烟稀少 | [来源](https://www.hanyuguoxue.com/chengyu/ci-6a1ed4310) | [来源](https://www.hanyuguoxue.com/chengyu/ci-6a1ed4310) | [来源](https://www.hanyuguoxue.com/chengyu/ci-6a1ed4310) | — |
| 膀大腰圆 | [来源](https://www.hanyuguoxue.com/chengyu/ci-15cb306e14) | [来源](https://www.hanyuguoxue.com/chengyu/ci-15cb306e14) | [来源](https://www.hanyuguoxue.com/chengyu/ci-15cb306e14) | — |
| 嫦娥奔月 | [来源](https://www.hanyuguoxue.com/chengyu/ci-39998ba6f) | [来源](https://www.hanyuguoxue.com/chengyu/ci-39998ba6f) | [来源](https://www.hanyuguoxue.com/chengyu/ci-39998ba6f) | — |
| 鲲鹏展翅 | [来源](https://www.hanyuguoxue.com/cidian/ci-288f3982a) | 缺失，留空 | [来源](https://www.moedict.tw/uni/%E9%AF%A4%E9%B5%AC%E5%B1%95%E7%BF%85) | — |
| 趁其不备 | [来源](https://www.hanyuguoxue.com/cidian/ci-197ef8fd7f) | 缺失，留空 | 缺失，留空 | — |
| 老老少少 | [来源](https://www.hanyuguoxue.com/chengyu/ci-fb1ea87ac) | [来源](https://www.hanyuguoxue.com/chengyu/ci-fb1ea87ac) | [来源](https://www.hanyuguoxue.com/chengyu/ci-fb1ea87ac) | — |
| 自胜者强 | [来源](https://www.hanyuguoxue.com/chengyu/ci-17625b05d3) | [来源](https://www.hanyuguoxue.com/chengyu/ci-17625b05d3) | [来源](https://www.hanyuguoxue.com/chengyu/ci-17625b05d3) | — |
| 人影绰绰 | 保留原释义 | 缺失，留空 | 缺失，留空 | 词典返回了“影”的释义，与整词不符。；未检得可用整词释义，保留原释义。 |
| 整整齐齐 | [来源](https://www.hanyuguoxue.com/chengyu/ci-e38e26de6) | [来源](https://www.hanyuguoxue.com/chengyu/ci-e38e26de6) | [来源](https://www.hanyuguoxue.com/chengyu/ci-e38e26de6) | — |
| 一泻汪洋 | [来源](https://www.hanyuguoxue.com/chengyu/ci-1e7691468) | [来源](https://zh.wikisource.org/wiki/%E5%B0%91%E5%B9%B4%E4%B8%AD%E5%9C%8B%E8%AA%AA) | [来源](https://zh.wikisource.org/wiki/%E5%B0%91%E5%B9%B4%E4%B8%AD%E5%9C%8B%E8%AA%AA) | — |
| 干将发硎 | [来源](https://www.dwhy.net/article-1001-1.html) | [来源](https://www.dwhy.net/article-1001-1.html) | [来源](https://www.dwhy.net/article-1001-1.html) | 未检得独立词典条目，采用对外汉语网释文。 |
| 有作其芒 | [来源](https://www.gushiwen.cn/mingju/juv_2bb00c57f2ba.aspx) | [来源](https://zh.wikisource.org/wiki/%E5%B0%91%E5%B9%B4%E4%B8%AD%E5%9C%8B%E8%AA%AA) | [来源](https://zh.wikisource.org/wiki/%E5%B0%91%E5%B9%B4%E4%B8%AD%E5%9C%8B%E8%AA%AA) | 依据《少年中国说》译注整理。 |
| 潜龙腾渊 | [来源](https://www.hanyuguoxue.com/cidian/ci-153b83db3) | [来源](https://zh.wikisource.org/wiki/%E5%B0%91%E5%B9%B4%E4%B8%AD%E5%9C%8B%E8%AA%AA) | [来源](https://zh.wikisource.org/wiki/%E5%B0%91%E5%B9%B4%E4%B8%AD%E5%9C%8B%E8%AA%AA) | — |
| 矞矞皇皇 | [来源](https://www.hanyuguoxue.com/cidian/ci-143e264590) | [来源](https://zh.wikisource.org/wiki/%E5%B0%91%E5%B9%B4%E4%B8%AD%E5%9C%8B%E8%AA%AA) | [来源](https://zh.wikisource.org/wiki/%E5%B0%91%E5%B9%B4%E4%B8%AD%E5%9C%8B%E8%AA%AA) | — |
| 鹰隼试翼 | [来源](https://www.gushiwen.cn/mingju/juv_2bb00c57f2ba.aspx) | [来源](https://zh.wikisource.org/wiki/%E5%B0%91%E5%B9%B4%E4%B8%AD%E5%9C%8B%E8%AA%AA) | [来源](https://zh.wikisource.org/wiki/%E5%B0%91%E5%B9%B4%E4%B8%AD%E5%9C%8B%E8%AA%AA) | 采用古文岛原文译注。 |
| 端端正正 | [来源](https://www.hanyuguoxue.com/chengyu/ci-101a9e1fe9) | [来源](https://www.hanyuguoxue.com/chengyu/ci-101a9e1fe9) | [来源](https://www.hanyuguoxue.com/chengyu/ci-101a9e1fe9) | — |
| 舐犊之情 | [来源](https://zdic.net/hans/%E8%88%90%E7%8A%8A%E4%B9%8B%E6%83%85) | [来源](https://zdic.net/hans/%E8%88%90%E7%8A%8A%E4%B9%8B%E6%83%85) | [来源](https://zdic.net/hans/%E8%88%90%E7%8A%8A%E4%B9%8B%E6%83%85) | — |
| 戒奢以俭 | [来源](https://www.hanyuguoxue.com/chengyu/ci-1555ccb4ed) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1555ccb4ed) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1555ccb4ed) | — |
| 学如不及 | [来源](https://www.hanyuguoxue.com/chengyu/ci-bee735376) | [来源](https://zh.wikisource.org/wiki/論語/全覽) | [来源](https://www.hanyuguoxue.com/chengyu/ci-bee735376) | — |
| 犹恐失之 | [来源](https://zdic.net/hans/学如不及，犹恐失之) | [来源](https://zh.wikisource.org/wiki/論語/全覽) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | 完整说法的后半句，按该分句整理释义。 |
| 终夜不寝 | [来源](https://www.zdic.net/hans/终夜) | [来源](https://www.zdic.net/hans/终夜) | [来源](https://www.zdic.net/hans/终夜) | 依据“终夜”条引证整理。 |
| 官迫民反 | 保留原释义 | 缺失，留空 | 缺失，留空 | 未检得可用整词释义，保留原释义。 |
| 统而言之 | [来源](https://www.hanyuguoxue.com/chengyu/ci-781416f90) | [来源](https://www.hanyuguoxue.com/chengyu/ci-781416f90) | [来源](https://www.hanyuguoxue.com/chengyu/ci-781416f90) | — |
| 田忌赛马 | [来源](https://www.omgchinese.com/dictionary/chinese/田忌赛马) | 缺失，留空 | 缺失，留空 | 据英汉词典英文释义译写。 |
| 山高月小 | [来源](https://www.hanyuguoxue.com/chengyu/ci-30ce10838) | [来源](https://www.hanyuguoxue.com/chengyu/ci-30ce10838) | [来源](https://www.hanyuguoxue.com/chengyu/ci-30ce10838) | — |
| 一饮而尽 | [来源](https://www.hanyuguoxue.com/chengyu/ci-19ce06eee4) | [来源](https://www.hanyuguoxue.com/chengyu/ci-19ce06eee4) | [来源](https://www.hanyuguoxue.com/chengyu/ci-19ce06eee4) | — |
| 日精月华 | [来源](https://www.hanyuguoxue.com/cidian/ci-9772c5ba) | 缺失，留空 | 缺失，留空 | — |
| 乜乜些些 | [来源](https://www.hanyuguoxue.com/cidian/ci-a363ef737) | 缺失，留空 | 缺失，留空 | — |
| 云腾致雨 | [来源](https://www.hanyuguoxue.com/cidian/ci-744fc2232) | [来源](https://zh.wikisource.org/wiki/%E5%8D%83%E5%AD%97%E6%96%87) | [来源](https://zh.wikisource.org/wiki/%E5%8D%83%E5%AD%97%E6%96%87) | — |
| 威名远扬 | [来源](https://www.hanyuguoxue.com/cidian/ci-132eacf075) | 缺失，留空 | 缺失，留空 | — |
| 移步换景 | [来源](https://www.hanyuguoxue.com/cidian/ci-504c600fa) | 缺失，留空 | 缺失，留空 | — |
| 左膀右臂 | [来源](https://www.hanyuguoxue.com/chengyu/ci-187059376e) | [来源](https://www.hanyuguoxue.com/chengyu/ci-187059376e) | [来源](https://www.hanyuguoxue.com/chengyu/ci-187059376e) | — |
| 片刻不离 | [来源](https://www.hanyuguoxue.com/cidian/ci-78d2551a7) | 缺失，留空 | 缺失，留空 | — |
| 一碧千里 | [来源](https://www.hanyuguoxue.com/chengyu/ci-5114f5bad) | 缺失，留空 | 缺失，留空 | — |
| 婉言谢绝 | [来源](https://www.hanyuguoxue.com/chengyu/ci-1a317041a7) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1a317041a7) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1a317041a7) | — |
| 鸣钟击磬 | 保留原释义 | 缺失，留空 | 缺失，留空 | 词典释义把演奏动作误写成器具。；未检得可用整词释义，保留原释义。 |
| 无边无涯 | [来源](https://www.hanyuguoxue.com/chengyu/ci-f1706cc40) | [来源](https://www.hanyuguoxue.com/chengyu/ci-f1706cc40) | [来源](https://www.hanyuguoxue.com/chengyu/ci-f1706cc40) | — |
| 朝花夕拾 | [来源](https://www.newton.com.tw/wiki/朝花夕拾/5946389) | [来源](https://www.newton.com.tw/wiki/朝花夕拾/5946389) | 缺失，留空 | 采用中文百科全书的成语解释条目。 |
| 无暇顾及 | [来源](https://www.hanyuguoxue.com/chengyu/ci-10c814bc95) | 缺失，留空 | [来源](https://www.hanyuguoxue.com/chengyu/ci-10c814bc95) | — |
| 春风拂面 | [来源](https://www.hanyuguoxue.com/cidian/ci-d546739ee) | 缺失，留空 | 缺失，留空 | — |
| 骄阳似火 | [来源](https://www.hanyuguoxue.com/chengyu/ci-60a7dd83a) | 缺失，留空 | [来源](https://www.hanyuguoxue.com/chengyu/ci-60a7dd83a) | — |
| 桃李满门 | [来源](https://www.hanyuguoxue.com/chengyu/ci-1e8542ffb3) | 缺失，留空 | 缺失，留空 | — |
| 秋风萧瑟 | [来源](https://www.hanyuguoxue.com/cidian/ci-1a3c70fe9d) | 缺失，留空 | 缺失，留空 | — |
| 人迹罕至 | [来源](https://www.hanyuguoxue.com/chengyu/ci-14d75e6bc5) | [来源](https://www.hanyuguoxue.com/chengyu/ci-14d75e6bc5) | [来源](https://www.hanyuguoxue.com/chengyu/ci-14d75e6bc5) | — |
| 潜龙勿用 | [来源](https://www.hanyuguoxue.com/chengyu/ci-d4c4fd2cd) | [来源](https://www.hanyuguoxue.com/chengyu/ci-d4c4fd2cd) | [来源](https://www.hanyuguoxue.com/chengyu/ci-d4c4fd2cd) | — |
| 历久弥新 | [来源](https://www.hanyuguoxue.com/cidian/ci-1281de133a) | 缺失，留空 | 缺失，留空 | — |
| 年与时驰 | [来源](https://dict.baidu.com/shici/detail?pid=ce7bcf07f57411e58fb0c8e0eb15ce01) | [来源](https://zh.wikisource.org/wiki/%E8%AA%A1%E5%AD%90%E6%9B%B8) | [来源](https://zh.wikisource.org/wiki/%E8%AA%A1%E5%AD%90%E6%9B%B8) | 采用原文译注。 |
| 层次分明 | [来源](https://www.hanyuguoxue.com/cidian/ci-155bb40619) | 缺失，留空 | 缺失，留空 | — |
| 兀兀穷年 | [来源](https://www.hanyuguoxue.com/chengyu/ci-868da1ca4) | [来源](https://www.hanyuguoxue.com/chengyu/ci-868da1ca4) | [来源](https://www.hanyuguoxue.com/chengyu/ci-868da1ca4) | — |
| 心会神凝 | [来源](https://www.hanyuguoxue.com/cidian/ci-5812f5107) | 缺失，留空 | 缺失，留空 | — |
| 群蚁排衙 | [来源](https://www.hanyuguoxue.com/cidian/ci-c4a06dd01) | 缺失，留空 | 缺失，留空 | — |
| 气度不凡 | [来源](https://www.hanyuguoxue.com/chengyu/ci-ec6b9d6c1) | [来源](https://www.hanyuguoxue.com/chengyu/ci-ec6b9d6c1) | [来源](https://www.hanyuguoxue.com/chengyu/ci-ec6b9d6c1) | — |
| 神秘莫测 | [来源](https://www.hanyuguoxue.com/chengyu/ci-175ef6ef19) | [来源](https://www.hanyuguoxue.com/chengyu/ci-175ef6ef19) | [来源](https://www.hanyuguoxue.com/chengyu/ci-175ef6ef19) | — |
| 士别三日 | [来源](https://www.hanyuguoxue.com/cidian/ci-12914ee332) | 缺失，留空 | 缺失，留空 | — |
| 无欲则刚 | [来源](https://www.moe.gov.cn/jyb_xwfb/moe_2082/2025/2025_zl02/202602/t20260228_1429566.html) | [来源](https://www.moe.gov.cn/jyb_xwfb/moe_2082/2025/2025_zl02/202602/t20260228_1429566.html) | 缺失，留空 | 采用每日好词语释文。 |
| 有容乃大 | [来源](https://www.hanyuguoxue.com/cidian/ci-4cb55b4f4) | 缺失，留空 | 缺失，留空 | — |
| 风吹雨淋 | [来源](https://www.hanyuguoxue.com/cidian/ci-daeac1baf) | 缺失，留空 | 缺失，留空 | — |
| 如临其境 | [来源](https://wapbaike.baidu.com/item/如临其境/53572117) | 缺失，留空 | 缺失，留空 | 采用百科词条释义。 |
| 憨态可掬 | [来源](https://www.hanyuguoxue.com/chengyu/ci-337d1de3a) | [来源](https://www.hanyuguoxue.com/chengyu/ci-337d1de3a) | 缺失，留空 | — |
| 月华如水 | [来源](https://www.cidianwang.com/cd/y/yuehua83904.htm) | [来源](https://m.cidianwang.com/zd/yue/yue3632.htm) | [来源](https://m.cidianwang.com/zd/yue/yue3632.htm) | 据“月华”释义整理；引文见词典网“月”字条。 |
| 由己及人 | [来源](https://www.hanyuguoxue.com/cidian/ci-947dcc2f2) | 缺失，留空 | 缺失，留空 | — |
| 围追堵截 | [来源](https://www.hanyuguoxue.com/chengyu/ci-7fcdc23b0) | [来源](https://www.hanyuguoxue.com/chengyu/ci-7fcdc23b0) | [来源](https://www.hanyuguoxue.com/chengyu/ci-7fcdc23b0) | — |
| 尊老爱幼 | [来源](https://www.hanyuguoxue.com/cidian/ci-10c7914841) | 缺失，留空 | 缺失，留空 | — |
| 志不可满 | [来源](https://www.moedict.tw/uni/%E5%BF%97%E4%B8%8D%E5%8F%AF%E6%BB%BF) | [来源](https://www.moedict.tw/uni/%E5%BF%97%E4%B8%8D%E5%8F%AF%E6%BB%BF) | [来源](https://www.moedict.tw/uni/%E5%BF%97%E4%B8%8D%E5%8F%AF%E6%BB%BF) | — |
| 重重叠叠 | [来源](https://www.hanyuguoxue.com/chengyu/ci-1d78be32c5) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1d78be32c5) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1d78be32c5) | — |
| 漫天风雪 | [来源](https://www.hanyuguoxue.com/chengyu/ci-1887e55320) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1887e55320) | 缺失，留空 | — |
| 心有灵犀 | [来源](https://www.hanyuguoxue.com/chengyu/ci-1672810302) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1672810302) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1672810302) | — |
| 死于安乐 | [来源](https://zdic.net/hans/生於憂患，死於安樂) | [来源](https://zh.wikisource.org/wiki/%E5%AD%9F%E5%AD%90/%E5%91%8A%E5%AD%90%E4%B8%8B) | [来源](https://zh.wikisource.org/wiki/%E5%AD%9F%E5%AD%90/%E5%91%8A%E5%AD%90%E4%B8%8B) | 完整说法的分句，按该分句整理释义。 |
| 逆流而上 | [来源](https://www.hanyuguoxue.com/chengyu/ci-1021303599) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1021303599) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1021303599) | — |
| 顺流而下 | [来源](https://www.hanyuguoxue.com/chengyu/ci-129a86ad31) | [来源](https://www.hanyuguoxue.com/chengyu/ci-129a86ad31) | [来源](https://www.hanyuguoxue.com/chengyu/ci-129a86ad31) | — |
| 回清倒影 | [来源](https://www.hanyuguoxue.com/cidian/ci-80ad9b5ec) | [来源](https://zh.wikisource.org/wiki/%E4%B8%89%E5%B3%BD) | [来源](https://zh.wikisource.org/wiki/%E4%B8%89%E5%B3%BD) | — |
| 清荣峻茂 | [来源](https://www.hanyuguoxue.com/cidian/ci-1048dd2dc2) | [来源](https://zh.wikisource.org/wiki/%E4%B8%89%E5%B3%BD) | [来源](https://zh.wikisource.org/wiki/%E4%B8%89%E5%B3%BD) | — |
| 空谷传响 | [来源](https://www.hanyuguoxue.com/cidian/ci-e0bcdf1c8) | [来源](https://zh.wikisource.org/wiki/%E4%B8%89%E5%B3%BD) | [来源](https://zh.wikisource.org/wiki/%E4%B8%89%E5%B3%BD) | — |
| 奇山异水 | [来源](https://www.hanyuguoxue.com/chengyu/ci-1546d2fb5e) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1546d2fb5e) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1546d2fb5e) | — |
| 坦荡如砥 | [来源](https://www.hanyuguoxue.com/chengyu/ci-16c12d2b4f) | [来源](https://www.hanyuguoxue.com/chengyu/ci-16c12d2b4f) | [来源](https://www.hanyuguoxue.com/chengyu/ci-16c12d2b4f) | — |
| 旁逸斜出 | [来源](https://www.hanyuguoxue.com/chengyu/ci-177ac2272) | [来源](https://www.hanyuguoxue.com/chengyu/ci-177ac2272) | [来源](https://www.hanyuguoxue.com/chengyu/ci-177ac2272) | — |
| 潜滋暗长 | [来源](https://www.hanyuguoxue.com/chengyu/ci-dd194702e) | [来源](https://www.hanyuguoxue.com/chengyu/ci-dd194702e) | [来源](https://www.hanyuguoxue.com/chengyu/ci-dd194702e) | — |
| 纵横决荡 | [来源](https://www.hanyuguoxue.com/chengyu/ci-3536134ed) | [来源](https://www.hanyuguoxue.com/chengyu/ci-3536134ed) | [来源](https://www.hanyuguoxue.com/chengyu/ci-3536134ed) | — |
| 文采斐然 | [来源](https://www.hanyuguoxue.com/cidian/ci-b03744370) | 缺失，留空 | 缺失，留空 | — |
| 娓娓道来 | [来源](https://www.hanyuguoxue.com/cidian/ci-c6224402e) | 缺失，留空 | 缺失，留空 | — |
| 恹恹欲睡 | [来源](https://www.hanyuguoxue.com/cidian/ci-110a32a83a) | 缺失，留空 | 缺失，留空 | — |
| 长虹饮涧 | 保留原释义 | 缺失，留空 | 缺失，留空 | 词典返回彩虹成因介绍，缺少整词释义。；未检得可用整词释义，保留原释义。 |
| 字字千钧 | [来源](https://hanyu.baidu.com/zici/s?wd=字字千钧) | 缺失，留空 | 缺失，留空 | 该词条以近义说法“一字千钧”释义。 |
| 舳舻相接 | [来源](https://www.hanyuguoxue.com/chengyu/ci-769617df3) | [来源](https://www.hanyuguoxue.com/chengyu/ci-769617df3) | [来源](https://www.hanyuguoxue.com/chengyu/ci-769617df3) | — |
| 生于忧患 | [来源](https://zdic.net/hans/生於憂患，死於安樂) | [来源](https://zh.wikisource.org/wiki/%E5%AD%9F%E5%AD%90/%E5%91%8A%E5%AD%90%E4%B8%8B) | [来源](https://zh.wikisource.org/wiki/%E5%AD%9F%E5%AD%90/%E5%91%8A%E5%AD%90%E4%B8%8B) | 完整说法的分句，按该分句整理释义。 |
| 固不可彻 | [来源](https://www.hanyuguoxue.com/chengyu/ci-1c404ae5e) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1c404ae5e) | [来源](https://zh.wikisource.org/wiki/%E6%84%9A%E5%85%AC%E7%A7%BB%E5%B1%B1) | — |
| 寒暑易节 | [来源](https://www.hanyuguoxue.com/chengyu/ci-18b9a31cd3) | [来源](https://www.hanyuguoxue.com/chengyu/ci-18b9a31cd3) | [来源](https://www.hanyuguoxue.com/chengyu/ci-18b9a31cd3) | — |
| 辨而不华 | [来源](https://www.xinhuanet.com/politics/2015-05/14/c_127800289.htm) | [来源](https://www.cidianwang.com/lishi/diangu/6/76176or.htm) | [来源](https://www.cidianwang.com/lishi/diangu/6/76176or.htm) | 释义据新华网释文；引文见词典网“质而不俚”。 |
| 蓄势待发 | [来源](https://dict.revised.moe.edu.tw/dictView.jsp?ID=111552&la=0&powerMode=0) | 缺失，留空 | [来源](https://dict.revised.moe.edu.tw/dictView.jsp?ID=111552&la=0&powerMode=0) | — |
| 固不待言 | 保留原释义 | [来源](https://www.chinesewords.org/dict/277077-696.html) | [来源](https://www.chinesewords.org/dict/277077-696.html) | 未找到独立词条的可用释义，保留原释义；仅补录所查引文。；未检得可用整词释义，保留原释义。 |
| 阡陌交通 | [来源](https://www.hanyuguoxue.com/cidian/ci-617fc489c) | [来源](https://zh.wikisource.org/wiki/%E6%A1%83%E8%8A%B1%E6%BA%90%E8%A8%98) | [来源](https://zh.wikisource.org/wiki/%E6%A1%83%E8%8A%B1%E6%BA%90%E8%A8%98) | — |
| 矫首昂视 | 保留原释义 | [来源](https://www.hanyuguoxue.com/chengyu/ci-1566995a5a) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1566995a5a) | 词典额外附加“高傲”义，与原文语境不符。；未检得可用整词释义，保留原释义。 |
| 袒胸露乳 | [来源](https://dict.baidu.com/s?type=zici&wd=袒胸露乳) | [来源](https://zh.wikisource.org/wiki/%E6%A0%B8%E8%88%9F%E8%A8%98) | [来源](https://zh.wikisource.org/wiki/%E6%A0%B8%E8%88%9F%E8%A8%98) | — |
| 理至易明 | [来源](https://www.hanyuguoxue.com/cidian/ci-929d4e910) | 缺失，留空 | 缺失，留空 | — |
| 敬事而信 | [来源](https://dict.revised.moe.edu.tw/dictView.jsp?ID=96438&la=0&powerMode=0) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | 依据“敬事”条引证整理。 |
| 人生在世 | [来源](https://www.hanyuguoxue.com/chengyu/ci-208c3904b8) | [来源](https://www.hanyuguoxue.com/chengyu/ci-208c3904b8) | [来源](https://www.hanyuguoxue.com/chengyu/ci-208c3904b8) | — |
| 推推搡搡 | [来源](https://www.hanyuguoxue.com/cidian/ci-10bfe19599) | [来源](https://www.hanyuguoxue.com/cidian/ci-10bfe19599) | [来源](https://www.hanyuguoxue.com/cidian/ci-10bfe19599) | — |
| 柔中有刚 | [来源](https://www.hanyuguoxue.com/chengyu/ci-1b854b80bb) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1b854b80bb) | [来源](https://www.hanyuguoxue.com/chengyu/ci-1b854b80bb) | — |
| 不测之险 | [来源](https://www.zidian.com.cn/ci/u4e0du6d4b) | [来源](https://www.cidianwang.com/cd/b/buzi86260.htm) | [来源](https://www.cidianwang.com/cd/b/buzi86260.htm) | 据“不测”条整理释义；引文见“不訾”条。 |
| 夜凉如水 | [来源](https://dict.youdao.com/w/夜凉如水/) | 缺失，留空 | [来源](https://dict.youdao.com/w/夜凉如水/) | 据英汉词典译义和例句整理。 |
| 胜利在望 | [来源](https://www.hanyuguoxue.com/chengyu/ci-ba9aabaac) | 缺失，留空 | [来源](https://www.hanyuguoxue.com/chengyu/ci-ba9aabaac) | — |
| 和和美美 | [来源](https://cy.hwxnet.com/view/ipmpjkndiancdckh.html) | [来源](https://cy.hwxnet.com/view/ipmpjkndiancdckh.html) | [来源](https://cy.hwxnet.com/view/ipmpjkndiancdckh.html) | — |
| 克明俊德 | [来源](https://www.cidianwang.com/lishi/diangu/0/21150fi.htm) | [来源](https://www.cidianwang.com/lishi/diangu/0/21150fi.htm) | 缺失，留空 | — |
| 以和为贵 | [来源](https://en.wiktionary.org/wiki/以和为贵) | 缺失，留空 | 缺失，留空 | 据英文释义译写。 |
| 各美其美 | [来源](https://www.neac.gov.cn/seac/c103391/202304/1162902.shtml) | [来源](https://www.neac.gov.cn/seac/c103391/202304/1162902.shtml) | [来源](https://www.neac.gov.cn/seac/c103391/202304/1162902.shtml) | 采用对费孝通十六字箴言的释文。 |
| 袅袅不绝 | [来源](https://www.hanyuguoxue.com/chengyu/ci-f7fe95b2) | [来源](https://www.hanyuguoxue.com/chengyu/ci-f7fe95b2) | [来源](https://www.hanyuguoxue.com/chengyu/ci-f7fe95b2) | — |
| 秦皇汉武 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E7%A7%A6%E7%9A%87%E6%BC%A2%E6%AD%A6) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E7%A7%A6%E7%9A%87%E6%BC%A2%E6%AD%A6) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E7%A7%A6%E7%9A%87%E6%BC%A2%E6%AD%A6) | — |
| 饶有兴味 | [来源](https://www.hanyuguoxue.com/chengyu/ci-d542754e6) | [来源](https://www.hanyuguoxue.com/chengyu/ci-d542754e6) | 缺失，留空 | — |
| 实实在在 | [来源](https://www.hanyuguoxue.com/chengyu/ci-f7863a0ac) | [来源](https://www.hanyuguoxue.com/chengyu/ci-f7863a0ac) | [来源](https://www.hanyuguoxue.com/chengyu/ci-f7863a0ac) | — |
| 铮铮作响 | [来源](https://dict.baidu.com/s?cf=zuci&wd=铮组词) | 缺失，留空 | 缺失，留空 | — |
| 宠辱偕忘 | [来源](https://www.cidianwang.com/yuwen/wenyanwen/951047.htm) | [来源](https://zh.wikisource.org/wiki/%E5%B2%B3%E9%99%BD%E6%A8%93%E8%A8%98) | [来源](https://zh.wikisource.org/wiki/%E5%B2%B3%E9%99%BD%E6%A8%93%E8%A8%98) | 采用词典网原文译注。 |
| 樯倾楫摧 | [来源](https://www.guoxuemi.com/chengyu/62708c.html) | [来源](https://zh.wikisource.org/wiki/%E5%B2%B3%E9%99%BD%E6%A8%93%E8%A8%98) | [来源](https://zh.wikisource.org/wiki/%E5%B2%B3%E9%99%BD%E6%A8%93%E8%A8%98) | — |
| 波澜不惊 | [来源](https://www.newton.com.tw/wiki/波瀾不驚/80779) | [来源](https://zh.wikisource.org/wiki/%E5%B2%B3%E9%99%BD%E6%A8%93%E8%A8%98) | [来源](https://zh.wikisource.org/wiki/%E5%B2%B3%E9%99%BD%E6%A8%93%E8%A8%98) | — |
| 满目萧然 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%BB%BF%E7%9B%AE%E8%95%AD%E7%84%B6) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%BB%BF%E7%9B%AE%E8%95%AD%E7%84%B6) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%BB%BF%E7%9B%AE%E8%95%AD%E7%84%B6) | — |
| 虎啸猿啼 | 保留原释义 | [来源](https://zh.wikisource.org/wiki/%E5%B2%B3%E9%99%BD%E6%A8%93%E8%A8%98) | [来源](https://zh.wikisource.org/wiki/%E5%B2%B3%E9%99%BD%E6%A8%93%E8%A8%98) | 未检得可用整词释义，保留原释义。 |
| 郁郁青青 | [来源](https://www.moedict.tw/uni/%E9%83%81%E9%83%81%E9%9D%92%E9%9D%92) | [来源](https://www.moedict.tw/uni/%E9%83%81%E9%83%81%E9%9D%92%E9%9D%92) | [来源](https://www.moedict.tw/uni/%E9%83%81%E9%83%81%E9%9D%92%E9%9D%92) | — |
| 风霜高洁 | [来源](https://cidian.hao86.com/68345__ciyu.html) | [来源](https://zh.wikisource.org/wiki/%E9%86%89%E7%BF%81%E4%BA%AD%E8%A8%98) | [来源](https://zh.wikisource.org/wiki/%E9%86%89%E7%BF%81%E4%BA%AD%E8%A8%98) | — |
| 求神拜佛 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%B1%82%E7%A5%9E%E6%8B%9C%E4%BD%9B) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%B1%82%E7%A5%9E%E6%8B%9C%E4%BD%9B) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%B1%82%E7%A5%9E%E6%8B%9C%E4%BD%9B) | — |
| 善解人意 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%96%84%E8%A7%A3%E4%BA%BA%E6%84%8F) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%96%84%E8%A7%A3%E4%BA%BA%E6%84%8F) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%96%84%E8%A7%A3%E4%BA%BA%E6%84%8F) | — |
| 春蚕自缚 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%98%A5%E8%A0%B6%E8%87%AA%E7%B8%9B) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%98%A5%E8%A0%B6%E8%87%AA%E7%B8%9B) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%98%A5%E8%A0%B6%E8%87%AA%E7%B8%9B) | — |
| 不谙世事 | [来源](https://www.hao86.com/ciyu_view_9d98fc43ac9d98fc/) | 缺失，留空 | [来源](https://www.hao86.com/ciyu_view_9d98fc43ac9d98fc/) | — |
| 国弊民穷 | 保留原释义 | [来源](https://paper.people.com.cn/rmrbhwb/images/2021-09/30/05/rmrbhwb2021093005.pdf) | [来源](https://paper.people.com.cn/rmrbhwb/images/2021-09/30/05/rmrbhwb2021093005.pdf) | 未找到独立词条的可用释义，保留原释义；仅补录所查引文。；未检得可用整词释义，保留原释义。 |
| 男扮女装 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E7%94%B7%E6%89%AE%E5%A5%B3%E8%A3%9D) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E7%94%B7%E6%89%AE%E5%A5%B3%E8%A3%9D) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E7%94%B7%E6%89%AE%E5%A5%B3%E8%A3%9D) | — |
| 云山雾罩 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E9%9B%B2%E5%B1%B1%E9%9C%A7%E7%BD%A9) | 缺失，留空 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E9%9B%B2%E5%B1%B1%E9%9C%A7%E7%BD%A9) | — |
| 免冠徒跣 | [来源](https://baike.sogou.com/m/fullLemma?lid=7897149) | [来源](https://zh.wikisource.org/wiki/%E5%94%90%E9%9B%8E%E4%B8%8D%E8%BE%B1%E4%BD%BF%E5%91%BD) | [来源](https://zh.wikisource.org/wiki/%E5%94%90%E9%9B%8E%E4%B8%8D%E8%BE%B1%E4%BD%BF%E5%91%BD) | 采用百科词条释义。 |
| 天下缟素 | [来源](https://www.zdic.net/hans/縞素) | [来源](https://zh.wikisource.org/wiki/%E5%94%90%E9%9B%8E%E4%B8%8D%E8%BE%B1%E4%BD%BF%E5%91%BD) | [来源](https://zh.wikisource.org/wiki/%E5%94%90%E9%9B%8E%E4%B8%8D%E8%BE%B1%E4%BD%BF%E5%91%BD) | 依据“缟素”条释义和引证整理。 |
| 彗星袭月 | [来源](https://bkso.baidu.com/item/天文历法/0) | [来源](https://zh.wikisource.org/wiki/%E5%94%90%E9%9B%8E%E4%B8%8D%E8%BE%B1%E4%BD%BF%E5%91%BD) | [来源](https://zh.wikisource.org/wiki/%E5%94%90%E9%9B%8E%E4%B8%8D%E8%BE%B1%E4%BD%BF%E5%91%BD) | 采用百科相关词条释义。 |
| 口体之奉 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%8F%A3%E9%AB%94%E4%B9%8B%E5%A5%89) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%8F%A3%E9%AB%94%E4%B9%8B%E5%A5%89) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%8F%A3%E9%AB%94%E4%B9%8B%E5%A5%89) | — |
| 负箧曳屣 | [来源](https://dict.baidu.com/s?ptype=poem&wd=负箧曳屣) | [来源](https://zh.wikisource.org/wiki/%E9%80%81%E6%9D%B1%E9%99%BD%E9%A6%AC%E7%94%9F%E5%BA%8F) | [来源](https://zh.wikisource.org/wiki/%E9%80%81%E6%9D%B1%E9%99%BD%E9%A6%AC%E7%94%9F%E5%BA%8F) | — |
| 烛幽索隐 | 保留原释义 | [来源](https://www.jsrd.gov.cn/xwzx/zkzl/rmyql/2023/d_10998/202308/P020260113790000617626.pdf) | [来源](https://www.jsrd.gov.cn/xwzx/zkzl/rmyql/2023/d_10998/202308/P020260113790000617626.pdf) | 未找到独立词条的可用释义，保留原释义；仅补录所查引文。；未检得可用整词释义，保留原释义。 |
| 针砭时弊 | [来源](https://tw.chengyudaquan.org/cidian/ci-1548xu1dxpfmxnoa.html) | 缺失，留空 | 缺失，留空 | — |
| 天高地远 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%A4%A9%E9%AB%98%E5%9C%B0%E9%81%A0) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%A4%A9%E9%AB%98%E5%9C%B0%E9%81%A0) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%A4%A9%E9%AB%98%E5%9C%B0%E9%81%A0) | — |
| 收放自如 | [来源](https://www.moedict.tw/uni/%E6%94%B6%E6%94%BE%E8%87%AA%E5%A6%82) | 缺失，留空 | [来源](https://www.moedict.tw/uni/%E6%94%B6%E6%94%BE%E8%87%AA%E5%A6%82) | — |
| 长空万里 | [来源](https://dict.youdao.com/w/长空万里/) | 缺失，留空 | 缺失，留空 | 据英汉词典译义整理。 |
| 文采藻饰 | 保留原释义 | 缺失，留空 | 缺失，留空 | 未检得可用整词释义，保留原释义。 |
| 揭竿为旗 | [来源](https://www.zdic.net/hans/揭竿) | [来源](https://zh.wikisource.org/wiki/%E9%81%8E%E7%A7%A6%E8%AB%96) | [来源](https://zh.wikisource.org/wiki/%E9%81%8E%E7%A7%A6%E8%AB%96) | 依据“揭竿”条释义及引证整理。 |
| 斩木为兵 | [来源](https://www.moedict.tw/uni/%E6%96%AC%E6%9C%A8%E7%82%BA%E5%85%B5) | [来源](https://www.moedict.tw/uni/%E6%96%AC%E6%9C%A8%E7%82%BA%E5%85%B5) | [来源](https://www.moedict.tw/uni/%E6%96%AC%E6%9C%A8%E7%82%BA%E5%85%B5) | — |
| 深入不毛 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%B7%B1%E5%85%A5%E4%B8%8D%E6%AF%9B) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%B7%B1%E5%85%A5%E4%B8%8D%E6%AF%9B) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%B7%B1%E5%85%A5%E4%B8%8D%E6%AF%9B) | — |
| 寻寻觅觅 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%B0%8B%E5%B0%8B%E8%A6%93%E8%A6%93) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%B0%8B%E5%B0%8B%E8%A6%93%E8%A6%93) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%B0%8B%E5%B0%8B%E8%A6%93%E8%A6%93) | — |
| 百舸争流 | [来源](https://dict.baidu.com/s?ptype=poem&wd=百舸争流) | [来源](https://dict.baidu.com/s?ptype=poem&wd=百舸争流) | [来源](https://dict.baidu.com/s?ptype=poem&wd=百舸争流) | — |
| 书生意气 | 保留原释义 | 缺失，留空 | 缺失，留空 | 未检得可用整词释义，保留原释义。 |
| 弯弯曲曲 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%BD%8E%E5%BD%8E%E6%9B%B2%E6%9B%B2) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%BD%8E%E5%BD%8E%E6%9B%B2%E6%9B%B2) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%BD%8E%E5%BD%8E%E6%9B%B2%E6%9B%B2) | — |
| 锐意进取 | [来源](https://kmcha.com/cidian/锐意进取) | 缺失，留空 | 缺失，留空 | — |
| 山不厌高 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%B1%B1%E4%B8%8D%E5%8E%AD%E9%AB%98) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%B1%B1%E4%B8%8D%E5%8E%AD%E9%AB%98) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%B1%B1%E4%B8%8D%E5%8E%AD%E9%AB%98) | — |
| 海不厌深 | [来源](https://www.cidianwang.com/mingju/013563427.htm) | [来源](https://zh.wikisource.org/wiki/%E7%9F%AD%E6%AD%8C%E8%A1%8C_%28%E6%9B%B9%E6%93%8D%29) | [来源](https://zh.wikisource.org/wiki/%E7%9F%AD%E6%AD%8C%E8%A1%8C_%28%E6%9B%B9%E6%93%8D%29) | 采用词典网原文译注。 |
| 鼓瑟吹笙 | [来源](https://www.cidianwang.com/mingju/013563427.htm) | [来源](https://zh.wikisource.org/wiki/%E8%A9%A9%E7%B6%93/%E9%B9%BF%E9%B3%B4) | [来源](https://zh.wikisource.org/wiki/%E8%A9%A9%E7%B6%93/%E9%B9%BF%E9%B3%B4) | 依据原文译注整理。 |
| 恬然自安 | [来源](https://www.hao86.com/ciyu_view_9d17d943ac9d17d9/) | [来源](https://dict.revised.moe.edu.tw/dictView.jsp?ID=53557&q=1&word=然) | [来源](https://dict.revised.moe.edu.tw/dictView.jsp?ID=53557&q=1&word=然) | — |
| 封狼居胥 | [来源](https://zdic.net/hans/%E5%B0%81%E7%8B%BC%E5%B1%85%E8%83%A5) | [来源](https://zdic.net/hans/%E5%B0%81%E7%8B%BC%E5%B1%85%E8%83%A5) | [来源](https://zdic.net/hans/%E5%B0%81%E7%8B%BC%E5%B1%85%E8%83%A5) | — |
| 冷冷清清 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%86%B7%E5%86%B7%E6%B8%85%E6%B8%85) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%86%B7%E5%86%B7%E6%B8%85%E6%B8%85) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%86%B7%E5%86%B7%E6%B8%85%E6%B8%85) | — |
| 点点滴滴 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E9%BB%9E%E9%BB%9E%E6%BB%B4%E6%BB%B4) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E9%BB%9E%E9%BB%9E%E6%BB%B4%E6%BB%B4) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E9%BB%9E%E9%BB%9E%E6%BB%B4%E6%BB%B4) | — |
| 有理有据 | [来源](https://en.wiktionary.org/wiki/有理有据) | 缺失，留空 | 缺失，留空 | 据英文释义译写。 |
| 含糊不清 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%90%AB%E7%B3%8A%E4%B8%8D%E6%B8%85) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%90%AB%E7%B3%8A%E4%B8%8D%E6%B8%85) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%90%AB%E7%B3%8A%E4%B8%8D%E6%B8%85) | — |
| 善假于物 | [来源](https://www.zdic.net/hans/假) | [来源](https://zh.wikisource.org/wiki/%E8%8D%80%E5%AD%90/%E5%8B%B8%E5%AD%B8%E7%AF%87) | [来源](https://zh.wikisource.org/wiki/%E8%8D%80%E5%AD%90/%E5%8B%B8%E5%AD%B8%E7%AF%87) | 依据“假”字“凭借”义及引证整理。 |
| 木直中绳 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%9C%A8%E7%9B%B4%E4%B8%AD%E7%B9%A9) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%9C%A8%E7%9B%B4%E4%B8%AD%E7%B9%A9) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%9C%A8%E7%9B%B4%E4%B8%AD%E7%B9%A9) | — |
| 恰恰相反 | 保留原释义 | 缺失，留空 | 缺失，留空 | 未检得可用整词释义，保留原释义。 |
| 旌旗蔽空 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%97%8C%E6%97%97%E8%94%BD%E7%A9%BA) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%97%8C%E6%97%97%E8%94%BD%E7%A9%BA) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%97%8C%E6%97%97%E8%94%BD%E7%A9%BA) | — |
| 舳舻千里 | [来源](https://www.moedict.tw/uni/%E8%88%B3%E8%89%AB%E5%8D%83%E9%87%8C) | 缺失，留空 | 缺失，留空 | — |
| 洗盏更酌 | [来源](https://www.moedict.tw/uni/%E6%B4%97%E7%9B%9E%E6%9B%B4%E9%85%8C) | [来源](https://www.moedict.tw/uni/%E6%B4%97%E7%9B%9E%E6%9B%B4%E9%85%8C) | [来源](https://www.moedict.tw/uni/%E6%B4%97%E7%9B%9E%E6%9B%B4%E9%85%8C) | — |
| 柔情似水 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%9F%94%E6%83%85%E4%BC%BC%E6%B0%B4) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%9F%94%E6%83%85%E4%BC%BC%E6%B0%B4) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%9F%94%E6%83%85%E4%BC%BC%E6%B0%B4) | — |
| 千乘之国 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%8D%83%E4%B9%98%E4%B9%8B%E5%9C%8B) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%8D%83%E4%B9%98%E4%B9%8B%E5%9C%8B) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%8D%83%E4%B9%98%E4%B9%8B%E5%9C%8B) | — |
| 为国以礼 | [来源](https://en.wiktionary.org/wiki/為國) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | 依据“为国”条释义及引证整理。 |
| 保民而王 | [来源](https://www.moe.gov.cn/jyb_xwfb/moe_2082/2025/2025_zl02/202608/t20260806_1446214.html) | [来源](https://zh.wikisource.org/wiki/%E5%AD%9F%E5%AD%90/%E6%A2%81%E6%83%A0%E7%8E%8B%E4%B8%8A) | [来源](https://zh.wikisource.org/wiki/%E5%AD%9F%E5%AD%90/%E6%A2%81%E6%83%A0%E7%8E%8B%E4%B8%8A) | 采用每日好词语释文。 |
| 技经肯綮 | 保留原释义 | [来源](https://zh.wikisource.org/wiki/%E8%8E%8A%E5%AD%90/%E9%A4%8A%E7%94%9F%E4%B8%BB) | [来源](https://zh.wikisource.org/wiki/%E8%8E%8A%E5%AD%90/%E9%A4%8A%E7%94%9F%E4%B8%BB) | 未检得可用整词释义，保留原释义。 |
| 以乱易整 | 保留原释义 | [来源](https://www.zidian.com.cn/zi/u6574) | [来源](https://www.zidian.com.cn/zi/u6574) | 未找到独立词条的可用释义，保留原释义；仅补录所查引文。；未检得可用整词释义，保留原释义。 |
| 为之奈何 | [来源](https://bkso.baidu.com/item/奈何/79106) | 缺失，留空 | 缺失，留空 | 依据“奈何”条的“为之奈何”用例整理。 |
| 前合后偃 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%89%8D%E5%90%88%E5%BE%8C%E5%81%83) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%89%8D%E5%90%88%E5%BE%8C%E5%81%83) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%89%8D%E5%90%88%E5%BE%8C%E5%81%83) | — |
| 吵吵嚷嚷 | [来源](https://zh.wiktionary.org/wiki/吵吵嚷嚷) | 缺失，留空 | 缺失，留空 | 据英文释义译写。 |
| 窥斑见豹 | [来源](https://cy.hao86.com/b6f4__cy.html) | 缺失，留空 | 缺失，留空 | — |
| 居为奇货 | [来源](https://www.cidianwang.com/gushiwen/1/54046297211.htm) | [来源](https://www.cidianwang.com/gushiwen/1/54046297211.htm) | [来源](https://www.cidianwang.com/gushiwen/1/54046297211.htm) | 采用词典网原文译注。 |
| 天高气爽 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%A4%A9%E9%AB%98%E6%B0%A3%E7%88%BD) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%A4%A9%E9%AB%98%E6%B0%A3%E7%88%BD) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%A4%A9%E9%AB%98%E6%B0%A3%E7%88%BD) | — |
| 玉鉴琼田 | [来源](https://m.gushiwen.cn/shiwenv_8d26eae2cfdf.aspx) | [来源](https://m.gushiwen.cn/shiwenv_8d26eae2cfdf.aspx) | [来源](https://m.gushiwen.cn/shiwenv_8d26eae2cfdf.aspx) | 采用原文译注。 |
| 朝飞暮卷 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%9C%9D%E9%A3%9B%E6%9A%AE%E5%8D%B7) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%9C%9D%E9%A3%9B%E6%9A%AE%E5%8D%B7) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%9C%9D%E9%A3%9B%E6%9A%AE%E5%8D%B7) | — |
| 互诉衷肠 | [来源](https://ntireader.org/words/139744.html) | 缺失，留空 | 缺失，留空 | 据英文释义译写。 |
| 烽烟四起 | [来源](https://www.moedict.tw/uni/%E7%83%BD%E7%85%99%E5%9B%9B%E8%B5%B7) | 缺失，留空 | [来源](https://www.moedict.tw/uni/%E7%83%BD%E7%85%99%E5%9B%9B%E8%B5%B7) | — |
| 与子同袍 | [来源](https://www.moedict.tw/uni/%E8%88%87%E5%AD%90%E5%90%8C%E8%A2%8D) | [来源](https://www.moedict.tw/uni/%E8%88%87%E5%AD%90%E5%90%8C%E8%A2%8D) | [来源](https://www.moedict.tw/uni/%E8%88%87%E5%AD%90%E5%90%8C%E8%A2%8D) | — |
| 寒风凛冽 | [来源](https://zdic.net/hans/凛冽) | 缺失，留空 | 缺失，留空 | 依据“凛冽”条释义整理。 |
| 仁者不忧 | [来源](https://ctext.org/zhuzi-yulei/37/zhs) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | 依据《朱子语类》对该句的解说整理。 |
| 知者不惑 | [来源](https://www.moedict.tw/uni/%E7%9F%A5%E8%80%85%E4%B8%8D%E6%83%91) | [来源](https://www.moedict.tw/uni/%E7%9F%A5%E8%80%85%E4%B8%8D%E6%83%91) | [来源](https://www.moedict.tw/uni/%E7%9F%A5%E8%80%85%E4%B8%8D%E6%83%91) | — |
| 非礼勿动 | [来源](https://dict.cn/非礼勿动) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | 据英汉词典译义整理。 |
| 非礼勿听 | [来源](https://www.zdic.net/hans/耳擇) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | 依据“耳择”条整理。 |
| 非礼勿视 | [来源](https://baike.sogou.com/v762521.htm) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | 采用“非礼勿视”条原文译注。 |
| 非礼勿言 | [来源](https://baike.sogou.com/v762521.htm) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | [来源](https://zh.wikisource.org/wiki/%E8%AB%96%E8%AA%9E/%E5%85%A8%E8%A6%BD) | 采用“非礼勿视”条原文译注。 |
| 合抱之木 | [来源](https://dict.youdao.com/w/合抱之木/) | 缺失，留空 | 缺失，留空 | 据词典英文释义整理。 |
| 天人合一 | [来源](https://www.moedict.tw/uni/%E5%A4%A9%E4%BA%BA%E5%90%88%E4%B8%80) | 缺失，留空 | 缺失，留空 | — |
| 民为邦本 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%B0%91%E7%82%BA%E9%82%A6%E6%9C%AC) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%B0%91%E7%82%BA%E9%82%A6%E6%9C%AC) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%B0%91%E7%82%BA%E9%82%A6%E6%9C%AC) | 词典将“五子之歌”误归《论语》，订正为《尚书》。 |
| 简而言之 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E7%B0%A1%E8%80%8C%E8%A8%80%E4%B9%8B) | 缺失，留空 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E7%B0%A1%E8%80%8C%E8%A8%80%E4%B9%8B) | — |
| 以史为鉴 | [来源](https://en.wiktionary.org/wiki/以史为鉴) | 缺失，留空 | 缺失，留空 | 据英文释义译写。 |
| 兼听则明 | [来源](https://www.zdic.net/hans/兼聽則明，偏聽則蔽) | [来源](https://www.zdic.net/hans/兼聽則明，偏聽則蔽) | [来源](https://www.zdic.net/hans/兼聽則明，偏聽則蔽) | 完整说法的前半句，按该分句整理释义。 |
| 威振四海 | 保留原释义 | [来源](https://zh.wikisource.org/wiki/%E9%81%8E%E7%A7%A6%E8%AB%96) | [来源](https://zh.wikisource.org/wiki/%E9%81%8E%E7%A7%A6%E8%AB%96) | 未检得可用整词释义，保留原释义。 |
| 流血漂橹 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%B5%81%E8%A1%80%E6%BC%82%E6%AB%93) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%B5%81%E8%A1%80%E6%BC%82%E6%AB%93) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%B5%81%E8%A1%80%E6%BC%82%E6%AB%93) | — |
| 不测之渊 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E4%B8%8D%E6%B8%AC%E4%B9%8B%E6%B7%B5) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E4%B8%8D%E6%B8%AC%E4%B9%8B%E6%B7%B5) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E4%B8%8D%E6%B8%AC%E4%B9%8B%E6%B7%B5) | — |
| 猗顿之富 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E7%8C%97%E9%A0%93%E4%B9%8B%E5%AF%8C) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E7%8C%97%E9%A0%93%E4%B9%8B%E5%AF%8C) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E7%8C%97%E9%A0%93%E4%B9%8B%E5%AF%8C) | — |
| 急急忙忙 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%80%A5%E6%80%A5%E5%BF%99%E5%BF%99) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%80%A5%E6%80%A5%E5%BF%99%E5%BF%99) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%80%A5%E6%80%A5%E5%BF%99%E5%BF%99) | — |
| 断断续续 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%96%B7%E6%96%B7%E7%BA%8C%E7%BA%8C) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%96%B7%E6%96%B7%E7%BA%8C%E7%BA%8C) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E6%96%B7%E6%96%B7%E7%BA%8C%E7%BA%8C) | — |
| 张弛有度 | [来源](https://www.hanyuguoxue.com/cidian/ci-138fcba83c) | 缺失，留空 | 缺失，留空 | — |
| 孤孤单单 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%AD%A4%E5%AD%A4%E5%96%AE%E5%96%AE) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%AD%A4%E5%AD%A4%E5%96%AE%E5%96%AE) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%AD%A4%E5%AD%A4%E5%96%AE%E5%96%AE) | — |
| 徘徊不前 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%BE%98%E5%BE%8A%E4%B8%8D%E5%89%8D) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%BE%98%E5%BE%8A%E4%B8%8D%E5%89%8D) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%BE%98%E5%BE%8A%E4%B8%8D%E5%89%8D) | — |
| 吹胡瞪眼 | [来源](https://m.guoxuedashi.com/hydcd/89373h.html) | 缺失，留空 | 缺失，留空 | 采用该条转引的“吹胡子瞪眼睛”释义。 |
| 波澜起伏 | [来源](https://www.zidian.com.cn/ci/u6ce2u6f9cu8d77u4f0f) | 缺失，留空 | 缺失，留空 | — |
| 至情至性 | [来源](https://baike.sogou.com/v7659578.htm) | 缺失，留空 | 缺失，留空 | 采用百科词条释义。 |
| 俯仰一世 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E4%BF%AF%E4%BB%B0%E4%B8%80%E4%B8%96) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E4%BF%AF%E4%BB%B0%E4%B8%80%E4%B8%96) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E4%BF%AF%E4%BB%B0%E4%B8%80%E4%B8%96) | — |
| 少长咸集 | [来源](https://www.hanyuguoxue.com/chengyu/ci-15632e7b28) | [来源](https://zh.wikisource.org/wiki/%E8%98%AD%E4%BA%AD%E9%9B%86%E5%BA%8F) | [来源](https://zh.wikisource.org/wiki/%E8%98%AD%E4%BA%AD%E9%9B%86%E5%BA%8F) | 采用完整说法“群贤毕至，少长咸集”后半句释义。 |
| 狂放不羁 | [来源](https://www.zdic.net/hans/狂放) | 缺失，留空 | 缺失，留空 | 依据“狂放”条释义及用例整理。 |
| 群贤毕至 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E7%BE%A4%E8%B3%A2%E7%95%A2%E8%87%B3) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E7%BE%A4%E8%B3%A2%E7%95%A2%E8%87%B3) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E7%BE%A4%E8%B3%A2%E7%95%A2%E8%87%B3) | — |
| 载欣载奔 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E8%BC%89%E6%AC%A3%E8%BC%89%E5%A5%94) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E8%BC%89%E6%AC%A3%E8%BC%89%E5%A5%94) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E8%BC%89%E6%AC%A3%E8%BC%89%E5%A5%94) | — |
| 前途无量 | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%89%8D%E9%80%94%E7%84%A1%E9%87%8F) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%89%8D%E9%80%94%E7%84%A1%E9%87%8F) | [来源](https://zhonghuachengyu.18dao.net/中華成語/%E5%89%8D%E9%80%94%E7%84%A1%E9%87%8F) | — |
| 天圆地方 | [来源](https://www.cidianwang.com/lishi/zhishi/1/66251xi.htm) | [来源](https://www.cidianwang.com/lishi/zhishi/1/66251xi.htm) | 缺失，留空 | — |

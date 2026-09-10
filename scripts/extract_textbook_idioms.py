"""从教材 PDF 提取现有成语库命中项，生成带页码和上下文的 Markdown 审核表。

依赖：pypdf；低文字量页使用 macOS Swift / PDFKit / Vision 本地 OCR。
只读教材和游戏数据库，不修改准入词池。字典匹配不是完整的成语语义识别。
"""
import argparse
from collections import defaultdict
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import subprocess
import sys
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = 1


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def chinese(c):
    return '\u3400' <= c <= '\u9fff' or '\U00020000' <= c <= '\U0002ffff'


def normalized(text):
    """保留标点/数字边界；仅移除空白和拉丁注音，保留到原文的索引。"""
    result, offsets = [], []
    for pos, char in enumerate(text):
        if char.isspace() or unicodedata.category(char) in ('Mn', 'Cf'):
            continue
        if char.isalpha() and 'LATIN' in unicodedata.name(char, ''):
            continue
        result.append(char)
        offsets.append(pos)
    return ''.join(result), offsets


def make_trie(words):
    trie = {}
    for word in words:
        node = trie
        for c in word:
            node = node.setdefault(c, {})
        node[''] = word
    return trie


def matches(text, trie):
    clean, offsets = normalized(text)
    for start in range(len(clean)):
        node = trie
        for end in range(start, len(clean)):
            node = node.get(clean[end])
            if node is None:
                break
            if '' not in node:
                continue
            left, right = offsets[start], offsets[end] + 1
            raw = text[left:right]
            flags = []
            if '\n' in raw or '\r' in raw:
                flags.append('跨行')
            if any(c.isalpha() and 'LATIN' in unicodedata.name(c, '') for c in raw):
                flags.append('移除注音或拉丁字母')
            if any(c.isspace() for c in raw) and not flags:
                flags.append('移除空白')
            yield {'word': node[''], 'start': left, 'end': right, 'matched_text': raw,
                   'context': text[max(0, left - 45):min(len(text), right + 45)],
                   'readable_context': clean[max(0, start - 25):end + 26], 'flags': flags}



def unknown_candidates(text, known):
    """只收集边界完整的库外四字片段，供人工判定，不认定其为成语。"""
    clean, offsets = normalized(text)
    for match in re.finditer(r'(?<![\u3400-\u9fff])[\u3400-\u9fff]{4}(?![\u3400-\u9fff])', clean):
        word = match[0]
        if word not in known:
            yield {'word': word, 'raw': text[offsets[match.start()]:offsets[match.end()-1]+1],
                   'context': clean[max(0, match.start()-20):match.end()+20]}


def book_meta(path):
    name = path.stem
    nums = dict(zip('一二三四五六七八九', range(1, 10)))
    match = re.search(r'([1-9一二三四五六七八九])年级', name)
    if match:
        value = match[1]
        grade = nums[value] if value in nums else int(value)
        stage = '小学' if grade <= 6 else '初中'
        term = '上册' if '上册' in name else '下册'
        return grade * 10 + (0 if term == '上册' else 1), f'{stage}{grade}年级{term}'
    order = {'必修上册': 100, '必修下册': 101, '选择性必修上册': 102,
             '选择性必修中册': 103, '选择性必修下册': 104}
    for title in sorted(order, key=len, reverse=True):
        if title in name:
            return order[title], '高中' + title
    return 999, name


def extract_pages(path, cache, ocr_binary):
    from pypdf import PdfReader
    key = digest(path)
    cache_path = cache / f'{key}-v{SCHEMA}.json'
    if cache_path.exists():
        return key, json.loads(cache_path.read_text())
    reader = PdfReader(path)
    pages = []
    for number, page in enumerate(reader.pages, 1):
        try:
            text = page.extract_text() or ''
            pages.append({'page': number, 'text': text, 'method': 'text',
                          'chinese_chars': sum(map(chinese, text))})
        except Exception as error:
            pages.append({'page': number, 'text': '', 'method': 'text',
                          'chinese_chars': 0, 'text_error': str(error)})
    low = [p['page'] for p in pages if p['chinese_chars'] < 20]
    if low:
        if not ocr_binary.exists():
            subprocess.run(['swiftc', str(ROOT / 'scripts/textbook_ocr.swift'), '-O', '-o', str(ocr_binary)], check=True)
        output = subprocess.run([str(ocr_binary), str(path), *map(str, low)],
                                check=True, capture_output=True, text=True)
        results = {r['page']: r for r in map(json.loads, output.stdout.splitlines())}
        for number in low:
            page = pages[number - 1]
            result = results.get(number, {'error': 'OCR 未返回此页'})
            if 'error' in result:
                page['ocr_error'] = result['error']
                continue
            # 合并两种来源的匹配在调用方进行；不把文字层与 OCR 拼成一句。
            page['ocr'] = result
    cache_path.write_text(json.dumps(pages, ensure_ascii=False), encoding='utf-8')
    return key, pages


def cell(value):
    return str(value).replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('|', '&#124;').replace('\r', '').replace('\n', ' ↵ ')


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input', type=Path, help='教材 PDF 目录（递归）')
    parser.add_argument('--output', type=Path, default=ROOT / 'docs/reviews/textbook-idioms')
    parser.add_argument('--cache', type=Path, default=ROOT / 'build/textbook-extraction')
    args = parser.parse_args()
    if args.output.exists() and any(args.output.iterdir()):
        parser.error('输出目录非空；为保护人工审核内容，请指定新的 --output 目录。')
    pdfs = sorted((p for p in args.input.rglob('*') if p.suffix.lower() == '.pdf'),
                  key=lambda p: (book_meta(p)[0], p.name))
    if not pdfs:
        parser.error('未找到 PDF')
    args.cache.mkdir(parents=True, exist_ok=True)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / 'books').mkdir(exist_ok=True)
    db_path = ROOT / 'assets/data/idiom_crossword.db'
    with sqlite3.connect(f'{db_path.as_uri()}?mode=ro', uri=True) as db:
        words = {w: {'id': i, 'pinyin': p} for i, w, p in db.execute('SELECT id, word, pinyin FROM idioms')}
    raw_path = ROOT / 'data/idiom.json'
    for item in json.loads(raw_path.read_text()):
        words.setdefault(item['word'], {'id': None, 'pinyin': item['pinyin']})
    trie = make_trie(words)
    pool_path = ROOT / 'assets/data/mainline_content.json'
    pools = json.loads(pool_path.read_text())
    all_hits, books, page_report = [], [], []
    unknown = defaultdict(list)
    for index, pdf in enumerate(pdfs, 1):
        book_id = f'B{index:02}'
        rank, title = book_meta(pdf)
        print(f'[{index}/{len(pdfs)}] {title}: {pdf.name}', flush=True)
        sha, pages = extract_pages(pdf, args.cache, args.cache / 'textbook_ocr')
        book = {'id': book_id, 'title': title, 'rank': rank, 'filename': pdf.name,
                'path': str(pdf.resolve()), 'sha256': sha, 'pages': len(pages)}
        books.append(book)
        hits = []
        for page in pages:
            seen_unknown = set()
            for method, text in [('text', page['text']), ('ocr', page.get('ocr', {}).get('text', ''))]:
                for candidate in unknown_candidates(text, words):
                    if candidate['word'] not in seen_unknown:
                        candidate.update({'book_id': book_id, 'page': page['page'], 'method': method})
                        unknown[candidate['word']].append(candidate)
                        seen_unknown.add(candidate['word'])
            native_hits = list(matches(page['text'], trie))
            sources = [('text', native_hits)]
            if 'ocr' in page:
                ocr_hits = list(matches(page['ocr']['text'], trie))
                # 同页同词已被文字层发现时，不重复计算 OCR 命中。
                native_words = {h['word'] for h in native_hits}
                sources.append(('ocr', [h for h in ocr_hits if h['word'] not in native_words]))
            count = 0
            for method, found in sources:
                for hit in found:
                    hit.update({'id': f'{book_id}-P{page["page"]:03}-H{count + 1:02}',
                                'book_id': book_id, 'page': page['page'], 'method': method,
                                'idiom_id': words[hit['word']]['id']})
                    if method == 'ocr':
                        hit['flags'].append('OCR待核对')
                    hit['review'] = '待审核'
                    hits.append(hit)
                    count += 1
            page_report.append({'book_id': book_id, 'page': page['page'],
                                'native_chinese_chars': page['chinese_chars'],
                                'ocr_attempted': 'ocr' in page or 'ocr_error' in page,
                                'ocr_chinese_chars': sum(map(chinese, page.get('ocr', {}).get('text', ''))),
                                'hits': count, 'text_error': page.get('text_error'), 'ocr_error': page.get('ocr_error')})
        book['hits'] = len(hits)
        book['unique_words'] = len({h['word'] for h in hits})
        all_hits.extend(hits)
        lines = [f'# {title}：成语出现明细', '', f'原文件：[打开教材](<{book["path"]}>)', '',
                 f'文件名：{pdf.name}。共 {len(pages)} 页。页码均为从 1 开始的 **PDF 文件页码**，不是教材印刷页码。', '',
                 '全部为待审核的字典命中；跨行、去注音及 OCR 项优先核对。正文、目录、注释、练习和出版信息未自动分类。', '']
        for hit in hits:
            lines += [f'<a id="{hit["id"]}"></a>', f'### {hit["id"]} · {hit["word"]} · PDF第{hit["page"]}页', '',
                      f'- 提取：{hit["method"]}；提示：{cell("、".join(hit["flags"]) or "连续文字命中")}。',
                      f'- 原始命中字串：{cell(hit["matched_text"])}',
                      f'- 阅读上下文（去注音，仅供辅助）：{cell(hit["readable_context"])}',
                      f'- 原始上下文：{cell(hit["context"])}',
                      '- 审核：待审核；位置类型：待标注；备注：', '']
        (args.output / 'books' / f'{book_id}.md').write_text('\n'.join(lines), encoding='utf-8')
    grouped = defaultdict(list)
    for hit in all_hits:
        grouped[hit['word']].append(hit)
    by_book = {b['id']: b for b in books}
    rows = ['# 教材成语人工审核汇总', '',
            '此表可直接填写审核结论、建议词池和备注。最早册次仅指本批文件顺序，高中册次不强行对应年级。', '',
            '次数包含正文、目录、注释、练习等，未经人工去重与分类，不能直接作为词频或难度。点击出处查看原始字串及上下文。', '',
            '| 成语 | ID | 当前词池（快照） | 最早册次 | 册数 | 命中次数 | 出处（PDF页码） | 审核结论 | 建议词池 | 备注 |',
            '|---|---:|---|---|---:|---:|---|---|---|---|']
    summary = []
    for word, hits in sorted(grouped.items(), key=lambda item: (by_book[item[1][0]['book_id']]['rank'], item[1][0]['page'], item[0])):
        membership = [label for key, label in [('intro', '入门'), ('foundation', '基础'), ('expansion', '拓展')] if word in pools.get(key, [])]
        pages = {}
        for h in hits:
            pages.setdefault((h['book_id'], h['page']), h)
        refs = '；'.join(f'[{b} p{p}](books/{b}.md#{h["id"]})' for (b, p), h in pages.items())
        first = by_book[hits[0]['book_id']]['title']
        rows.append(f'| {word} | {words[word]["id"] or '未入库'} | {"、".join(membership) or "未准入"} | {first} | {len({h["book_id"] for h in hits})} | {len(hits)} | {refs} | 待审核 | | |')
        summary.append({'word': word, **words[word], 'current_pools': membership, 'first_book': first,
                        'book_count': len({h['book_id'] for h in hits}), 'hit_count': len(hits),
                        'occurrences': [h['id'] for h in hits], 'review': '待审核'})
    (args.output / '审核汇总.md').write_text('\n'.join(rows) + '\n', encoding='utf-8')
    with (args.output / 'occurrences.jsonl').open('w', encoding='utf-8') as file:
        for hit in all_hits:
            file.write(json.dumps(hit, ensure_ascii=False) + '\n')
    write_json(args.output / 'summary.json', summary)
    candidate_rows = ['# 库外四字短语候选：只用于查漏', '',
                      '以下仅是词典之外、在清理注音后的文本中具有边界的四字片段，**不代表成语**。可能是普通短语、人名、书名、标题或排版误拼。只保留你核实为成语的项，其余可排除。也无法覆盖嵌在长句中的所有库外成语。', '',
                      '| 短语 | 首处原始字串 | 首处阅读上下文 | 出处（PDF页码） | 是否成语 | 备注 |', '|---|---|---|---|---|---|']
    for word, candidates in sorted(unknown.items(), key=lambda item: (item[1][0]['book_id'], item[1][0]['page'], item[0])):
        first = candidates[0]
        refs = '；'.join(f'[{c["book_id"]} p{c["page"]}](books/{c["book_id"]}.md)（{c["method"]}）' for c in candidates)
        candidate_rows.append(f'| {word} | {cell(first["raw"])} | {cell(first["context"])} | {refs} | 待判定 | |')
    (args.output / '库外四字短语候选.md').write_text('\n'.join(candidate_rows) + '\n', encoding='utf-8')
    write_json(args.output / 'unknown_candidates.json', dict(unknown))
    write_json(args.output / 'pages.json', page_report)
    import pypdf
    manifest = {'generated_at': datetime.now().astimezone().isoformat(), 'schema': SCHEMA,
                'dictionary_sha256': digest(db_path), 'dictionary_size': len(words), 'raw_dictionary_sha256': digest(raw_path),
                'pool_sha256': digest(pool_path), 'pool_snapshot': {k: pools[k] for k in ['intro', 'foundation', 'expansion']},
                'script_sha256': digest(Path(__file__)), 'ocr_script_sha256': digest(ROOT / 'scripts/textbook_ocr.swift'),
                'python': sys.version, 'pypdf': pypdf.__version__, 'ocr_threshold': 20, 'books': books}
    write_json(args.output / 'manifest.json', manifest)
    errors = [p for p in page_report if p['ocr_error']]
    low_pages = [p for p in page_report if max(p['native_chinese_chars'], p['ocr_chinese_chars']) < 20]
    intro_missing = sorted(set(pools['intro']) - grouped.keys())
    foundation_missing = sorted(set(pools['foundation']) - grouped.keys())
    expansion_missing = sorted(set(pools['expansion']) - grouped.keys())
    report = ['# 语文教材成语提取与审核', '',
              f'本次处理 **{len(books)}本教材、{len(page_report)}页**，匹配到 **{len(grouped)}条不同词典条目、{len(all_hits)}处命中**。其中四字条目{sum(len(w) == 4 for w in grouped)}条，非四字条目{sum(len(w) != 4 for w in grouped)}条，全部待人工审核。', '',
              '从 [审核汇总](审核汇总.md) 开始，逐词填写审核结论、建议词池与备注；出处链接跳转到分册明细。分册顶部可打开原PDF，再按标注的PDF页码核查。', '',
              f'另有 **{len(unknown)}条[库外四字短语候选](库外四字短语候选.md)**，仅用于人工查漏，不计入成语数。', '',
              '## 如何审核', '',
              '1. 在审核汇总填写：审核结论（保留／排除／存疑）、建议词池（入门／基础／拓展／暂不准入）和备注。',
              '2. 对跨行、注音清理及同形普通短语，点击出处核对原PDF；阅读上下文只便于浏览，原始字串与页面才是核查依据。',
              '3. 同一词有多处出处时，可在分册明细逐条标注正文／注释／练习／目录／栏目标题及是否误拼；例如“日积月累”作为栏目标题应与正文使用区分。',
              '4. 审核后再汇总更新游戏词池，不自动把首次出现年级换算为难度。', '',
              '## 提取口径与限制', '',
              '- 合并游戏数据库与 `data/idiom.json` 原始词典精确匹配（条目数见 manifest.json）；包括非四字条目，未进入游戏数据库的ID标注为“未入库”。字典之外的成语仍可能遗漏。',
              '- 页内移除空白、拉丁注音后匹配，保留标点、数字边界，不跨页拼接；跨行与去注音的命中已标记。段落/栏序误拼、普通语句恰好同形仍可能造成误报，需对照原页。',
              '- 每页先提取文字层；少于20个汉字时追加 Apple Vision 中文OCR。同页同词优先保留文字层命中，OCR补充新词，不重复累计两个来源。',
              '- 文字层超过阈值的混合图片页未全页OCR，图片内文字、跨页成语、异体字、带标点或数字的表达，以及识别错误可能漏检；本结果不能声称教材成语已无遗漏。',
              '- PDF页码从1开始；没有猜测印刷页码、章节与正文/练习类型。教材版本来自文件名，未认证其版本或完整性。',
              '- 计数含目录、练习、注释等重复出现；它是命中次数，不是经校准的日常词频。教材未检出不等于生僻，出现过不等于玩家掌握。',
              '- 当前词池为运行时文件快照，未修改游戏词库、难度或准入名单。', '',
              '## 覆盖检查', '',
              f'- OCR检查页数：{sum(p["ocr_attempted"] for p in page_report)}；OCR错误页数：{len(errors)}；文字层与OCR均少于20汉字的页数：{len(low_pages)}（含封面、插图、空白页，仍需复核）。',
              '- 全部页的提取状态见 [pages.json](pages.json)，包括未命中页；原文件SHA-256、字典及词池快照见 [manifest.json](manifest.json)。', '',
              '| 教材 | PDF页数 | 不同成语 | 命中次数 |', '|---|---:|---:|---:|']
    report += [f'| [{b["id"]} {b["title"]}](books/{b["id"]}.md) | {b["pages"]} | {b["unique_words"]} | {b["hits"]} |' for b in books]
    report += ['', '## 当前词池未检出的成语', '', '这里是对照结果，不是删除建议；入门词属于基础词子集。', '']
    for title, missing in [('入门', intro_missing), ('基础', foundation_missing), ('拓展', expansion_missing)]:
        report += [f'### {title}：{len(missing)}条', '', '、'.join(missing) or '无', '']
    report += ['## 复现', '', '依赖 Python 3、pypdf；OCR依赖 macOS 自带 Vision/PDFKit 和 Swift 编译器。全部本地处理，无外部OCR服务。', '',
               '```bash', 'python3 -m pip install pypdf',
               'python3 scripts/extract_textbook_idioms.py "/Users/serenaxxsun/my/成语/教材" --output docs/reviews/textbook-idioms-new', '```', '',
               '输出目录必须为空，避免覆盖人工审核。原始逐页文字与OCR缓存位于忽略提交的 `build/textbook-extraction/`，正式文档只保留命中附近的短上下文。删除该缓存可重新识别。', '',
               '机器读取文件：`occurrences.jsonl` 为出现明细，`summary.json` 为汇总。人工优先编辑Markdown；JSON是生成快照，不会自动同步人工修改。', '']
    (args.output / 'README.md').write_text('\n'.join(report), encoding='utf-8')
    print(f'Done: {len(grouped)} words, {len(all_hits)} hits, {len(errors)} OCR errors. {args.output}', flush=True)
    return 1 if errors else 0


if __name__ == '__main__':
    raise SystemExit(main())

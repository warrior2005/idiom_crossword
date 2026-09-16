import hashlib
import json
from pathlib import Path
import subprocess
import sys
import sqlite3
import unittest
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from build_four_tier_content import apply_content, reviewed_rows, tier, unreviewed_overrides


class FourTierContentTest(unittest.TestCase):
    def test_completed_review_confirms_blank_and_explicit_annotations(self):
        path = ROOT / 'docs/reviews/textbook-idioms/非教材_未人工审核成语分档表.md'
        ids = json.loads((ROOT / 'data/idiom_ids.json').read_text())
        content = json.loads((ROOT / 'assets/data/four_tier_content.json').read_text())
        self.assertTrue(all(r[4] for r in content['entries']))
        remaining = {r[1] for r in reviewed_rows(path)}
        rows = reviewed_rows(path)
        self.assertEqual(len(rows), 26655)
        self.assertEqual({r[1] for r in rows}, remaining)
        imported = unreviewed_overrides(path, ids, set(ids) - remaining)
        self.assertEqual(len(imported), 26655)
        expected = {r[1]: r[3] or r[2] for r in rows}
        self.assertEqual({w: g for w, g, _ in imported}, expected)
        with tempfile.TemporaryDirectory() as d:
            sample = Path(d) / 'review.md'
            prefix = '| ID | 成语 | 当前等级 | 人工等级 |\n|---|---|---|---|\n'
            word = rows[0][1]
            sample.write_text(prefix + f'| {ids[word]} | {word} | 入门 | 基础 |\n')
            self.assertEqual(unreviewed_overrides(sample, ids, set()), [(word, '基础', '非教材审核表人工标注')])
            sample.write_text(prefix + f'| {ids[word]} | {word} | 入门 | 入门 |\n')
            self.assertEqual(len(unreviewed_overrides(sample, ids, set())), 1)
            sample.write_text(prefix + f'| {ids[word]} | {word} | 基础 | |\n')
            self.assertEqual(unreviewed_overrides(sample, ids, set()), [(word, '基础', '完整审核确认原等级')])
            for ident, grade in [(ids[word] + 1, '基础'), (ids[word], '待定')]:
                sample.write_text(prefix + f'| {ident} | {word} | 入门 | {grade} |\n')
                with self.assertRaises(ValueError):
                    unreviewed_overrides(sample, ids, set())

    def test_dictionary_fields_survive_reimport(self):
        content = json.loads((ROOT / 'assets/data/four_tier_content.json').read_text())
        details = json.loads((ROOT / 'data/textbook_additions.json').read_text())
        with sqlite3.connect(':memory:') as db:
            with sqlite3.connect(ROOT / 'assets/data/idiom_crossword.db') as source:
                source.backup(db)
            db.execute("UPDATE idioms SET explanation='编辑释义',derivation='教材审核保留',example='' WHERE id>29502")
            apply_content(db, content)
            for row in content['additions']:
                expected = tuple(details[row['word']][f] for f in ('explanation', 'derivation', 'example'))
                self.assertEqual(db.execute('SELECT explanation,derivation,example FROM idioms WHERE id=?', [row['id']]).fetchone(), expected)
                self.assertTrue(expected[0])
                self.assertNotIn('教材审核', expected[1])
            before = list(db.iterdump())
            apply_content(db, content)
            self.assertEqual(list(db.iterdump()), before)

    def test_reviewed_content_and_evidence_are_reproducible(self):
        paths = [ROOT / p for p in ['assets/data/four_tier_content.json',
                 'docs/reviews/textbook-idioms/four_tier_evidence.json',
                 'docs/specs/four_tier_content_report.md', 'data/idiom_ids.json']]
        before = [p.read_bytes() for p in paths]
        subprocess.run([sys.executable, str(ROOT / 'scripts/build_four_tier_content.py')], check=True, capture_output=True)
        self.assertEqual(before, [p.read_bytes() for p in paths])
        content = json.loads(paths[0].read_text())
        entries = {r[1]: r for r in content['entries']}
        self.assertEqual(len(entries), 29724)
        self.assertEqual(sum(r[4] for r in entries.values()), 29724)
        self.assertEqual(len(content['additions']), 222)
        self.assertTrue(all(len(w) == 4 for w in entries))
        review_dir = ROOT / 'docs/reviews/textbook-idioms'
        for r in reviewed_rows(review_dir / '有数据库ID_四字成语审核表.md'):
            self.assertEqual(entries[r[0]][2:4], list(tier(r)))
            self.assertTrue(entries[r[0]][4])
        accepted = {r[0] for r in reviewed_rows(review_dir / '无数据库ID_四字候选审核表.md') if r[-2] == '保留' or r[0] == '漫天风雪'}
        self.assertEqual({r['word'] for r in content['additions']}, accepted)
        self.assertEqual(entries['流水桃花'][2], 4)
        self.assertEqual(entries['蒙袂辑屦'][2], 4)
        self.assertEqual(entries['矞矞皇皇'][2], 2)
        overrides = reviewed_rows(review_dir / '人工分档覆盖表.md')
        names = ['入门', '基础', '拓展', '生僻']
        for word, grade, _ in overrides:
            self.assertEqual(entries[word][2:], [names.index(grade) + 1, 'manual', True])
        self.assertEqual(content['version'], 6)
        evidence = json.loads(paths[1].read_text())
        self.assertEqual(len(evidence['textbook']), 2898)
        for path, digest in evidence['sourceHashes'].items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest)
        legacy = json.loads((ROOT / 'assets/data/mainline_content.json').read_text())
        old = {w: t for key, t in [('expansion', 3), ('foundation', 2), ('intro', 1)] for w in legacy[key]}
        self.assertEqual(sum(entries[w][2] != t for w, t in old.items()), 154)


if __name__ == '__main__':
    unittest.main()

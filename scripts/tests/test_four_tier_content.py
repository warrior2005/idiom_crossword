import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from build_four_tier_content import reviewed_rows, tier


class FourTierContentTest(unittest.TestCase):
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
        self.assertEqual(sum(r[4] for r in entries.values()), 3069)
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
        self.assertEqual(content['version'], 4)
        evidence = json.loads(paths[1].read_text())
        self.assertEqual(len(evidence['textbook']), 2898)
        for path, digest in evidence['sourceHashes'].items():
            self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest)
        legacy = json.loads((ROOT / 'assets/data/mainline_content.json').read_text())
        old = {w: t for key, t in [('expansion', 3), ('foundation', 2), ('intro', 1)] for w in legacy[key]}
        self.assertEqual(sum(entries[w][2] != t for w, t in old.items()), 154)


if __name__ == '__main__':
    unittest.main()

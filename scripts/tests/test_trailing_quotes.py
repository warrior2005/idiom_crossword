import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from fix_trailing_quotes import fix_trailing_quotes


class TrailingQuotesTest(unittest.TestCase):
    def test_pairing_and_idempotence(self):
        cases = json.loads((ROOT / 'test/fixtures/trailing_quotes.json').read_text())
        for original, expected in cases:
            with self.subTest(original=original):
                self.assertEqual(fix_trailing_quotes(original), expected)
                self.assertEqual(fix_trailing_quotes(expected), expected)


if __name__ == '__main__':
    unittest.main()

import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('extract', Path(__file__).parents[1] / 'extract_textbook_idioms.py')
extract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(extract)


class ExtractionTest(unittest.TestCase):
    def setUp(self):
        self.trie = extract.make_trie(['万里无云', '一心一意', '画蛇添足', '心一'])

    def test_pinyin_keeps_original_evidence_offsets(self):
        text = '天空万\nwSn\n里\nlJ\n无\nwP\n云。'
        hit, = extract.matches(text, self.trie)
        self.assertEqual(hit['word'], '万里无云')
        self.assertEqual(text[hit['start']:hit['end']], hit['matched_text'])
        self.assertEqual(hit['flags'], ['跨行', '移除注音或拉丁字母'])

    def test_punctuation_and_page_numbers_are_boundaries(self):
        for text in ['一心，一意', '一心。\n一意', '一心12\n一意']:
            self.assertNotIn('一心一意', [h['word'] for h in extract.matches(text, self.trie)])

    def test_distinct_occurrences_and_nested_words_are_preserved(self):
        hits = list(extract.matches('一心一意，一心一意', self.trie))
        self.assertEqual([h['word'] for h in hits], ['一心一意', '心一', '一心一意', '心一'])
        self.assertEqual(len({h['start'] for h in hits}), 4)

    def test_split_lines_are_flagged_not_silently_confirmed(self):
        hit, = extract.matches('画蛇\n添足', self.trie)
        self.assertEqual(hit['flags'], ['跨行'])

    def test_unknown_four_character_phrase_is_not_invented(self):
        self.assertEqual(list(extract.matches('今天天晴', self.trie)), [])

    def test_unknown_candidates_do_not_claim_every_four_character_window(self):
        candidates = list(extract.unknown_candidates('层林尽染；百舸争流。天空万里无云。', {'百舸争流'}))
        self.assertEqual([c['word'] for c in candidates], ['层林尽染'])

    def test_book_order_does_not_confuse_publication_year(self):
        self.assertEqual(extract.book_meta(Path('2026春小学三年级下册.pdf')), (31, '小学3年级下册'))
        self.assertEqual(extract.book_meta(Path('小学4年级上册.pdf')), (40, '小学4年级上册'))
        self.assertEqual(extract.book_meta(Path('普通高中语文选择性必修上册.pdf')), (102, '高中选择性必修上册'))

    def test_markdown_context_cannot_inject_html_or_table_rows(self):
        self.assertEqual(extract.cell('<a>|\n'), '&lt;a&gt;&#124; ↵ ')


if __name__ == '__main__':
    unittest.main()

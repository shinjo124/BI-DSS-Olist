import tempfile
import unittest
from pathlib import Path

from import_staging import read_rows


class CsvTests(unittest.TestCase):
    def test_quoted_multiline_and_empty_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'data.csv'
            path.write_bytes(b'id,comment,optional\n1,"hello,\nworld",\n')
            self.assertEqual(list(read_rows(path, ['id', 'comment', 'optional'])),
                             [('1', 'hello,\nworld', None)])

    def test_missing_required_column_fails(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'data.csv'
            path.write_text('id\n1\n', encoding='utf-8')
            with self.assertRaises(ValueError):
                list(read_rows(path, ['id', 'missing']))

    def test_unclosed_quote_reports_file_and_line(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'broken.csv'
            path.write_text('id,comment\n1,"unfinished\n', encoding='utf-8')
            with self.assertRaisesRegex(ValueError, r'broken\.csv:.*line 2'):
                list(read_rows(path, ['id', 'comment']))


if __name__ == '__main__':
    unittest.main()

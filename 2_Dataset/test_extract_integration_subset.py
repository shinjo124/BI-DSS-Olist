import csv
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from extract_integration_subset import extract


class ExtractTests(unittest.TestCase):
    def test_related_rows_and_existing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, output = root / 'source', root / 'output'
            source.mkdir()
            files = {
                'olist_orders_dataset.csv': 'order_id,customer_id\na,c1\nb,c2\n',
                'olist_order_items_dataset.csv': 'order_id,product_id,seller_id\na,p1,s1\nb,p2,s2\n',
                'olist_order_payments_dataset.csv': 'order_id,payment_value\na,10\na,5\nb,9\n',
                'olist_order_reviews_dataset.csv': 'order_id,review_score\nb,3\n',
                'olist_customers_dataset.csv': 'customer_id\nc1\nc2\n',
                'olist_products_dataset.csv': 'product_id,product_category_name\np1,cat1\np2,cat2\n',
                'olist_sellers_dataset.csv': 'seller_id\ns1\ns2\n',
                'product_category_name_translation.csv': 'product_category_name,product_category_name_english\ncat1,one\ncat2,two\n',
            }
            for name, content in files.items():
                (source / name).write_text(content, encoding='utf-8')
            with patch('extract_integration_subset.ORDER_IDS', {'a'}):
                extract(source, output)
                with (output / 'olist_order_payments_dataset.csv').open(newline='', encoding='utf-8') as f:
                    self.assertEqual([r['payment_value'] for r in csv.DictReader(f)], ['10', '5'])
                with (output / 'olist_order_reviews_dataset.csv').open(newline='', encoding='utf-8') as f:
                    self.assertEqual(list(csv.DictReader(f)), [])
                with self.assertRaises(ValueError):
                    extract(source, output)


if __name__ == '__main__':
    unittest.main()

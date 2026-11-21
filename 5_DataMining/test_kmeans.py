import unittest

import pandas as pd

from kmeans import build_rfm


class RfmTests(unittest.TestCase):
    def test_counts_orders_once_and_excludes_cancelled_and_itemless_orders(self):
        orders = pd.DataFrame([
            ('a', 'c1', 'delivered', '2018-01-01'),
            ('b', 'c2', 'delivered', '2018-01-09'),
            ('c', 'c1', 'canceled', '2018-01-10'),
            ('d', 'c1', 'delivered', '2018-01-10'),
        ], columns=['order_id', 'customer_id', 'order_status', 'order_purchase_timestamp'])
        customers = pd.DataFrame([('c1', 'person'), ('c2', 'person')],
                                 columns=['customer_id', 'customer_unique_id'])
        items = pd.DataFrame([('a', 10), ('a', 5), ('b', 20), ('c', 100)],
                             columns=['order_id', 'price'])
        result = build_rfm(orders, customers, items, pd.Timestamp('2018-01-11')).iloc[0]
        self.assertEqual(result['frequency'], 2)
        self.assertEqual(result['monetary'], 35)
        self.assertEqual(result['recency'], 2)


if __name__ == '__main__':
    unittest.main()

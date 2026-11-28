import importlib.util
from pathlib import Path
import unittest

import pandas as pd


class RandomForestDataTests(unittest.TestCase):
    def module(self):
        path = Path(__file__).with_name('random_forest.py')
        self.assertTrue(path.exists(), 'Random Forest implementation is missing')
        spec = importlib.util.spec_from_file_location('olist_rf', path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_temporal_split_excludes_labels_unavailable_at_cutoff(self):
        module = self.module()
        data = pd.DataFrame({
            'order_delivered_customer_date': pd.to_datetime(['2018-03-30', '2018-03-31', '2018-04-01', '2018-06-30', '2018-07-01']),
            'review_answer_timestamp': pd.to_datetime(['2018-03-31', '2018-04-02', '2018-04-03', '2018-07-02', '2018-07-03']),
        })
        train, validation, test, exclusions = module.temporal_split(data, '2018-04-01', '2018-07-01', '2018-10-18')
        self.assertEqual(train.index.tolist(), [0])
        self.assertEqual(validation.index.tolist(), [2])
        self.assertEqual(test.index.tolist(), [4])
        self.assertEqual(exclusions['train_labels_after_cutoff'], 1)
        self.assertEqual(exclusions['validation_labels_after_cutoff'], 1)

    def test_feature_contract_excludes_reviews_ids_and_future_timestamps(self):
        module = self.module()
        self.assertIn('delivery_days', module.NUMERIC_FEATURES)
        self.assertIn('customer_state', module.CATEGORICAL_FEATURES)
        features = (module.NUMERIC_FEATURES + module.CATEGORICAL_FEATURES +
                    module.EXTRA_NUMERIC + module.EXTRA_CATEGORICAL)
        for name in features:
            self.assertFalse(any(token in name for token in ['review', 'order_id', 'timestamp', 'unique_id']))

    def test_enrichment_preserves_order_grain_and_handles_missing_geocodes(self):
        module = self.module()
        items = pd.DataFrame({
            'order_id': ['a', 'a', 'b'], 'order_item_id': [2, 1, 1],
            'product_category_name': ['toys', 'books', 'toys'],
            'product_weight_g': [100, 200, None],
            'seller_zip_code_prefix': [20, 10, 30],
            'customer_zip_code_prefix': [10, 10, 10],
        })
        geocodes = pd.DataFrame({
            'geolocation_zip_code_prefix': [10, 10, 20],
            'geolocation_lat': [0, 0, 0], 'geolocation_lng': [0, 0, 1],
        })
        self.assertTrue(hasattr(module, 'aggregate_delivery_features'))
        result = module.aggregate_delivery_features(items, geocodes)
        self.assertEqual(result.index.tolist(), ['a', 'b'])
        self.assertEqual(result.loc['a', 'first_category'], 'books')
        self.assertEqual(result.loc['a', 'total_weight_g'], 300)
        self.assertAlmostEqual(result.loc['a', 'max_seller_distance_km'], 111.2, places=1)
        self.assertTrue(pd.isna(result.loc['b', 'max_seller_distance_km']))
        self.assertTrue(pd.isna(result.loc['b', 'total_weight_g']))

    def test_alert_budget_uses_same_order_id_tiebreak_for_all_scores(self):
        module = self.module()
        data = pd.DataFrame({'order_id': ['d', 'b', 'a', 'c'], 'target': [0, 1, 1, 0]})
        self.assertTrue(hasattr(module, 'alert_budget'))
        self.assertEqual(module.alert_budget(data, [0.1, 0.8, 0.8, 0.8], 0.25),
                         {'alerts': 1, 'hits': 1, 'alert_precision': 1.0, 'alert_recall': 0.5})


if __name__ == '__main__':
    unittest.main()

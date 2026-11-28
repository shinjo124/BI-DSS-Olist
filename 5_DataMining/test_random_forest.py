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
        for name in module.NUMERIC_FEATURES + module.CATEGORICAL_FEATURES:
            self.assertFalse(any(token in name for token in ['review', 'order_id', 'timestamp', 'unique_id']))


if __name__ == '__main__':
    unittest.main()

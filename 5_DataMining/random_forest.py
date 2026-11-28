"""Predict an order review <=2 at delivery; temporal evaluation, no live deployment."""
import argparse
import hashlib
import json
from pathlib import Path
import platform

import joblib
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import sklearn
from sklearn.compose import ColumnTransformer
from sklearn.dummy import DummyClassifier
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.metrics import (average_precision_score, confusion_matrix, f1_score,
                             precision_score, recall_score, roc_auc_score,
                             PrecisionRecallDisplay, ConfusionMatrixDisplay)
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder

NUMERIC_FEATURES = ['delivery_days', 'late_days', 'expected_delivery_days', 'price',
                    'freight', 'item_count', 'seller_count', 'category_count',
                    'purchase_month', 'purchase_weekday']
CATEGORICAL_FEATURES = ['customer_state']


def build_cohort(data_directory, snapshot):
    def read(name):
        return pd.read_csv(data_directory / f'olist_{name}_dataset.csv')
    orders, reviews = read('orders'), read('order_reviews')
    for col in ['order_purchase_timestamp', 'order_delivered_customer_date', 'order_estimated_delivery_date']:
        orders[col] = pd.to_datetime(orders[col])
    for col in ['review_creation_date', 'review_answer_timestamp']:
        reviews[col] = pd.to_datetime(reviews[col])
    reviews = reviews.sort_values(['review_creation_date', 'review_answer_timestamp', 'review_id', 'review_score'],
                                  ascending=False, na_position='last').drop_duplicates('order_id')
    items = read('order_items').merge(read('products')[['product_id', 'product_category_name']],
                                      on='product_id', validate='many_to_one')
    items['product_category_name'] = items['product_category_name'].fillna('Unknown')
    totals = items.groupby('order_id').agg(price=('price', 'sum'), freight=('freight_value', 'sum'),
                                          item_count=('order_item_id', 'size'), seller_count=('seller_id', 'nunique'),
                                          category_count=('product_category_name', 'nunique'))
    scoped = orders[(~orders.order_status.isin(['canceled', 'unavailable'])) &
                    (orders.order_purchase_timestamp < snapshot)].merge(totals, on='order_id', validate='one_to_one')
    scoped = scoped.merge(reviews[['order_id', 'review_score', 'review_answer_timestamp']],
                          on='order_id', how='left', validate='one_to_one')
    eligible = scoped.order_delivered_customer_date.notna() & scoped.review_score.notna() & (
        scoped.review_answer_timestamp >= scoped.order_delivered_customer_date)
    cohort = scoped.loc[eligible].copy()
    cohort = cohort.merge(read('customers')[['customer_id', 'customer_state']], on='customer_id', validate='many_to_one')
    purchase = cohort.order_purchase_timestamp.dt.normalize()
    delivery = cohort.order_delivered_customer_date.dt.normalize()
    estimated = cohort.order_estimated_delivery_date.dt.normalize()
    cohort['delivery_days'] = (delivery - purchase).dt.days
    cohort['late_days'] = (delivery - estimated).dt.days
    cohort['expected_delivery_days'] = (estimated - purchase).dt.days
    cohort['purchase_month'] = purchase.dt.month
    cohort['purchase_weekday'] = purchase.dt.day_of_week + 1
    cohort['target'] = (cohort.review_score <= 2).astype(int)
    return cohort, {'scoped_orders': len(scoped), 'cohort_orders': len(cohort),
                     'cohort_excluded': int((~eligible).sum()), 'low_reviews': int(cohort.target.sum())}


def temporal_split(data, train_cutoff, test_cutoff, snapshot):
    train_cutoff, test_cutoff, snapshot = map(pd.Timestamp, [train_cutoff, test_cutoff, snapshot])
    if not train_cutoff < test_cutoff < snapshot:
        raise ValueError('Require train cutoff < test cutoff < snapshot')
    delivered, answered = data.order_delivered_customer_date, data.review_answer_timestamp
    train_period = delivered < train_cutoff
    validation_period = (delivered >= train_cutoff) & (delivered < test_cutoff)
    test_period = (delivered >= test_cutoff) & (delivered < snapshot)
    return (data[train_period & (answered <= train_cutoff)].copy(),
            data[validation_period & (answered <= test_cutoff)].copy(),
            data[test_period & (answered < snapshot)].copy(),
            {'train_labels_after_cutoff': int((train_period & (answered > train_cutoff)).sum()),
             'validation_labels_after_cutoff': int((validation_period & (answered > test_cutoff)).sum()),
             'test_labels_unavailable_at_snapshot': int((test_period & ~(answered < snapshot)).sum()),
             'deliveries_at_or_after_snapshot': int((delivered >= snapshot).sum())})


def evaluate(y, probability, threshold):
    prediction = (probability >= threshold).astype(int)
    return {'orders': len(y), 'positives': int(y.sum()), 'threshold': float(threshold),
            'precision': precision_score(y, prediction, zero_division=0),
            'recall': recall_score(y, prediction, zero_division=0),
            'f1': f1_score(y, prediction, zero_division=0),
            'roc_auc': roc_auc_score(y, probability) if y.nunique() == 2 else None,
            'average_precision': average_precision_score(y, probability) if y.sum() else None,
            'confusion_matrix_tn_fp_fn_tp': confusion_matrix(y, prediction, labels=[0, 1]).ravel().tolist()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data', type=Path, default=Path('2_Dataset/raw'))
    parser.add_argument('--output', type=Path, default=Path('5_DataMining/results/random_forest'))
    parser.add_argument('--train-cutoff', default='2018-04-01')
    parser.add_argument('--test-cutoff', default='2018-07-01')
    parser.add_argument('--snapshot', default='2018-10-18')
    args = parser.parse_args()
    cohort, counts = build_cohort(args.data, pd.Timestamp(args.snapshot))
    train, validation, test, exclusions = temporal_split(cohort, args.train_cutoff, args.test_cutoff, args.snapshot)
    for name, part in [('train', train), ('validation', validation), ('test', test)]:
        if part.empty or part.target.nunique() != 2:
            raise ValueError(f'{name} needs both label classes')
    features = NUMERIC_FEATURES + CATEGORICAL_FEATURES
    preprocessing = ColumnTransformer([
        ('numeric', SimpleImputer(strategy='median'), NUMERIC_FEATURES),
        ('category', Pipeline([('impute', SimpleImputer(strategy='most_frequent')),
                               ('encode', OneHotEncoder(handle_unknown='ignore'))]), CATEGORICAL_FEATURES)])
    model = Pipeline([('preprocessing', preprocessing), ('forest', RandomForestClassifier(
        n_estimators=200, max_depth=14, min_samples_leaf=10, class_weight='balanced_subsample',
        random_state=42, n_jobs=-1))])
    model.fit(train[features], train.target)
    validation_probability = model.predict_proba(validation[features])[:, 1]
    thresholds = np.arange(10, 91, 5) / 100
    scores = [evaluate(validation.target, validation_probability, threshold) for threshold in thresholds]
    # F1 balances precision/recall for this academic comparison; costs are not estimated.
    threshold = max(scores, key=lambda result: (result['f1'], result['threshold']))['threshold']
    test_probability = model.predict_proba(test[features])[:, 1]
    baseline = DummyClassifier(strategy='most_frequent').fit(train[features], train.target)
    baseline_probability = baseline.predict_proba(test[features])[:, 1]
    metrics = {'random_forest_validation': evaluate(validation.target, validation_probability, threshold),
               'random_forest_test': evaluate(test.target, test_probability, threshold),
               'majority_baseline_test': evaluate(test.target, baseline_probability, 0.5)}
    output = args.output
    output.mkdir(parents=True, exist_ok=True)
    pd.DataFrame(scores).drop(columns='confusion_matrix_tn_fp_fn_tp').to_csv(output / 'threshold_validation.csv', index=False)
    pd.DataFrame({'feature': model['preprocessing'].get_feature_names_out(),
                  'impurity_importance': model['forest'].feature_importances_}).sort_values(
                      'impurity_importance', ascending=False).to_csv(output / 'feature_importance.csv', index=False)
    slices = []
    for month, part in test.assign(delivery_month=test.order_delivered_customer_date.dt.strftime('%Y-%m')).groupby('delivery_month'):
        result = evaluate(part.target, model.predict_proba(part[features])[:, 1], threshold)
        slices.append({'delivery_month': month, **result})
    pd.DataFrame(slices).to_csv(output / 'test_month_metrics.csv', index=False)
    hashes = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
              for path in sorted(args.data.glob('olist_*_dataset.csv'))}
    summary = {'prediction_time': 'delivery', 'target': 'selected review score <=2',
               'seed': 42, 'train_cutoff': args.train_cutoff, 'test_cutoff': args.test_cutoff,
               'snapshot_exclusive': args.snapshot, 'cohort': counts, 'cutoff_exclusions': exclusions,
               'split_counts': {name: {'orders': len(part), 'low_reviews': int(part.target.sum())}
                                for name, part in [('train', train), ('validation', validation), ('test', test)]},
               'features': features, 'metrics': metrics, 'source_sha256': hashes,
               'versions': {'python': platform.python_version(), 'pandas': pd.__version__, 'sklearn': sklearn.__version__},
               'limitations': ['Review answer time is an imperfect label-availability proxy.',
                               'Latest review selection uses the final snapshot; historical revisions cannot be reconstructed.',
                               'No causal or production-readiness claims; test period is short and historical.',
                               'Customer state and product categories are snapshot attributes without change histories.',
                               'Threshold maximizes validation F1; business intervention costs are unknown.']}
    (output / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    joblib.dump({'pipeline': model, 'threshold': threshold, 'features': features}, output / 'model.joblib')
    fig, axes = plt.subplots(1, 2, figsize=(11, 4))
    ConfusionMatrixDisplay.from_predictions(test.target, test_probability >= threshold, ax=axes[0], colorbar=False)
    PrecisionRecallDisplay.from_predictions(test.target, test_probability, ax=axes[1], name='Random Forest')
    axes[0].set_title('Held-out deliveries: confusion matrix')
    axes[1].axhline(test.target.mean(), color='gray', linestyle='--', label='Prevalence')
    axes[1].legend(); fig.tight_layout(); fig.savefig(output / 'evaluation.png', dpi=160); plt.close(fig)
    print(json.dumps({'cohort': counts, 'split_counts': summary['split_counts'], 'metrics': metrics}, indent=2))


if __name__ == '__main__':
    main()

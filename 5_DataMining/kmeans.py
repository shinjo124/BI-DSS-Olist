"""Reproducible customer RFM clustering on the Olist snapshot."""

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from sklearn.cluster import KMeans
from sklearn.metrics import adjusted_rand_score, silhouette_score
from sklearn.preprocessing import StandardScaler


def build_rfm(orders, customers, items, snapshot):
    orders = orders.copy()
    orders['order_purchase_timestamp'] = pd.to_datetime(orders['order_purchase_timestamp'])
    orders = orders[(~orders['order_status'].isin(['canceled', 'unavailable'])) &
                    (orders['order_purchase_timestamp'] < snapshot)]
    values = items.groupby('order_id', as_index=False)['price'].sum()
    orders = orders.merge(values, on='order_id', how='inner', validate='one_to_one')
    orders = orders.merge(customers[['customer_id', 'customer_unique_id']],
                          on='customer_id', validate='many_to_one')
    rfm = orders.groupby('customer_unique_id').agg(
        last_order=('order_purchase_timestamp', 'max'),
        frequency=('order_id', 'nunique'), monetary=('price', 'sum'))
    rfm['recency'] = (snapshot.normalize() - rfm['last_order'].dt.normalize()).dt.days
    return rfm[['recency', 'frequency', 'monetary']]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--data', type=Path, default=Path('2_Dataset/raw'))
    parser.add_argument('--output', type=Path, default=Path('5_DataMining/results'))
    parser.add_argument('--snapshot', default='2018-10-18', help='Exclusive snapshot date')
    args = parser.parse_args()
    def read(name):
        return pd.read_csv(args.data / f'olist_{name}_dataset.csv')

    rfm = build_rfm(read('orders'), read('customers'), read('order_items'),
                    pd.Timestamp(args.snapshot))
    if (rfm[['recency', 'frequency', 'monetary']] < 0).any().any():
        raise ValueError('RFM values must be non-negative before log1p')
    transformed = StandardScaler().fit_transform(np.log1p(rfm))
    metrics = []
    models = {}
    for k in range(2, 9):
        model = KMeans(n_clusters=k, random_state=42, n_init=10).fit(transformed)
        models[k] = model
        metrics.append({'k': k, 'inertia': model.inertia_,
                        'silhouette': silhouette_score(transformed, model.labels_,
                                                       sample_size=min(5000, len(rfm)),
                                                       random_state=42)})
    chosen = max(metrics, key=lambda row: row['silhouette'])['k']
    rfm['cluster'] = models[chosen].labels_
    stability = []
    for seed in [1, 7, 21, 99]:
        candidate = KMeans(n_clusters=chosen, random_state=seed, n_init=10).fit(transformed)
        stability.append({'seed': seed, 'adjusted_rand_index':
                          adjusted_rand_score(rfm['cluster'], candidate.labels_)})
    args.output.mkdir(parents=True, exist_ok=True)
    pd.DataFrame(metrics).to_csv(args.output / 'kmeans_metrics.csv', index=False)
    pd.DataFrame(stability).to_csv(args.output / 'kmeans_stability.csv', index=False)
    profiles = rfm.groupby('cluster').agg(customers=('frequency', 'size'),
                                          recency=('recency', 'mean'), frequency=('frequency', 'mean'),
                                          monetary=('monetary', 'mean'))
    profiles.to_csv(args.output / 'kmeans_profiles.csv')
    fig, axes = plt.subplots(1, 2, figsize=(11, 4))
    axes[0].plot([row['k'] for row in metrics], [row['inertia'] for row in metrics], marker='o')
    axes[0].set(xlabel='Number of clusters (k)', ylabel='Inertia', title='Elbow')
    axes[1].plot([row['k'] for row in metrics], [row['silhouette'] for row in metrics], marker='o')
    axes[1].set(xlabel='Number of clusters (k)', ylabel='Sampled silhouette', title='Silhouette')
    fig.tight_layout()
    fig.savefig(args.output / 'kmeans_selection.png', dpi=160)
    plt.close(fig)
    (args.output / 'kmeans_summary.json').write_text(json.dumps({
        'snapshot_exclusive': args.snapshot, 'customers': len(rfm), 'seed': 42,
        'silhouette_sample_size': min(5000, len(rfm)), 'selected_k': chosen,
        'selection': 'highest sampled silhouette among k=2..8',
    }, indent=2), encoding='utf-8')
    print(f'Customers: {len(rfm)}; selected k: {chosen}; results: {args.output}')


if __name__ == '__main__':
    main()

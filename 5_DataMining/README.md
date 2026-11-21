# Customer segmentation with K-Means

Run from the repository root with Python 3.13 after extracting the checked Olist snapshot into `2_Dataset/raw/`.

```powershell
python -m venv .venv
.\.venv\Scripts\python -m pip install -r 5_DataMining/requirements.txt
.\.venv\Scripts\python -m unittest discover -s 5_DataMining -p test_kmeans.py
.\.venv\Scripts\python 5_DataMining/kmeans.py
```

Use `--data`, `--output`, and `--snapshot` to choose paths and an exclusive reference date. The default snapshot is 2018-10-18. Orders before that date with at least one item and status other than canceled/unavailable are grouped by `customer_unique_id`. Recency is calendar days since the most recent purchase, frequency is distinct order count, and monetary is the sum of item prices excluding freight. Item prices are aggregated by order before customer joins. Features are log1p transformed and standardized. Models for k=2–8 use seed 42 and ten initializations. Silhouette is measured on a fixed sample of up to 5,000 customers; the highest sampled silhouette selects k. Outputs are aggregate metrics, profiles, and run settings under `results/`.

On this snapshot, median recency is 269 days (range 45–774), and median item spend is BRL 89.89 (95th percentile BRL 420.00; maximum BRL 13,440.00). Frequency is highly concentrated: 92,096 customers have one order, 2,651 have two, and 236 have three or more. The large spend tail supports inspecting the log-transformed data, but transformation does not remove outliers or prove that the clusters are useful for a business decision. The minimum recency of 45 days reflects the chosen reference date and the latest observed eligible purchase, not live customer activity.

On the checked snapshot, this first run contains 94,983 customers and selects k=3 with sampled silhouette 0.368. The clusters contain 59,372, 32,724, and 2,887 customers. The third cluster corresponds to customers with repeat purchases, while the first two have frequency exactly one. These are descriptive profiles, not evidence of loyalty or a causal effect. The k=4 silhouette is close (0.366); inspect stability and business usefulness before claiming k=3 is uniquely optimal. This is exploratory clustering on historical data, not a predictive test-set evaluation.

For the selected k=3, repeated fits with seeds 1, 7, 21, and 99 have adjusted Rand index 0.982–1.000 relative to seed 42, using all customer assignments. This checks initialization sensitivity on the same data and preprocessing; it does not establish stability across time periods or different snapshots. `kmeans_selection.png` plots inertia and the fixed-sample silhouette, while `kmeans_stability.csv` records the seed comparisons.

## Interpretation for the report

| Cluster | Customers | Mean recency (days) | Mean orders | Mean item spend (BRL) | Description |
| --- | ---: | ---: | ---: | ---: | --- |
| 0 | 59,372 | 375.9 | 1.00 | 134.51 | Older one-order customers |
| 1 | 32,724 | 131.0 | 1.00 | 145.39 | More recent one-order customers |
| 2 | 2,887 | 271.4 | 2.11 | 259.95 | Customers with multiple orders |

Recency is measured from the exclusive snapshot date; spend is the sum of item prices, excluding freight. Cluster numbers are arbitrary and may change on another fit. The repeat group is only 3.04% of the cohort, so the frequency feature separates a small minority. The mean spend for that group covers multiple orders and should not be interpreted as a higher average order value. These results describe the available historical snapshot; they do not show future retention, customer loyalty, or the effect of an intervention.

The assignments were checked directly: clusters 0 and 1 each have frequency 1 for every customer; cluster 2 has frequencies from 2 to 16 and contains no single-order customer. This check applies to the saved model settings and snapshot.

The raw-CSV RFM inputs were also compared customer by customer with an independent aggregation of the loaded warehouse for the same cutoff and scope. All 94,983 customer IDs, recency values, frequencies, and monetary totals matched (monetary comparison tolerance: BRL 0.000001). This checks the generated RFM values against the warehouse; both derive from the same source snapshot.

The analysis was rerun into a separate directory in the existing local Python environment. The saved metrics, profiles, and stability tables matched the rerun to a tolerance of 1e-10. The listed dependencies were also installed in a fresh local Python 3.13 environment; the unit test and `pip check` passed there. Reproduction on the second machine remains open.

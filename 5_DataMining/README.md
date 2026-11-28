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

## Random Forest for low reviews at delivery

Run `.\.venv\Scripts\python 5_DataMining/random_forest.py` from the repository root, using the same CSV snapshot and Python environment. The command writes the fitted pipeline and threshold, validation scores, holdout metrics, feature importance, and figures to [results/random_forest](results/random_forest). The generated model can be reproduced locally and is excluded from Git.

Each row is one eligible order. The label is the selected review score of 1 or 2. We use answer time as the availability proxy. Train on deliveries before 1 April 2018 whose review was available by the cutoff. Use deliveries from April through June whose review was available by 1 July to pick the threshold. Evaluate on deliveries from July through the exclusive 18 October snapshot cutoff with labels available before that date. These splits contain 56,818, 19,203, and 13,747 orders. The cutoffs excluded 625, 771, and 6 otherwise eligible labels, respectively.

The chosen validation threshold was 0.55. On the holdout, the forest reached precision 25.1%, recall 22.7%, F1 0.239, ROC AUC 0.626, and average precision 0.180. The always-majority baseline reached F1 0.000, ROC AUC 0.500, and average precision 0.082. The forest flagged 1,022 orders and found 257 of 1,131 low reviews. That is enough to show some ranking signal but leaves 874 low reviews missed. The snapshot, short holdout, and possible review revisions limit interpretation. The model uses only signals available at delivery and supports retrospective exploration.

### Delivery feature comparison

Run `./.venv/Scripts/python 5_DataMining/random_forest.py --compare` to reproduce [the comparison](results/random_forest/model_comparison.csv) on the same time splits. The enriched models add freight as a share of order value, total product weight, the first item's category, and the maximum straight-line distance from any seller to the customer using median ZIP-prefix coordinates. The late-delivery rule ranks by days past the promise date. Model thresholds use validation F1. The top-5% check ranks each split by score and breaks ties by order ID.

| Method | Validation average precision | Holdout average precision | Holdout low reviews found in 688 alerts |
| --- | ---: | ---: | ---: |
| Late-delivery rule | 0.1002 | 0.0887 | 75 |
| Original Random Forest | 0.2302 | 0.1804 | 206 |
| Enriched Random Forest | 0.2326 | 0.1817 | 195 |
| Enriched gradient boosting | 0.2308 | 0.1816 | 195 |

We retained the original forest for the project. Enrichment produced a small gain in overall ranking on the previously examined holdout, while the original found the most low reviews at the fixed alert budget. The original found 206 of 1,131 low reviews at that budget, giving 29.9% precision and 18.2% recall.

# Olist Business Intelligence Final Project

Working draft of Lam's sections. The native SSIS package has run on the full snapshot in the local Visual Studio debugger; the earlier package was tested on the four-order subset and full snapshot. Cube, Power BI, MDX, and Excel results are not yet available for reconciliation. Replace this notice only after the team verifies those deliverables. All values below describe the checked Olist snapshot and the stated filters.

## Data selection and warehouse loading

The project uses the Brazilian e-commerce public dataset provided by Olist. Eight CSV files provide order, customer, item, product, category translation, seller, payment, and review data. Product descriptions, review text, and the geolocation file are outside the present analysis. The source archive and individual file hashes are recorded in `2_Dataset/DATASET_PROFILE.md` so the team can use the same snapshot.

The warehouse includes orders with at least one item whose status is neither canceled nor unavailable. Other statuses remain in scope. The purchase calendar date is the common analysis date. The resulting warehouse contains 98,199 orders and 112,101 item rows. Item revenue is BRL 13,494,400.74 and freight is BRL 2,241,126.29. Revenue is the sum of item prices excluding freight; it is not settled accounting revenue.

The native SSIS package imports the required CSV fields into typed staging tables using Data Flows. It validates required lookups and orphan records, then loads dimensions and facts through separate Data Flows. A package transaction covers the staging and warehouse reload; an invalid-payment test rolled back the previous warehouse state. Malformed source rows stop the import; a separate rejected-row file is not yet implemented. The project also contains an alternative package that orchestrates the Python importer and SQL procedure in separate transactions. Both packages implement the same ETL process; they are alternatives, not consecutive stages.

The model keeps sales at item grain, payments at payment-row grain, and delivery and reviews at order grain. This avoids multiplying sales when an order has several payments or reviews. The selected review is the latest according to creation time, answer time, review ID, and score as descending tie-breakers. Missing reviews remain missing rather than being treated as zero. Payment analysis uses actual payment rows, so an order using multiple methods contributes to each applicable method.

The full warehouse was loaded twice in an isolated local test database using the importer and SQL procedure. The native SSIS package also loaded the full snapshot successfully in the local Visual Studio debugger. Eligible staging rows reconciled with warehouse sales, payments, and orders; category and seller aggregates also matched independently aggregated staging data. The native staging tables matched the earlier full-data staging tables in both directions and by row count. A reproducible run on the second machine remains open.

## Customer segmentation using K Means

The exploratory analysis groups historical customers by recency, frequency, and monetary value. The exclusive reference date is 18 October 2018. Customers are identified by `customer_unique_id`; frequency counts distinct eligible orders and monetary value sums item prices excluding freight. Items are aggregated to order before joining customers. Recency is the number of calendar days since the last purchase. The three features are transformed with `log1p` and standardized before clustering.

Median recency is 269 days and median item spend is BRL 89.89; the 95th percentile of spend is BRL 420.00 and the maximum is BRL 13,440.00. Of the 94,983 customers, 92,096 have one order, 2,651 have two, and 236 have three or more. This concentration in frequency and the long spend tail influence the clustering. The minimum recency is 45 days because of the reference date and the latest observed eligible purchase; it does not describe current customer activity.

Models with k from 2 to 8 were fitted with seed 42 and ten initializations. The highest silhouette on a fixed sample of 5,000 customers selected k = 3, with silhouette 0.368. The score for k = 4 was close at 0.366, so the result should not be described as uniquely optimal. Repeating k = 3 with four other seeds produced adjusted Rand indices from 0.982 to 1.000 relative to the original fit. This measures initialization sensitivity on the same data, not stability over time.

| Cluster | Customers | Mean recency in days | Mean orders | Mean item spend BRL |
| --- | ---: | ---: | ---: | ---: |
| 0 | 59,372 | 375.9 | 1.00 | 134.51 |
| 1 | 32,724 | 131.0 | 1.00 | 145.39 |
| 2 | 2,887 | 271.4 | 2.11 | 259.95 |

The first two groups consist of customers with one order and differ mainly in recency. The third contains customers with repeat purchases and represents 3.04% of the 94,983 customers in scope. Its mean spend covers multiple orders and should not be interpreted as average order value. The clusters describe historical behavior in this snapshot; they do not establish loyalty, future retention, or a causal effect. Code, candidate metrics, profiles, and the selection chart are in `5_DataMining/`.

## Sections awaiting integration

The team still needs verified cube construction, ten SSAS and Power BI analyses, ten MDX queries, Excel Pivot analyses, the second mining algorithm, cross-tool reconciliation, and the final report review. Add actual results and evidence supplied by each owner before producing the submission DOCX and PDF. Verify the page limit and instructor access to the Drive submission.

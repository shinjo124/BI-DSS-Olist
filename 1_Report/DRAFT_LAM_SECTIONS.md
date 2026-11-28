# Olist Business Intelligence Final Project

Lam and Kiet prepared this business intelligence study of the Brazilian Olist ecommerce snapshot. The warehouse supports analysis of sales, payments, delivery and reviews, and the mining experiments describe customer behavior and estimate low review risk at delivery. Orders, item sales and payment rows use separate grains so that an order with multiple items or payment methods does not inflate totals.

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

## Analysis Services cube

The processed Olist cube uses the Sales, Orders and Payments measure groups and six dimensions. Date, Customer and Order relate to all three groups. Product and Seller relate directly to Sales and through Sales to Orders. The latter relationships let an order contribute one review within a selected category or seller even if it contains several items in that group. Category or seller order counts can therefore overlap at the group level. Payment has a direct relationship only to the Payments group.

Calendar attributes sort by numeric key. Year and month keys support chronological comparison across years. The cube calculates payment share by dividing by all methods under the same date and customer filters. The delivery and review averages use their eligible counts. Product and seller were checked individually for order-level analysis. Combining both filters can intersect orders without proving that the selected product and seller refer to the same line item, so the published analyses avoid that combination.

The four-order subset returned BRL 400.00 in payments, with credit card at 63.885%, boleto at 31.635% and voucher at 4.480%. On the full snapshot the cube returned 98,199 orders, BRL 13,494,400.74 item revenue, BRL 15,738,221.95 payments and 97,467 reviewed orders. The ten MDX exports match SQL by row keys and measures. Each result was also run in the native SSAS Browser. For Q4, we selected the payment fields in the visual designer. The other nine ran in the Browser's MDX editor. Screenshots accompany the cube project.

## Ten business questions

| Question | Finding and interpretation |
| --- | --- |
| Q1 Revenue and orders by quarter | The covered 2018 period produced BRL 7.34 million and 53,531 orders. The 2017 total was BRL 6.11 million and 44,375 orders. Compare matched windows for year-over-year conclusions because the 2018 extract is incomplete. |
| Q2 Top categories | Health and beauty leads with BRL 1.26 million across 9,634 items, followed by watches and gifts. Revenue ranks product value and does not measure margin. |
| Q3 Top customer states | São Paulo leads with BRL 5.16 million and 41,125 orders. Its average item value per order is BRL 125.57 compared with Rio de Janeiro's BRL 142.68. Volume and order value tell different stories. |
| Q4 Payment method share | Credit cards account for 78.468% of BRL 15.74 million in payments. Boleto accounts for 17.959%. The shares measure amounts, with orders using several methods contributing to each participating method. |
| Q5 Monthly revenue growth | February 2017 grew 103.97% from January. January's growth used a December 2016 base of BRL 10.90, so its percentage is unstable and unsuitable for a general growth claim. |
| Q6 Category reviews | Office furniture has the lowest average among eligible categories, at 3.618 across 1,262 reviewed orders. Review scores belong to the whole order. |
| Q7 Delivery by customer state | Alagoas averaged 24.50 days and 21.41% late among 397 eligible deliveries. Counts accompany the rates to show the size of each state sample. |
| Q8 Top sellers | The top seller, 4869f7a5dfa277a7dca6462dcf3b52b2 in São Paulo, recorded BRL 229,237.63 and 1,131 orders. Its 4.136 average describes orders that include this seller. |
| Q9 Regional freight ratio | In January–August 2018, the North had a ratio of 23.87% and the Southeast 15.48%. The respective 2017 ratios for the same months were 20.62% and 14.77%. The denominator is item revenue. |
| Q10 Weekday and payment | Monday credit-card purchases total BRL 1,982,261.37. The full weekday matrix groups by purchase weekday and actual payment method. |

Three live Excel PivotTables cover Q1 annual orders and revenue, Q4 payment method share, and Q7 delivery by state. Refreshing on the local SSAS instance reproduced the three primary totals. Full results are in `4_SSAS/MDX/results/` and the live workbook is in `4_SSAS/Excel/`.

Two Power BI projects each pair a chart with a detail table for every question. The editable model imports selected columns from all warehouse rows across six dimensions and three fact tables, with 12 relationships. The warehouse calculations matched the SSAS exports. The live project queries the SSAS cube directly. Power BI Desktop confirmed the connection and returned BRL 15,738,221.95 in total payments on Q4, with credit cards accounting for 78.468%.

## Low review prediction using Random Forest

The forest predicts a selected score of 1 or 2 at delivery. Features describe actual and scheduled delivery duration, lateness, basket size and value, seller and category counts, purchase calendar fields and customer state. Reviews and their timestamps define eligibility and labels. The features are computed per order before the split.

We trained on 56,818 deliveries before 1 April 2018. We chose the threshold on 19,203 deliveries from April through June and tested on 13,747 later deliveries with an observed label before the 18 October snapshot cutoff. Labels arriving after the relevant cutoff excluded 625 training candidates, 771 validation candidates and 6 test candidates. Imputation and encoding were fitted using training rows. The threshold of 0.55 maximized validation F1 over the fixed grid.

| Test metric | Random Forest | Majority baseline |
| --- | ---: | ---: |
| Precision | 25.1% | 0.0% |
| Recall | 22.7% | 0.0% |
| F1 | 0.239 | 0.000 |
| ROC AUC | 0.626 | 0.500 |
| Average precision | 0.180 | 0.082 |
| True negatives | 11,851 | 12,616 |
| False positives | 765 | 0 |
| False negatives | 874 | 1,131 |
| True positives | 257 | 0 |

The holdout shows modest ranking signal and low recall at the selected threshold. Review answer time only approximates when the label became observable, and the final snapshot cannot reconstruct past review revisions. The short holdout and absence of intervention costs limit operational conclusions.

## Reproduction and remaining checks

Use the verified snapshot and one SSIS package per load. Process the cube, run the ten MDX files and compare the output with SQL. Refresh the three live PivotTables. The subset and full-snapshot results are saved separately. Second-machine reproduction and instructor Drive access still require verification.

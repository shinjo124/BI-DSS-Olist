# Olist Dataset Profile — 17 November 2026

## Source and snapshot

The archive was downloaded from the [Olist dataset on Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce). The source page lists the **CC BY-NC-SA 4.0** license. The archive was downloaded on 17 November 2026; its SHA-256 is `967e41e04fc306fe604e2a693f488995a8b41e5047418f8a5c8e4abd6deca784`, and ZIP integrity validation passed. A Kaggle version number could not be confirmed from the archive metadata, so the hash identifies this snapshot. Kaggle may serve a newer archive later.

The checked archive `olist-download.zip` is in Drive under `2_Dataset/`. The extracted CSVs and archive in the local workspace are ignored by Git. Teammates should download the Drive copy and verify its hash before use. Access for each teammate and the instructor has not been verified.

| CSV | Rows | SHA-256 |
| --- | ---: | --- |
| `olist_customers_dataset.csv` | 99,441 | `983a422239e1712ded753b3bf9ecf47dc73f144d306029dcfa99e70a226883d2` |
| `olist_geolocation_dataset.csv` | 1,000,163 | `b514f6fc991b9566aeba02aa5d67e2c3630f034b60a0e05aa0d082a3b66d88d6` |
| `olist_order_items_dataset.csv` | 112,650 | `0bc4d068c4fe38cbb01bd90e8746e3c613fe7b4baef75fab7b0e329701c3e279` |
| `olist_order_payments_dataset.csv` | 103,886 | `4f713964f2815dbbaa40b9488268c55aac3627bfce5aa96cf58d1f3616de3cc0` |
| `olist_order_reviews_dataset.csv` | 99,224 | `012b61c7593e34f51fa614efdf802b9c7056ce6aae5307ddb93236e7cfc797d7` |
| `olist_orders_dataset.csv` | 99,441 | `8df58ef3d2d7e9944010f7beecd9b75367f5588ec6e3c91cec19ae3345ef9ecf` |
| `olist_products_dataset.csv` | 32,951 | `3e6569628a17fbc75fd206ee357b59e20364b9afa90f5b6cd5b4d624c58aa9cc` |
| `olist_sellers_dataset.csv` | 3,095 | `1f643d2b950373b85735e7794b20986f528d7a000432e7c6f9bcbb44d0846a0e` |
| `product_category_name_translation.csv` | 71 | `a81f0d1f27b27e7293f761bc79e3ce8f348ee39c4b3ed3e49bde38f478586278` |

## Profile results

The CSVs were read with pandas 3.0.6. Checks covered row counts, nulls, duplicate keys, and join coverage. Results below describe this snapshot and the stated analysis scope; they do not prove every possible quality rule.

- `order_id`, `customer_id`, `product_id`, and `seller_id` are unique in their respective tables. `(order_id, order_item_id)` and `(order_id, payment_sequential)` are also unique. No orphan order-item, product, seller, customer, payment, or review keys were found in the checked joins.
- Order statuses: delivered 96,478; shipped 1,107; canceled 625; unavailable 609; invoiced 314; processing 301; created 5; approved 2. Purchase timestamps range from 4 September 2016 through 17 October 2018.
- Excluding canceled and unavailable orders leaves 98,207 orders. Eight of these have no order item. The analysis scope requires at least one item, leaving **98,199 orders and 112,101 items**. Item price sums to **BRL 13,494,400.74** and freight to **BRL 2,241,126.29**. No negative price or freight was found in this scoped item set. Report the eight itemless orders separately.
- In scope, 9,761 orders have multiple items, 1,277 have multiple sellers, and 785 have multiple product categories (a null category counts as unknown). Order and review counts across these overlapping groups cannot be summed to derive a grand total.
- Across the full data, 2,961 orders have multiple payment rows and 2,246 have multiple payment types. Within the 98,199-order scope, 2,211 orders use multiple types. Eighty scoped orders lack `payment_sequential = 1`: 79 have another payment row and one has no payment row. Do not silently drop these orders with an inner join.
- There are 547 orders with multiple review rows; 314 rows belong to duplicate `(order_id, review_creation_date)` pairs. In scope, 97,467 orders have a review and 732 do not. Selecting one row per order by descending `review_creation_date`, `review_answer_timestamp`, `review_id`, and `review_score` gives a review-score sum of 401,198 and an order-weighted average of **4.11624**. Joining that review to items and averaging gives **4.04446**; these are different metrics.
- Across all orders, 2,965 `order_delivered_customer_date` values and 160 approval timestamps are null. In scope, 96,470 orders have a delivery date; eight orders marked delivered lack one. There are 610 products with a null category and 13 products with a non-null category missing from the translation table. A missing translation does not mean the product itself is unknown.
- No in-scope delivery date precedes its purchase date. Using calendar-day differences, the scoped orders total **1,205,571 delivery days**. There are 96,470 orders with delivery dates and **6,534 late orders**; the eligible denominator with both actual and estimated delivery dates is also 96,470. These figures check the proposed definition; they are not cube results.
- The warehouse scope contains **94,983** `customer_unique_id` values: 92,096 customers have one order and 2,887 have more than one (3.04%). RFM frequency has limited variation; do not label clusters as loyal customers without supporting evidence.
- After selecting one review per order, 95,824 in-scope delivered orders have a review. For scoring at delivery time, requiring `review_answer_timestamp >= delivered_customer_date` as a proxy that the label was not yet observed leaves **91,170 samples**, including **8,629 low scores (1–2; 9.46%)**. There are 4,966 selected reviews whose creation date precedes delivery, 3,161 on the same date, and 4,654 whose answer timestamp precedes delivery. The answer timestamp does not prove when the score became available; this cohort reduces, but cannot guarantee the absence of, target leakage. Report the exclusions and this limitation.

## Limits

2018 is incomplete; compare equal periods or state the period explicitly. This is historical data and should not be used to claim current business conditions. Since this profile, an exploratory K-Means model and the SQL warehouse load have run on the snapshot. SSIS execution and the SSAS cube remain unverified. Not every possible data-quality rule or Drive permission has been checked.

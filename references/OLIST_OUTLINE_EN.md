# Olist Final Project Outline

English working version of the supplied Olist proposal. The [original DOCX](Original-Olist-Outline.docx) is preserved as the source. The assignment brief remains authoritative where it differs from this proposal.

## Dataset

Use the Brazilian E-Commerce Public Dataset by Olist on Kaggle. It contains about 100,000 orders from September 2016 through October 2018. There is little data from 2016, and 2018 is complete only through August; monthly analysis should therefore focus on 2017.

| CSV | Proposed use | Main columns |
| --- | --- | --- |
| `olist_orders_dataset` | Fact and Date dimension source | `order_id`, `customer_id`, `order_status`, purchase/delivery/estimated timestamps |
| `olist_order_items_dataset` | Fact grain | `order_id`, `order_item_id`, `product_id`, `seller_id`, `price`, `freight_value` |
| `olist_customers_dataset` | Customer dimension | `customer_id`, `customer_unique_id`, city, state |
| `olist_products_dataset` | Product dimension | `product_id`, category, weight |
| `product_category_name_translation` | Product category translation | source and English category names |
| `olist_sellers_dataset` | Seller dimension | `seller_id`, city, state |
| `olist_order_payments_dataset` | Payment dimension/source | `order_id`, `payment_sequential`, `payment_type`, `payment_value` |
| `olist_order_reviews_dataset` | Review score source | `order_id`, `review_score` |
| `olist_geolocation_dataset` | Excluded | Too large and unnecessary for the proposed cube |

### Proposed cleaning rules

- Exclude orders whose status is `canceled` or `unavailable`.
- Map missing product categories to `unknown`; translate category names with the translation CSV.
- Convert timestamp strings to datetime.
- Derive Brazil's five macro-regions from state codes: North, Northeast, Center-West, Southeast, and South.
- The original proposal selects `payment_type` where `payment_sequential = 1` and selects the latest review for orders with multiple rows. The current team decision replaces the primary-payment rule: retain all actual payment rows and analyze each payment type separately. See `../WAREHOUSE_DESIGN.md`.

## Original star-schema proposal

The proposal uses one central `Fact_Sales` and five dimensions. Its grain is one product line per order (`order_item`). This is the initial outline; the current project design uses separate Sales, Order, and Payment facts to prevent double-counting across different grains.

| Table | Key attributes and measures | Hierarchy |
| --- | --- | --- |
| `Fact_Sales` | Sales key, FKs to five dimensions, degenerate OrderID; Quantity, Price, FreightValue, ReviewScore, DeliveryDays, IsLate | — |
| `Dim_Date` | DateKey, FullDate, day, month, month name, quarter, year, weekday and weekday number | Year → Quarter → Month → Date |
| `Dim_Customer` | CustomerID, CustomerUniqueID, city, state, region | Region → State → City |
| `Dim_Product` | ProductID, category, weight | Category → Product |
| `Dim_Seller` | SellerID, city, state, region | Region → State → City |
| `Dim_Payment` | PaymentType | — |

The outline defines `DeliveryDays` as calendar days from purchase to delivery, NULL when undelivered; `IsLate` as actual delivery date after estimated delivery; and Quantity as 1 per order item. The current detailed contract is in `../WAREHOUSE_DESIGN.md`.

## SSIS proposal

The original assignment split SSIS into three sequential packages:

1. `Load_Staging.dtsx`: one Data Flow per CSV from Flat File Source to the matching `stg_*` OLE DB destination. Set the text qualifier to a double quote. If the review message column exceeds the destination length, omit that column. Truncate staging at the beginning of Control Flow so the package can be rerun.
2. Load dimensions: derive Region for Customer and Seller; translate Product category and map missing categories to `unknown`; select distinct PaymentType; generate the Date dimension with a SQL script.
3. `Load_Fact.dtsx`: read the staging query, look up dimension surrogate keys, send unmatched lookup rows to an error table, and load the fact.

These are source-outline instructions, not verified implementation. Use the current design's controlled full-reload and reconciliation rules in `../WAREHOUSE_DESIGN.md`.

## SSAS and analysis proposal

The source outline proposes an Analysis Services Multidimensional cube named `Olist DW`, built over `OlistDW`. It asks for date and geography hierarchies, correctly keyed month/quarter attributes, weekday sorting, a processed cube, and Browser validation. It also includes DDL, calculated members, and ten MDX examples in the original DOCX. Those query examples depend on the original single-fact design and must be revised to match the current cube metadata and measure contract before use.

### Ten business questions

1. Revenue and order count by year and quarter; show a column chart with year-to-quarter drill-down.
2. Top 10 product categories by revenue; show a bar chart.
3. Top 5 customer states by revenue, with order count and average order value; use a filled map or bar chart.
4. Revenue share by payment method in the original proposal. The agreed project definition uses actual Payment Amount and Payment Share by each `payment_type`.
5. Monthly revenue growth in 2017 versus the previous month; show a line/column visual filtered to 2017.
6. Ten categories with the lowest average review score, requiring at least 100 reviews; show a sorted bar chart.
7. Average delivery time and late-delivery rate by state; use a combined bar and line chart.
8. Top 10 sellers by revenue, with state and review score; show a bar chart/table.
9. Freight-to-revenue ratio by region, comparing 2017 with 2018; show a clustered column chart.
10. Revenue by weekday and payment method; show a conditionally formatted matrix. The agreed project definition uses Payment Amount by weekday and payment type.

The provided instructor requirement asks for the 10 questions using manual SSAS analysis and Power BI, plus MDX analysis and Excel PivotTable analysis. It does not specify that every question must be repeated in all four tools.

## Data mining proposal

The outline proposes reading CSVs directly with pandas and scikit-learn, in parallel with SSIS/cube work, and submitting a notebook or Python script with figures.

| | Algorithm 1 | Algorithm 2 |
| --- | --- | --- |
| Role in outline | A | B |
| Task | Customer clustering | Low-review classification |
| Algorithm | K-Means | Random Forest; Decision Tree as an optional comparison |
| Unit of analysis | One row per `customer_unique_id`: Recency, Frequency, Monetary | One row per order; label `review_score <= 2`; proposed features include delivery days, delay, freight, price, item count, category, and whether customer/seller share a state |
| Preparation | Log transform and StandardScaler; try k = 2–8 using Elbow and Silhouette | One-hot encode categories; stratified 80/20 split; balanced class weights for imbalanced labels |
| Evaluation | Silhouette score and average RFM by cluster; interpret cluster profiles | Precision, Recall, F1, confusion matrix, ROC-AUC, and feature importance |
| Intended use | Tailor marketing to customer segments | Improve operations based on low-score risk factors |

The original Random Forest feature set includes post-delivery information. The current project defines prediction at delivery time, before the review label is observed, and requires leakage-aware feature timing, a time-based split, a baseline, and reporting of cohort exclusions. Each model's report should state its objective, data preparation, parameters, actual results, interpretation, and recommendations.

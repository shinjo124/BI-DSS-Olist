# Olist Warehouse and Measure Design

**Status: the contract is implemented and verified in SSAS for the checked snapshot.** See [local reconciliation evidence](4_SSAS/README.md). Multi-category orders, actual payment rows, and mining cohort rules follow the definitions below. The original proposal is preserved in `references/Original-Olist-Outline.docx`.

## Scope and dates

- Include orders whose status is not `canceled` or `unavailable` and that have at least one order item. Every measure below uses this scope. Record the eight eligible-status orders without items separately; exclude them from `Order Count`. Other statuses remain included. Revenue is order-item value within this analysis scope, not settled accounting revenue.
- Use the calendar date of `order_purchase_timestamp` as the common analysis date. Delivery and estimated-delivery dates are used only for delivery measures. The CSV timestamps have no timezone offset; do not invent one. `DateKey = YYYYMMDD`. ISO weekday runs Monday = 1 through Sunday = 7, independent of SQL `DATEFIRST`.
- `Revenue` is the sum of `order_items.price`, excluding freight; it is not payment amount. `Freight Value` is the sum of `order_items.freight_value`. Store BRL values as `decimal(19,2)`. `Payment Amount` is the sum of `payment_value` over actual payment rows and must not be inferred from Revenue. Questions 4 and 10 therefore analyze **payment amount**, not product revenue.
- Count an order once within each category or seller that has at least one item in that group. Groups can overlap, so their order and review counts may sum to more than the overall total. Reviews are order-level scores, not seller- or product-specific ratings.

## Proposed model

Use three measure groups at separate grains, shared dimensions, and `DimOrder` as a bridge. This is a fact constellation with shared dimensions, not the single-fact/five-dimension star in the original proposal; describe it as such in the report.

| Table | Grain, key, and main columns |
| --- | --- |
| `DimDate` | `DateKey int` PK; unique `FullDate date`; Year, Quarter, Month, Day, MonthName, ISOWeekdayNo/Name. Hierarchy Year → Quarter → Month → Date; quarter key is year+quarter and month key is year+month. Cover the full purchase-date range and validate boundaries during load. |
| `DimCustomer` | `CustomerKey int` PK; unique `CustomerID char(32)`, `CustomerUniqueID char(32)`, City, State, Region. `CustomerID` is order-specific; `CustomerUniqueID` identifies the person. City keys use State+City. Unknown state/region maps to Unknown. |
| `DimProduct` | `ProductKey int` PK; unique `ProductID char(32)`, CategoryOriginal, CategoryEnglish, nullable WeightG. Missing source category maps to Unknown. If a source category exists but its English translation does not, retain the source category and flag the missing translation rather than mapping the product to Unknown. |
| `DimSeller` | `SellerKey int` PK; unique `SellerID char(32)`, City, State, Region. City keys use State+City; unknown values follow the customer rule. |
| `DimPayment` | `PaymentKey int` PK; unique `PaymentType` (`credit_card`, `boleto`, `debit_card`, `voucher`, and any other/unknown values encountered). Do not fabricate a payment row for an order with no payment. |
| `DimOrder` | `OrderKey int` PK; unique `OrderID char(32)`. Connects `FactSales`, `FactOrder`, and `FactPayment`; can be hidden from ordinary report users. |
| `FactSales` | One order item, unique `(OrderKey, OrderItemID)`; FKs DateKey, CustomerKey, ProductKey, SellerKey, OrderKey; Quantity = 1, Price, FreightValue. Never directly join multi-row payment or review records into this grain. |
| `FactOrder` | One scoped order, `OrderKey` PK/FK; FKs DateKey, CustomerKey; nullable ReviewScore, ReviewPresent 0/1, nullable DeliveryDays, DeliveredFlag 0/1, nullable LateFlag 0/1, LateEligibleFlag 0/1. Select no more than one review by the rule below. |
| `FactPayment` | One payment row `(OrderKey, PaymentSequential)` unique; FKs OrderKey, DateKey, CustomerKey, PaymentKey; PaymentValue and PaymentInstallments. Keep all actual payment rows for scoped orders; do not invent a row when payment is absent. |

### SSAS Multidimensional relationships

Create Sales, Orders, and Payments measure groups. Date and Customer have regular relationships to all three; Order has a regular relationship to all three. Product and Seller relate regularly to Sales and many-to-many to Orders through the Sales measure group and Order dimension, using the DSV keys and relationship described in [Microsoft's many-to-many tutorial](https://learn.microsoft.com/en-us/analysis-services/multidimensional-tutorial/lesson-5-3-defining-a-many-to-many-relationship?view=sql-analysis-services-2025).

Do not relate Payment to Product or Seller by assumption. Questions 4 and 10 use Payment, Date, and Customer. Hide or block unsupported dimension combinations; do not let SSAS return an unfiltered grand total as if it were filtered. When Product and Seller are filtered together for order-level measures, test same-item semantics: two independent many-to-many relationships can intersect orders without proving that the selected product and seller belong to the same item. Do not publish that combination until it is verified. If needed, add an order–product–seller bridge or another tested filtering method.

Keep many-to-many as the primary design. Kiet has one working day for the initial implementation and validation, starting when the base cube processes and independent SQL reference results are ready. Pass requires SQL agreement for category/seller groups and grand totals, including orders with repeated items in the same group, multiple groups, and missing reviews. At the checkpoint, record the outcome and decide whether to continue or assess the fallback. Test combined Product+Seller filters separately and do not publish them without same-item evidence.

If the checkpoint fails, assess two deduplicated facts at `(order, category)` and `(order, seller)` grain, each carrying the selected order review and a review-present flag. Calculate group averages from score sum / reviewed-order count; retain `FactOrder` for overall order counts and overall average because a multi-group order appears in several rows. Do not add group counts to obtain grand totals. These two facts do not establish Product+Seller same-item semantics; validate or exclude that combination. Reconcile the fallback with independent SQL before adopting it.

## ETL and reproducibility

1. Load CSVs to staging with business keys and original timestamps retained. Check key uniqueness before joining. Separate rejected rows with reasons, counts, and amounts; never discard them silently. Use the complete Brazilian state-to-region mapping from the outline, exact state codes, and a separate Unknown value; do not default unrecognized states to Norte.
2. Select one review row per order using `ROW_NUMBER` ordered by `review_creation_date DESC, review_answer_timestamp DESC, review_id DESC, review_score DESC`. Review Count means orders with a selected review, not the raw number of review rows. Retain the selected source ID/date for traceability. A missing score is not zero.
3. `DeliveryDays = DATEDIFF(day, CAST(purchase AS date), CAST(delivered AS date))` when a delivery date exists. Set `DeliveredFlag = 1` when the date exists; do not rely on status alone. Set `LateEligibleFlag = 1` when actual and estimated dates both exist. Set `LateFlag = 1` when the actual calendar date is after the estimated calendar date, or 0 when both exist and delivery is not late. If either is missing, leave LateFlag NULL and exclude the row from the rate denominator.
4. Use a controlled full reload: stage separately, validate, and load a new version or use a suitable transaction; switch the active version only after all checks pass. Delete facts before dimensions when required and roll back on failure. Do not truncate the live warehouse and leave it partially loaded. Enforce business-key uniqueness and FKs; compare row counts and totals before and after two runs. Truncating staging alone does not prevent duplicates.
5. Keep lookup failures with business keys and counts. Use an Unknown member only where the rule allows. If rejected rows could lose items or value, stop publishing/swapping the load until reconciled; a partial load is not a successful load.

## Measure contract

Totals are `SUM`; load 0/1 flags explicitly. A zero or NULL denominator returns NULL/blank. Divide using decimal/floating arithmetic, not integer division. A measure is additive across a dimension only where the relationships above support it.

| Measure | Definition and grain |
| --- | --- |
| Revenue; Freight Value; Quantity | `SUM(Price)`, `SUM(FreightValue)`, and `SUM(Quantity)` from Sales/item. |
| Order Count | `SUM(1)` from Orders/order. Product/Seller filter through many-to-many, counting each order once within the selected context. Do not add counts across overlapping groups. |
| Review Score Sum; Review Count; Avg Review | Sum the selected order-level ReviewScore; sum ReviewPresent; divide the two sums. Under Product/Seller filters, include one score per order that has a matching item. |
| Delivery Days Sum; Delivered Count; Avg Delivery Days | Sum DeliveryDays; sum DeliveredFlag; divide at order grain. |
| Late Count; Late Eligible Count; Late Rate | Sum LateFlag; sum LateEligibleFlag; divide. Do not replace the denominator with all orders or delivered orders when estimated dates are missing. |
| Freight Ratio | Freight Value / Revenue; a ratio, not a payment ratio. |
| Avg Order Value | Revenue / Order Count: product value per order with a matching item in the selected context, excluding freight. Under Seller/Category filters, this need not equal the entire basket value. |
| Payment Amount; Payment Share | Sum PaymentValue by payment type; divide by Payment Amount over all payment types in the same date/customer context. An order with multiple methods contributes its actual amounts to each. This is not Revenue. |
| MoM Growth | `(current month Revenue − prior month Revenue) / prior month Revenue`. Return blank if the prior month is missing or zero. January 2017 compares with December 2016; state the small baseline and avoid strong claims. |

## Mapping the 10 questions

| # | Scope and evidence to show |
| --- | --- |
| 1 | Revenue and Order Count by purchase year/quarter; show annual totals and drill to quarters. |
| 2 | Top 10 categories by Revenue with Quantity; retain Unknown category. |
| 3 | Top 5 customer states by Revenue, with Order Count and Avg Order Value. |
| 4 | Payment Amount and Payment Share by payment type, against total payment amount in the same filter context; not revenue share. |
| 5 | Monthly Revenue and MoM Growth for 2017; compare across year boundaries and guard against division by zero. |
| 6 | Ten categories with lowest Avg Review among categories with at least 100 reviewed orders; state that reviews are order-level and category groups can overlap. |
| 7 | By customer state: Avg Delivery Days, Late Rate, Delivered Count, and Late Eligible Count to expose the denominator. |
| 8 | Top 10 sellers by Revenue, with seller state, Order Count, and Avg Review of orders containing that seller; do not describe this as seller-specific ratings. |
| 9 | Freight Ratio by customer region, compare 2017 and 2018 over the same **January–August** period; do not compare a partial year as a complete year. |
| 10 | Payment Amount by purchase weekday and payment type; sort weekdays Monday through Sunday. Use the same actual payment convention as question 4. |

## Validation targets

- Independent SQL and SSAS/Power BI should match these full-scope snapshot totals: 98,199 orders, 112,101 items, Revenue BRL 13,494,400.74, Freight BRL 2,241,126.29; 102,565 payment rows across 98,198 orders, Payment Amount BRL 15,738,221.95. One order has no payment row and must not have a fabricated FactPayment row. Payment Amount is not expected to equal Revenue plus Freight.
- With the specified review-selection rule, snapshot targets are Review Count 97,467, Review Score Sum 401,198, Avg Review about 4.116244; Delivery Days Sum 1,205,571; Delivered Count and Late Eligible Count 96,470; Late Count 6,534. These are CSV results, not cube results.
- Build a small test case: one order with two items in different categories/sellers and another order with one item; scores 5 and 1 produce an overall average of 3. Each category/seller context counts an order once, and group totals can overlap. Add an order without a review and cases with missing delivery/estimated dates; denominators must remain correct. Test category + seller same-item filtering before allowing it.
- Test multiple payment types against actual rows, orders missing `payment_sequential = 1` but having other payment rows, and orders with no payment that still count in Sales/Orders. Test Unknown members, two reloads, zero/missing prior month, on-time delivery on the estimated date, incomplete years, and SQL reconciliations. Verify dimension usage, All member, subtotals, drill-down, and combined context in SSAS before treating the cube design as working.
- Mining profile: RFM uses `customer_unique_id`, Frequency is distinct order count, and joins must not multiply monetary value. Only 2,887/94,983 scoped customers (3.04%) repeat purchases, limiting frequency variation. Ground cluster labels in observed behavior. Random Forest scores at delivery using features available then. The existing eligibility rule, `review_answer_timestamp >= delivered_customer_date`, leaves 91,170 samples and 8,629 low-score labels (score ≤ 2, 9.46%) before splitting. Choose a training cutoff and split by `delivered_customer_date`. Train on deliveries before the cutoff whose selected review answer timestamp is at or before the cutoff. Hold out deliveries at or after the cutoff for evaluation once their labels are available. Report cutoff exclusions separately from cohort exclusions. The answer timestamp approximates when the score became observable. Fit preprocessing on training rows only, compare with a baseline on the same holdout, and report precision, recall, F1, and the confusion matrix. The [Random Forest results](5_DataMining/README.md#random-forest-for-low-reviews-at-delivery) record the completed holdout evaluation.

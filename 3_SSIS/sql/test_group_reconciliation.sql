-- Independently compare all category and seller groups against staging.
SET NOCOUNT ON;
WITH Eligible AS (
    SELECT order_id FROM stg.Orders WHERE order_status NOT IN ('canceled', 'unavailable')
      AND EXISTS (SELECT 1 FROM stg.OrderItems i WHERE i.order_id = stg.Orders.order_id)
), Reviews AS (
    SELECT order_id, review_score, ROW_NUMBER() OVER (PARTITION BY order_id
        ORDER BY review_creation_date DESC, review_answer_timestamp DESC, review_id DESC, review_score DESC) AS rn
    FROM stg.Reviews
), Membership AS (
    SELECT DISTINCT COALESCE(t.product_category_name_english, p.product_category_name, 'Unknown') AS category, i.order_id
    FROM Eligible e JOIN stg.OrderItems i ON i.order_id = e.order_id
    JOIN stg.Products p ON p.product_id = i.product_id
    LEFT JOIN stg.CategoryTranslation t ON t.product_category_name = p.product_category_name
), SourceGroups AS (
    SELECT m.category, COUNT(*) AS orders, COUNT(r.review_score) AS reviews,
           COALESCE(SUM(CONVERT(bigint,r.review_score)),0) AS scores
    FROM Membership m LEFT JOIN Reviews r ON r.order_id = m.order_id AND r.rn = 1 GROUP BY m.category
), WarehouseMembership AS (
    SELECT DISTINCT p.CategoryEnglish AS category, s.OrderKey
    FROM dbo.FactSales s JOIN dbo.DimProduct p ON p.ProductKey = s.ProductKey
), WarehouseGroups AS (
    SELECT m.category, COUNT(*) AS orders, COUNT(o.ReviewScore) AS reviews,
           COALESCE(SUM(CONVERT(bigint,o.ReviewScore)),0) AS scores
    FROM WarehouseMembership m JOIN dbo.FactOrder o ON o.OrderKey = m.OrderKey GROUP BY m.category
)
SELECT * INTO #CategoryDifferences FROM (
    SELECT * FROM (SELECT * FROM SourceGroups EXCEPT SELECT * FROM WarehouseGroups) a
    UNION ALL
    SELECT * FROM (SELECT * FROM WarehouseGroups EXCEPT SELECT * FROM SourceGroups) b
) d;
IF EXISTS (SELECT 1 FROM #CategoryDifferences) THROW 50500, 'Category group reconciliation failed', 1;

WITH Eligible AS (
    SELECT order_id FROM stg.Orders WHERE order_status NOT IN ('canceled', 'unavailable')
      AND EXISTS (SELECT 1 FROM stg.OrderItems i WHERE i.order_id = stg.Orders.order_id)
), Reviews AS (
    SELECT order_id, review_score, ROW_NUMBER() OVER (PARTITION BY order_id
        ORDER BY review_creation_date DESC, review_answer_timestamp DESC, review_id DESC, review_score DESC) AS rn
    FROM stg.Reviews
), SourceRevenue AS (
    SELECT i.seller_id, SUM(i.price) AS revenue FROM stg.OrderItems i JOIN Eligible e ON e.order_id=i.order_id GROUP BY i.seller_id
), SourceMembership AS (
    SELECT DISTINCT i.seller_id, i.order_id FROM stg.OrderItems i JOIN Eligible e ON e.order_id=i.order_id
), SourceGroups AS (
    SELECT m.seller_id, COUNT(*) AS orders, COUNT(r.review_score) AS reviews,
           COALESCE(SUM(CONVERT(bigint,r.review_score)),0) AS scores
    FROM SourceMembership m LEFT JOIN Reviews r ON r.order_id=m.order_id AND r.rn=1 GROUP BY m.seller_id
), WarehouseRevenue AS (
    SELECT SellerKey, SUM(Price) AS revenue FROM dbo.FactSales GROUP BY SellerKey
), WarehouseMembership AS (
    SELECT DISTINCT SellerKey, OrderKey FROM dbo.FactSales
), WarehouseGroups AS (
    SELECT m.SellerKey, COUNT(*) AS orders, COUNT(o.ReviewScore) AS reviews,
           COALESCE(SUM(CONVERT(bigint,o.ReviewScore)),0) AS scores
    FROM WarehouseMembership m JOIN dbo.FactOrder o ON o.OrderKey=m.OrderKey GROUP BY m.SellerKey
), SourceTotals AS (
    SELECT g.seller_id, r.revenue, g.orders, g.reviews, g.scores FROM SourceGroups g JOIN SourceRevenue r ON r.seller_id=g.seller_id
), WarehouseTotals AS (
    SELECT d.SellerID, r.revenue, g.orders, g.reviews, g.scores
    FROM WarehouseGroups g JOIN WarehouseRevenue r ON r.SellerKey=g.SellerKey JOIN dbo.DimSeller d ON d.SellerKey=g.SellerKey
)
SELECT * INTO #SellerDifferences FROM (
    SELECT * FROM (SELECT * FROM SourceTotals EXCEPT SELECT * FROM WarehouseTotals) a
    UNION ALL
    SELECT * FROM (SELECT * FROM WarehouseTotals EXCEPT SELECT * FROM SourceTotals) b
) d;
IF EXISTS (SELECT 1 FROM #SellerDifferences) THROW 50501, 'Seller group reconciliation failed', 1;
PRINT 'Category and seller groups reconcile with staging';

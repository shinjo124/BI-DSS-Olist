-- Full snapshot, no additional filters. Group membership is deduplicated by order.
SET NOCOUNT ON;

-- Q6: lowest category review averages, with at least 100 reviewed orders.
WITH CategoryOrders AS (
    SELECT DISTINCT p.CategoryEnglish, s.OrderKey
    FROM dbo.FactSales s JOIN dbo.DimProduct p ON p.ProductKey = s.ProductKey
)
SELECT TOP (10) c.CategoryEnglish, COUNT(*) AS OrderCount,
       COUNT(o.ReviewScore) AS ReviewCount,
       AVG(CAST(o.ReviewScore AS decimal(19,6))) AS AvgReview
FROM CategoryOrders c JOIN dbo.FactOrder o ON o.OrderKey = c.OrderKey
GROUP BY c.CategoryEnglish HAVING COUNT(o.ReviewScore) >= 100
ORDER BY AvgReview, c.CategoryEnglish;

-- Q8: seller revenue is at item grain; reviews and order counts are at order grain.
WITH SellerRevenue AS (
    SELECT SellerKey, SUM(Price) AS Revenue FROM dbo.FactSales GROUP BY SellerKey
), SellerOrders AS (
    SELECT DISTINCT SellerKey, OrderKey FROM dbo.FactSales
), SellerReviews AS (
    SELECT s.SellerKey, COUNT(*) AS OrderCount, COUNT(o.ReviewScore) AS ReviewCount,
           AVG(CAST(o.ReviewScore AS decimal(19,6))) AS AvgReview
    FROM SellerOrders s JOIN dbo.FactOrder o ON o.OrderKey = s.OrderKey GROUP BY s.SellerKey
)
SELECT TOP (10) d.SellerID, d.[State], r.Revenue, v.OrderCount, v.ReviewCount, v.AvgReview
FROM SellerRevenue r JOIN dbo.DimSeller d ON d.SellerKey = r.SellerKey
JOIN SellerReviews v ON v.SellerKey = r.SellerKey
ORDER BY r.Revenue DESC, d.SellerID;

-- Overall totals must come from orders, not the sum of overlapping groups.
SELECT COUNT(*) AS OrderCount, COUNT(ReviewScore) AS ReviewCount,
       AVG(CAST(ReviewScore AS decimal(19,6))) AS AvgReview FROM dbo.FactOrder;

-- Independent SQL reference queries for the agreed warehouse measure contract.
-- Run against the fully loaded snapshot with no additional report filters.
SET NOCOUNT ON;

-- Q1: year and quarter totals. Distinct orders protect against multiple items.
SELECT d.[Year], d.[Quarter], SUM(s.Price) AS Revenue,
       COUNT(DISTINCT s.OrderKey) AS OrderCount
FROM dbo.FactSales s JOIN dbo.DimDate d ON d.DateKey=s.DateKey
GROUP BY GROUPING SETS ((d.[Year]), (d.[Year], d.[Quarter]))
ORDER BY d.[Year], d.[Quarter];

-- Q2: top ten categories by item revenue.
SELECT TOP (10) p.CategoryEnglish, SUM(s.Price) AS Revenue, SUM(s.Quantity) AS Quantity
FROM dbo.FactSales s JOIN dbo.DimProduct p ON p.ProductKey=s.ProductKey
GROUP BY p.CategoryEnglish ORDER BY Revenue DESC, p.CategoryEnglish;

-- Q3: top customer states and average product value per distinct order.
SELECT TOP (5) c.[State], SUM(s.Price) AS Revenue, COUNT(DISTINCT s.OrderKey) AS OrderCount,
       SUM(s.Price) / NULLIF(CAST(COUNT(DISTINCT s.OrderKey) AS decimal(19,2)),0) AS AvgOrderValue
FROM dbo.FactSales s JOIN dbo.DimCustomer c ON c.CustomerKey=s.CustomerKey
GROUP BY c.[State] ORDER BY Revenue DESC, c.[State];

-- Q4: actual payment value by method, including multiple methods per order.
WITH Amounts AS (
    SELECT p.PaymentType, SUM(f.PaymentValue) AS PaymentAmount
    FROM dbo.FactPayment f JOIN dbo.DimPayment p ON p.PaymentKey=f.PaymentKey
    GROUP BY p.PaymentType
)
SELECT PaymentType, PaymentAmount,
       PaymentAmount / NULLIF(SUM(PaymentAmount) OVER (),0) AS PaymentShare
FROM Amounts ORDER BY PaymentAmount DESC, PaymentType;

-- Q5: include December 2016 to calculate January 2017's prior month.
WITH Months AS (
    SELECT DISTINCT DATEFROMPARTS([Year],[Month],1) AS MonthStart
    FROM dbo.DimDate WHERE FullDate >= '2016-12-01' AND FullDate < '2018-01-01'
), RevenueByMonth AS (
    SELECT DATEFROMPARTS(d.[Year],d.[Month],1) AS MonthStart, SUM(s.Price) AS Revenue
    FROM dbo.FactSales s JOIN dbo.DimDate d ON d.DateKey=s.DateKey
    GROUP BY d.[Year],d.[Month]
), Monthly AS (
    SELECT m.MonthStart, r.Revenue,
           LAG(r.Revenue) OVER (ORDER BY m.MonthStart) AS PreviousRevenue
    FROM Months m LEFT JOIN RevenueByMonth r ON r.MonthStart=m.MonthStart
)
SELECT MonthStart, Revenue, PreviousRevenue,
       (Revenue-PreviousRevenue) / NULLIF(PreviousRevenue,0) AS MoMGrowth
FROM Monthly WHERE MonthStart >= '2017-01-01' ORDER BY MonthStart;

SET NOCOUNT ON;
IF (SELECT COUNT(*) FROM dbo.FactOrder) <> 4 THROW 50200, 'Expected four orders', 1;
IF (SELECT COUNT(*) FROM dbo.FactSales) <> 8 THROW 50201, 'Expected eight items', 1;
IF (SELECT COUNT(*) FROM dbo.FactPayment) <> 5 THROW 50202, 'Expected five payment rows', 1;
IF (SELECT SUM(Price) FROM dbo.FactSales) <> 267.43 THROW 50203, 'Incorrect product revenue', 1;
IF (SELECT SUM(FreightValue) FROM dbo.FactSales) <> 132.57 THROW 50204, 'Incorrect freight', 1;
IF (SELECT SUM(PaymentValue) FROM dbo.FactPayment) <> 400.00 THROW 50205, 'Incorrect payment amount', 1;
IF (SELECT SUM(CONVERT(int, ReviewPresent)) FROM dbo.FactOrder) <> 3 THROW 50206, 'Incorrect reviewed-order count', 1;
IF (SELECT SUM(CONVERT(int, ReviewScore)) FROM dbo.FactOrder) <> 15 THROW 50207, 'Incorrect review sum', 1;
IF (SELECT COUNT(*) FROM dbo.DimDate) <> (SELECT DATEDIFF(day, MIN(FullDate), MAX(FullDate)) + 1 FROM dbo.DimDate)
    THROW 50208, 'Date dimension has missing calendar days', 1;
WITH Actual AS (
    SELECT p.PaymentType, SUM(f.PaymentValue) AS amount
    FROM dbo.FactPayment f JOIN dbo.DimPayment p ON p.PaymentKey = f.PaymentKey GROUP BY p.PaymentType
), Expected AS (
    SELECT PaymentType, amount FROM (VALUES ('boleto', CAST(126.54 AS decimal(19,2))),
        ('credit_card', CAST(255.54 AS decimal(19,2))), ('voucher', CAST(17.92 AS decimal(19,2)))) v(PaymentType, amount)
)
SELECT * INTO #PaymentDifference FROM (
    SELECT * FROM (SELECT * FROM Actual EXCEPT SELECT * FROM Expected) a
    UNION ALL SELECT * FROM (SELECT * FROM Expected EXCEPT SELECT * FROM Actual) b
) d;
IF EXISTS (SELECT 1 FROM #PaymentDifference) THROW 50209, 'Incorrect payment groups', 1;

WITH Membership AS (
    SELECT DISTINCT p.CategoryEnglish, s.OrderKey FROM dbo.FactSales s JOIN dbo.DimProduct p ON p.ProductKey = s.ProductKey
), Actual AS (
    SELECT m.CategoryEnglish, COUNT(*) AS orders, COUNT(o.ReviewScore) AS reviews,
           COALESCE(SUM(CONVERT(int,o.ReviewScore)),0) AS scores
    FROM Membership m JOIN dbo.FactOrder o ON o.OrderKey = m.OrderKey GROUP BY m.CategoryEnglish
), Expected AS (
    SELECT category, orders, reviews, scores FROM (VALUES ('consoles_games',1,1,5), ('garden_tools',2,2,10),
        ('sports_leisure',1,0,0), ('toys',1,1,5)) v(category,orders,reviews,scores)
)
SELECT * INTO #CategoryDifference FROM (
    SELECT * FROM (SELECT * FROM Actual EXCEPT SELECT * FROM Expected) a
    UNION ALL SELECT * FROM (SELECT * FROM Expected EXCEPT SELECT * FROM Actual) b
) d;
IF EXISTS (SELECT 1 FROM #CategoryDifference) THROW 50210, 'Incorrect category groups', 1;
PRINT 'Integration subset totals passed';

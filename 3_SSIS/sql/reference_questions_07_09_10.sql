-- Full snapshot, no additional filters except the periods specified for Q9.
SET NOCOUNT ON;

-- Q7: delivery averages and late rates use their respective eligible denominators.
SELECT c.[State], SUM(CONVERT(bigint, o.DeliveredFlag)) AS DeliveredCount,
       SUM(CONVERT(bigint, o.LateEligibleFlag)) AS LateEligibleCount,
       SUM(CONVERT(bigint, o.DeliveryDays)) * 1.0 / NULLIF(SUM(CONVERT(bigint, o.DeliveredFlag)), 0) AS AvgDeliveryDays,
       SUM(CONVERT(bigint, o.LateFlag)) * 1.0 / NULLIF(SUM(CONVERT(bigint, o.LateEligibleFlag)), 0) AS LateRate
FROM dbo.FactOrder o JOIN dbo.DimCustomer c ON c.CustomerKey = o.CustomerKey
GROUP BY c.[State] ORDER BY c.[State];

-- Q9: compare the same January to August window in each year.
SELECT c.Region, d.[Year], SUM(s.Price) AS Revenue, SUM(s.FreightValue) AS Freight,
       SUM(s.FreightValue) / NULLIF(SUM(s.Price), 0) AS FreightRatio
FROM dbo.FactSales s JOIN dbo.DimCustomer c ON c.CustomerKey = s.CustomerKey
JOIN dbo.DimDate d ON d.DateKey = s.DateKey
WHERE d.[Year] IN (2017, 2018) AND d.[Month] BETWEEN 1 AND 8
GROUP BY c.Region, d.[Year] ORDER BY c.Region, d.[Year];

-- Q10: payment rows retain their actual methods; weekdays sort Monday to Sunday.
SELECT d.ISOWeekdayNo, d.ISOWeekdayName, p.PaymentType, SUM(f.PaymentValue) AS PaymentAmount
FROM dbo.FactPayment f JOIN dbo.DimDate d ON d.DateKey = f.DateKey
JOIN dbo.DimPayment p ON p.PaymentKey = f.PaymentKey
GROUP BY d.ISOWeekdayNo, d.ISOWeekdayName, p.PaymentType
ORDER BY d.ISOWeekdayNo, p.PaymentType;

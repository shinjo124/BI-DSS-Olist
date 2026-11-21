SET NOCOUNT ON;
IF (SELECT COUNT(*) FROM dbo.FactOrder) <> 98199 THROW 50500, 'Incorrect order count', 1;
IF (SELECT COUNT(*) FROM dbo.FactSales) <> 112101 THROW 50501, 'Incorrect item count', 1;
IF (SELECT SUM(Price) FROM dbo.FactSales) <> 13494400.74 THROW 50502, 'Incorrect revenue', 1;
IF (SELECT SUM(FreightValue) FROM dbo.FactSales) <> 2241126.29 THROW 50503, 'Incorrect freight', 1;
IF (SELECT COUNT(*) FROM dbo.FactPayment) <> 102565 THROW 50504, 'Incorrect payment row count', 1;
IF (SELECT SUM(PaymentValue) FROM dbo.FactPayment) <> 15738221.95 THROW 50505, 'Incorrect payment amount', 1;
IF (SELECT SUM(CONVERT(int,ReviewPresent)) FROM dbo.FactOrder) <> 97467 THROW 50506, 'Incorrect review count', 1;
IF (SELECT SUM(CONVERT(int,ReviewScore)) FROM dbo.FactOrder) <> 401198 THROW 50507, 'Incorrect review sum', 1;
IF (SELECT SUM(DeliveryDays) FROM dbo.FactOrder) <> 1205571 THROW 50508, 'Incorrect delivery days', 1;
IF (SELECT SUM(CONVERT(int,DeliveredFlag)) FROM dbo.FactOrder) <> 96470 THROW 50509, 'Incorrect delivered count', 1;
IF (SELECT SUM(CONVERT(int,LateEligibleFlag)) FROM dbo.FactOrder) <> 96470 THROW 50510, 'Incorrect late denominator', 1;
IF (SELECT SUM(CONVERT(int,LateFlag)) FROM dbo.FactOrder) <> 6534 THROW 50511, 'Incorrect late count', 1;
IF (SELECT COUNT(*) FROM dbo.DimDate) <> (SELECT DATEDIFF(day, MIN(FullDate), MAX(FullDate)) + 1 FROM dbo.DimDate)
    THROW 50512, 'Date dimension has missing calendar days', 1;
PRINT 'Full snapshot totals passed';

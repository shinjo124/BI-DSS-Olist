SET NOCOUNT ON;
IF OBJECT_ID(N'dbo.FactSales', N'U') IS NULL OR OBJECT_ID(N'dbo.FactOrder', N'U') IS NULL OR OBJECT_ID(N'dbo.FactPayment', N'U') IS NULL
    THROW 50001, 'The three warehouse facts must exist', 1;
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id IN (OBJECT_ID(N'dbo.FactSales'), OBJECT_ID(N'dbo.FactOrder'), OBJECT_ID(N'dbo.FactPayment'))) <> 12
    THROW 50002, 'Warehouse fact relationships are incomplete', 1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.FactSales') AND is_unique = 1 AND name = N'UQ_FactSales_OrderItem')
    THROW 50003, 'The order item business key must be unique', 1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.FactPayment') AND is_unique = 1 AND name = N'UQ_FactPayment_OrderSequence')
    THROW 50004, 'The payment business key must be unique', 1;
BEGIN TRANSACTION;
INSERT dbo.DimDate VALUES (20180101, '2018-01-01', 2018, 1, 1, 1, 'January', 1, 'Monday');
INSERT dbo.DimCustomer (CustomerID, CustomerUniqueID, City, [State], Region) VALUES ('test', 'person', 'test', 'SP', 'Sudeste');
INSERT dbo.DimOrder (OrderID) VALUES ('test');
DECLARE @order int = (SELECT OrderKey FROM dbo.DimOrder WHERE OrderID = 'test');
DECLARE @customer int = (SELECT CustomerKey FROM dbo.DimCustomer WHERE CustomerID = 'test');
BEGIN TRY
    INSERT dbo.FactOrder (OrderKey, DateKey, CustomerKey, ReviewScore, ReviewPresent, DeliveredFlag, LateEligibleFlag)
    VALUES (@order, 20180101, @customer, NULL, 1, 0, 0);
    THROW 50005, 'A present review must have a score', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 547 THROW;
END CATCH;
ROLLBACK TRANSACTION;
PRINT 'Warehouse schema checks passed';

SET NOCOUNT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE stg.OrderItems SET product_id = REPLICATE('x', 32)
    WHERE order_id = '0016dfedd97fc2950e388d2971d718c7';
    EXEC dbo.LoadOlistWarehouse;
    THROW 50400, 'Load should reject a missing product', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50301 THROW;
END CATCH;
IF (SELECT COUNT(*) FROM dbo.FactOrder) <> 4 OR (SELECT SUM(Price) FROM dbo.FactSales) <> 267.43
    THROW 50401, 'Failed load changed the existing warehouse', 1;
IF EXISTS (SELECT 1 FROM stg.OrderItems WHERE product_id = REPLICATE('x', 32))
    THROW 50402, 'Test modification was not rolled back', 1;
PRINT 'Missing lookup rejected and previous warehouse preserved';

SET NOCOUNT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT stg.OrderItems (order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value)
    SELECT REPLICATE('z', 32), 1, product_id, seller_id, shipping_limit_date, price, freight_value
    FROM stg.OrderItems WHERE order_id = '0016dfedd97fc2950e388d2971d718c7';
    EXEC dbo.LoadOlistWarehouse;
    THROW 50410, 'Load should reject orphan order items', 1;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50302 THROW;
END CATCH;
IF (SELECT COUNT(*) FROM dbo.FactOrder) <> 4 OR (SELECT SUM(Price) FROM dbo.FactSales) <> 267.43
    THROW 50411, 'Failed orphan load changed the existing warehouse', 1;
PRINT 'Orphan item rejected and previous warehouse preserved';

SET NOCOUNT ON;
IF (SELECT COUNT(*) FROM sys.tables WHERE schema_id = SCHEMA_ID(N'stg') AND name IN
    (N'Orders', N'Customers', N'Products', N'CategoryTranslation', N'Sellers', N'OrderItems', N'Payments', N'Reviews')) <> 8
    THROW 50100, 'The eight required staging tables must exist', 1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'stg.OrderItems') AND is_primary_key = 1)
    THROW 50101, 'Order item staging requires a business key', 1;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'stg.Payments') AND is_primary_key = 1)
    THROW 50102, 'Payment staging requires a business key', 1;
PRINT 'Staging schema checks passed';

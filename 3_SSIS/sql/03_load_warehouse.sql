CREATE OR ALTER PROCEDURE dbo.LoadOlistWarehouse
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        SELECT o.* INTO #Orders FROM stg.Orders o
        WHERE o.order_status NOT IN ('canceled', 'unavailable')
          AND EXISTS (SELECT 1 FROM stg.OrderItems i WHERE i.order_id = o.order_id);

        IF NOT EXISTS (SELECT 1 FROM #Orders) THROW 50300, 'No eligible orders in staging', 1;
        IF EXISTS (SELECT 1 FROM stg.OrderItems i LEFT JOIN stg.Orders o ON o.order_id=i.order_id WHERE o.order_id IS NULL)
           OR EXISTS (SELECT 1 FROM stg.Payments p LEFT JOIN stg.Orders o ON o.order_id=p.order_id WHERE o.order_id IS NULL)
           OR EXISTS (SELECT 1 FROM stg.Reviews r LEFT JOIN stg.Orders o ON o.order_id=r.order_id WHERE o.order_id IS NULL)
            THROW 50302, 'Staging contains an item, payment, or review without an order', 1;
        IF EXISTS (SELECT 1 FROM #Orders o LEFT JOIN stg.Customers c ON c.customer_id=o.customer_id WHERE c.customer_id IS NULL)
           OR EXISTS (SELECT 1 FROM stg.OrderItems i JOIN #Orders o ON o.order_id=i.order_id LEFT JOIN stg.Products p ON p.product_id=i.product_id LEFT JOIN stg.Sellers s ON s.seller_id=i.seller_id WHERE p.product_id IS NULL OR s.seller_id IS NULL)
            THROW 50301, 'Missing customer, product, or seller lookup; load aborted', 1;

        DELETE FROM dbo.FactPayment; DELETE FROM dbo.FactSales; DELETE FROM dbo.FactOrder;
        DELETE FROM dbo.DimOrder; DELETE FROM dbo.DimPayment; DELETE FROM dbo.DimSeller;
        DELETE FROM dbo.DimProduct; DELETE FROM dbo.DimCustomer; DELETE FROM dbo.DimDate;

        DECLARE @FirstDate date = (SELECT MIN(CAST(order_purchase_timestamp AS date)) FROM #Orders);
        DECLARE @LastDate date = (SELECT MAX(CAST(order_purchase_timestamp AS date)) FROM #Orders);
        ;WITH CalendarDates AS (
            SELECT @FirstDate AS dt
            UNION ALL
            SELECT DATEADD(day, 1, dt) FROM CalendarDates WHERE dt < @LastDate
        )
        INSERT dbo.DimDate (DateKey, FullDate, [Year], [Quarter], [Month], [Day], MonthName, ISOWeekdayNo, ISOWeekdayName)
        SELECT CONVERT(int, CONVERT(char(8), d.dt, 112)), d.dt, YEAR(d.dt), DATEPART(quarter,d.dt), MONTH(d.dt), DAY(d.dt),
          CHOOSE(MONTH(d.dt),'January','February','March','April','May','June','July','August','September','October','November','December'),
          w.n, CHOOSE(w.n,'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday')
        FROM CalendarDates d
        CROSS APPLY (SELECT ((DATEDIFF(day, CONVERT(date,'19000101'),d.dt) % 7 + 7) % 7) + 1 n) w
        OPTION (MAXRECURSION 0);

        INSERT dbo.DimCustomer (CustomerID,CustomerUniqueID,City,[State],Region)
        SELECT c.customer_id,c.customer_unique_id,c.customer_city,c.customer_state,
          CASE WHEN c.customer_state IN ('AC','AP','AM','PA','RO','RR','TO') THEN 'Norte' WHEN c.customer_state IN ('AL','BA','CE','MA','PB','PE','PI','RN','SE') THEN 'Nordeste' WHEN c.customer_state IN ('DF','GO','MT','MS') THEN 'Centro-Oeste' WHEN c.customer_state IN ('ES','MG','RJ','SP') THEN 'Sudeste' WHEN c.customer_state IN ('PR','RS','SC') THEN 'Sul' ELSE 'Unknown' END
        FROM stg.Customers c WHERE EXISTS (SELECT 1 FROM #Orders o WHERE o.customer_id=c.customer_id);
        INSERT dbo.DimSeller (SellerID,City,[State],Region)
        SELECT s.seller_id,s.seller_city,s.seller_state,
          CASE WHEN s.seller_state IN ('AC','AP','AM','PA','RO','RR','TO') THEN 'Norte' WHEN s.seller_state IN ('AL','BA','CE','MA','PB','PE','PI','RN','SE') THEN 'Nordeste' WHEN s.seller_state IN ('DF','GO','MT','MS') THEN 'Centro-Oeste' WHEN s.seller_state IN ('ES','MG','RJ','SP') THEN 'Sudeste' WHEN s.seller_state IN ('PR','RS','SC') THEN 'Sul' ELSE 'Unknown' END
        FROM stg.Sellers s WHERE EXISTS (SELECT 1 FROM stg.OrderItems i JOIN #Orders o ON o.order_id=i.order_id WHERE i.seller_id=s.seller_id);
        INSERT dbo.DimProduct (ProductID,CategoryOriginal,CategoryEnglish,TranslationMissing,WeightG)
        SELECT p.product_id,COALESCE(p.product_category_name,'Unknown'),COALESCE(t.product_category_name_english,p.product_category_name,'Unknown'),
          CASE WHEN p.product_category_name IS NOT NULL AND t.product_category_name IS NULL THEN 1 ELSE 0 END,p.product_weight_g
        FROM stg.Products p LEFT JOIN stg.CategoryTranslation t ON t.product_category_name=p.product_category_name
        WHERE EXISTS (SELECT 1 FROM stg.OrderItems i JOIN #Orders o ON o.order_id=i.order_id WHERE i.product_id=p.product_id);
        INSERT dbo.DimPayment (PaymentType) SELECT DISTINCT p.payment_type FROM stg.Payments p JOIN #Orders o ON o.order_id=p.order_id;
        INSERT dbo.DimOrder (OrderID) SELECT order_id FROM #Orders;

        INSERT dbo.FactSales (OrderKey,OrderItemID,DateKey,CustomerKey,ProductKey,SellerKey,Quantity,Price,FreightValue)
        SELECT od.OrderKey,i.order_item_id,CONVERT(int,CONVERT(char(8),o.order_purchase_timestamp,112)),c.CustomerKey,p.ProductKey,s.SellerKey,1,i.price,i.freight_value
        FROM #Orders o JOIN stg.OrderItems i ON i.order_id=o.order_id JOIN dbo.DimOrder od ON od.OrderID=o.order_id
        JOIN dbo.DimCustomer c ON c.CustomerID=o.customer_id JOIN dbo.DimProduct p ON p.ProductID=i.product_id JOIN dbo.DimSeller s ON s.SellerID=i.seller_id;

        INSERT dbo.FactOrder (OrderKey,DateKey,CustomerKey,ReviewID,ReviewCreationDate,ReviewScore,ReviewPresent,DeliveryDays,DeliveredFlag,LateFlag,LateEligibleFlag)
        SELECT od.OrderKey,CONVERT(int,CONVERT(char(8),o.order_purchase_timestamp,112)),c.CustomerKey,r.review_id,r.review_creation_date,r.review_score,
          CASE WHEN r.review_id IS NULL THEN 0 ELSE 1 END,
          DATEDIFF(day,CAST(o.order_purchase_timestamp AS date),CAST(o.order_delivered_customer_date AS date)),
          CASE WHEN o.order_delivered_customer_date IS NULL THEN 0 ELSE 1 END,
          CASE WHEN o.order_delivered_customer_date IS NULL OR o.order_estimated_delivery_date IS NULL THEN NULL WHEN CAST(o.order_delivered_customer_date AS date)>CAST(o.order_estimated_delivery_date AS date) THEN 1 ELSE 0 END,
          CASE WHEN o.order_delivered_customer_date IS NOT NULL AND o.order_estimated_delivery_date IS NOT NULL THEN 1 ELSE 0 END
        FROM #Orders o JOIN dbo.DimOrder od ON od.OrderID=o.order_id JOIN dbo.DimCustomer c ON c.CustomerID=o.customer_id
        OUTER APPLY (SELECT TOP (1) review_id,review_creation_date,review_score FROM stg.Reviews r WHERE r.order_id=o.order_id ORDER BY review_creation_date DESC,review_answer_timestamp DESC,review_id DESC,review_score DESC) r;

        INSERT dbo.FactPayment (OrderKey,PaymentSequential,DateKey,CustomerKey,PaymentKey,PaymentValue,PaymentInstallments)
        SELECT od.OrderKey,p.payment_sequential,CONVERT(int,CONVERT(char(8),o.order_purchase_timestamp,112)),c.CustomerKey,dp.PaymentKey,p.payment_value,p.payment_installments
        FROM #Orders o JOIN stg.Payments p ON p.order_id=o.order_id JOIN dbo.DimOrder od ON od.OrderID=o.order_id
        JOIN dbo.DimCustomer c ON c.CustomerID=o.customer_id JOIN dbo.DimPayment dp ON dp.PaymentType=p.payment_type;
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;

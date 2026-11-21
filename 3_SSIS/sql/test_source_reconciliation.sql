SET NOCOUNT ON;

SELECT o.order_id, o.customer_id, CAST(o.order_purchase_timestamp AS date) AS purchase_date,
       o.order_delivered_customer_date, o.order_estimated_delivery_date
INTO #EligibleOrders
FROM stg.Orders o
WHERE o.order_status NOT IN ('canceled', 'unavailable')
  AND EXISTS (SELECT 1 FROM stg.OrderItems i WHERE i.order_id = o.order_id);
CREATE UNIQUE CLUSTERED INDEX IX_EligibleOrders ON #EligibleOrders(order_id);

SELECT i.order_id, i.order_item_id, i.product_id, i.seller_id, o.customer_id,
       o.purchase_date, i.price, i.freight_value
INTO #ExpectedSales FROM stg.OrderItems i JOIN #EligibleOrders o ON o.order_id=i.order_id;
SELECT d.OrderID AS order_id, f.OrderItemID AS order_item_id, p.ProductID AS product_id,
       s.SellerID AS seller_id, c.CustomerID AS customer_id, dt.FullDate AS purchase_date,
       f.Price AS price, f.FreightValue AS freight_value
INTO #ActualSales FROM dbo.FactSales f
JOIN dbo.DimOrder d ON d.OrderKey=f.OrderKey JOIN dbo.DimProduct p ON p.ProductKey=f.ProductKey
JOIN dbo.DimSeller s ON s.SellerKey=f.SellerKey JOIN dbo.DimCustomer c ON c.CustomerKey=f.CustomerKey
JOIN dbo.DimDate dt ON dt.DateKey=f.DateKey;
IF EXISTS (SELECT * FROM #ExpectedSales EXCEPT SELECT * FROM #ActualSales)
   OR EXISTS (SELECT * FROM #ActualSales EXCEPT SELECT * FROM #ExpectedSales)
    THROW 50600, 'Sales rows differ from staging', 1;

SELECT p.order_id, p.payment_sequential, p.payment_type, p.payment_value, p.payment_installments,
       o.customer_id, o.purchase_date
INTO #ExpectedPayments FROM stg.Payments p JOIN #EligibleOrders o ON o.order_id=p.order_id;
SELECT d.OrderID AS order_id, f.PaymentSequential AS payment_sequential, p.PaymentType AS payment_type,
       f.PaymentValue AS payment_value, f.PaymentInstallments AS payment_installments,
       c.CustomerID AS customer_id, dt.FullDate AS purchase_date
INTO #ActualPayments FROM dbo.FactPayment f
JOIN dbo.DimOrder d ON d.OrderKey=f.OrderKey JOIN dbo.DimPayment p ON p.PaymentKey=f.PaymentKey
JOIN dbo.DimCustomer c ON c.CustomerKey=f.CustomerKey JOIN dbo.DimDate dt ON dt.DateKey=f.DateKey;
IF EXISTS (SELECT * FROM #ExpectedPayments EXCEPT SELECT * FROM #ActualPayments)
   OR EXISTS (SELECT * FROM #ActualPayments EXCEPT SELECT * FROM #ExpectedPayments)
    THROW 50601, 'Payment rows differ from staging', 1;

SELECT o.order_id, o.customer_id, o.purchase_date, r.review_id, r.review_score,
       DATEDIFF(day, o.purchase_date, CAST(o.order_delivered_customer_date AS date)) AS delivery_days,
       CASE WHEN o.order_delivered_customer_date IS NULL OR o.order_estimated_delivery_date IS NULL THEN NULL
            WHEN CAST(o.order_delivered_customer_date AS date) > CAST(o.order_estimated_delivery_date AS date) THEN 1 ELSE 0 END AS late_flag
INTO #ExpectedOrders FROM #EligibleOrders o
OUTER APPLY (SELECT TOP (1) review_id, review_score FROM stg.Reviews r WHERE r.order_id=o.order_id
             ORDER BY review_creation_date DESC, review_answer_timestamp DESC, review_id DESC, review_score DESC) r;
SELECT d.OrderID AS order_id, c.CustomerID AS customer_id, dt.FullDate AS purchase_date,
       f.ReviewID AS review_id, f.ReviewScore AS review_score, f.DeliveryDays AS delivery_days,
       CONVERT(int, f.LateFlag) AS late_flag
INTO #ActualOrders FROM dbo.FactOrder f JOIN dbo.DimOrder d ON d.OrderKey=f.OrderKey
JOIN dbo.DimCustomer c ON c.CustomerKey=f.CustomerKey JOIN dbo.DimDate dt ON dt.DateKey=f.DateKey;
IF EXISTS (SELECT * FROM #ExpectedOrders EXCEPT SELECT * FROM #ActualOrders)
   OR EXISTS (SELECT * FROM #ActualOrders EXCEPT SELECT * FROM #ExpectedOrders)
    THROW 50602, 'Order rows differ from staging', 1;
PRINT 'Staging-to-warehouse row reconciliation passed';

-- Run against staging after a failed warehouse load; this does not change data.
SET NOCOUNT ON;

SELECT issue, order_id, source_key, price, freight, payment
INTO #Issues
FROM (
    SELECT 'Missing customer' AS issue, o.order_id, o.customer_id AS source_key,
           CAST(NULL AS decimal(19,2)) AS price, CAST(NULL AS decimal(19,2)) AS freight,
           CAST(NULL AS decimal(19,2)) AS payment
    FROM stg.Orders o LEFT JOIN stg.Customers c ON c.customer_id = o.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable') AND c.customer_id IS NULL
      AND EXISTS (SELECT 1 FROM stg.OrderItems i WHERE i.order_id = o.order_id)
    UNION ALL
    SELECT 'Orphan item', i.order_id, CONVERT(varchar(32), i.order_item_id), i.price, i.freight_value, NULL
    FROM stg.OrderItems i LEFT JOIN stg.Orders o ON o.order_id = i.order_id WHERE o.order_id IS NULL
    UNION ALL
    SELECT 'Missing product', i.order_id, i.product_id, i.price, i.freight_value, NULL
    FROM stg.OrderItems i JOIN stg.Orders o ON o.order_id = i.order_id
    LEFT JOIN stg.Products p ON p.product_id = i.product_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable') AND p.product_id IS NULL
    UNION ALL
    SELECT 'Missing seller', i.order_id, i.seller_id, i.price, i.freight_value, NULL
    FROM stg.OrderItems i JOIN stg.Orders o ON o.order_id = i.order_id
    LEFT JOIN stg.Sellers s ON s.seller_id = i.seller_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable') AND s.seller_id IS NULL
    UNION ALL
    SELECT 'Orphan payment', p.order_id, CONVERT(varchar(32), p.payment_sequential), NULL, NULL, p.payment_value
    FROM stg.Payments p LEFT JOIN stg.Orders o ON o.order_id = p.order_id WHERE o.order_id IS NULL
    UNION ALL
    SELECT 'Orphan review', r.order_id, r.review_id, NULL, NULL, NULL
    FROM stg.Reviews r LEFT JOIN stg.Orders o ON o.order_id = r.order_id WHERE o.order_id IS NULL
) issues;

SELECT issue, COUNT(*) AS row_count, SUM(price) AS price, SUM(freight) AS freight, SUM(payment) AS payment
FROM #Issues GROUP BY issue ORDER BY issue;
SELECT issue, order_id, source_key, price, freight, payment FROM #Issues ORDER BY issue, order_id, source_key;

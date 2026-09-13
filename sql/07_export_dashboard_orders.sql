-- Creates the order-level dataset used by the Tableau dashboard.
-- Run this entire file. It reads data without changing any tables.
-- Expected result: 95,461 rows, with one row per delivered order.
-- To export: save the results with column headers as
-- olist_dashboard_orders.csv.

USE Olist;
GO

;WITH payments_per_order AS (
    SELECT order_id, SUM(payment_value) AS payment_value
    FROM dbo.order_payments GROUP BY order_id
)
SELECT o.order_id,c.customer_unique_id,CAST(o.order_purchase_timestamp AS date) AS purchase_date,
 c.customer_state,p.payment_value,
 CAST(o.order_delivered_customer_date AS date) AS actual_delivery_date,
 CAST(o.order_estimated_delivery_date AS date) AS estimated_delivery_date,
 CASE
        WHEN o.order_delivered_customer_date IS NULL
          OR o.order_estimated_delivery_date IS NULL THEN 'Unknown'
        WHEN o.order_delivered_customer_date < o.order_purchase_timestamp
            THEN 'Invalid chronology'
        WHEN CAST(o.order_delivered_customer_date AS date)
             <= CAST(o.order_estimated_delivery_date AS date) THEN 'On time'
        ELSE 'Late'
    END AS delivery_performance
FROM dbo.orders o JOIN dbo.customers c ON o.customer_id=c.customer_id LEFT JOIN payments_per_order p ON o.order_id=p.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901';

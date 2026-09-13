-- Olist portfolio project: Microsoft SQL Server (T-SQL)
-- Recovered from the project conversation. Read-only SELECT statements.
-- Run one numbered question at a time in SSMS; CTEs belong to the next SELECT only.
USE Olist;
GO

;WITH payments_per_order AS (
    SELECT order_id, SUM(payment_value) AS payment_value
    FROM dbo.order_payments GROUP BY order_id
), order_summary AS (
 SELECT o.order_id,c.customer_unique_id,p.payment_value,CASE
        WHEN o.order_delivered_customer_date IS NULL
          OR o.order_estimated_delivery_date IS NULL THEN 'Unknown'
        WHEN o.order_delivered_customer_date < o.order_purchase_timestamp
            THEN 'Invalid chronology'
        WHEN CAST(o.order_delivered_customer_date AS date)
             <= CAST(o.order_estimated_delivery_date AS date) THEN 'On time'
        ELSE 'Late'
    END AS delivery_performance
 FROM dbo.orders o JOIN dbo.customers c ON o.customer_id=c.customer_id LEFT JOIN payments_per_order p ON o.order_id=p.order_id WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901'
)
SELECT COUNT(*) AS delivered_orders,COUNT(DISTINCT customer_unique_id) AS total_customers,
 CAST(SUM(payment_value) AS decimal(18,2)) AS total_payment_value,
 CAST(AVG(payment_value) AS decimal(18,2)) AS avg_payment_per_order,
 SUM(CASE WHEN delivery_performance IN ('On time','Late') THEN 1 ELSE 0 END) AS assessable_orders,
 SUM(CASE WHEN delivery_performance='On time' THEN 1 ELSE 0 END) AS on_time_orders,
 SUM(CASE WHEN delivery_performance='Late' THEN 1 ELSE 0 END) AS late_orders,
 SUM(CASE WHEN delivery_performance IN ('Unknown','Invalid chronology') THEN 1 ELSE 0 END) AS unassessable_orders,
 CAST(100.0*SUM(CASE WHEN delivery_performance='On time' THEN 1 ELSE 0 END)
 /NULLIF(SUM(CASE WHEN delivery_performance IN ('On time','Late') THEN 1 ELSE 0 END),0) AS decimal(6,2)) AS on_time_delivery_pct
FROM order_summary;

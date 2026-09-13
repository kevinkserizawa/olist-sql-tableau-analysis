-- Olist portfolio project: Microsoft SQL Server (T-SQL)
-- Recovered from the project conversation. Read-only SELECT statements.
-- Run one numbered question at a time in SSMS; CTEs belong to the next SELECT only.
USE Olist;
GO

-- 1. Repeat orders within the analysis window (not lifetime retention).
;WITH customer_orders AS (
 SELECT c.customer_unique_id,COUNT(*) AS delivered_orders,
 COUNT(DISTINCT CAST(o.order_purchase_timestamp AS date)) AS purchase_dates
 FROM dbo.orders o JOIN dbo.customers c ON o.customer_id=c.customer_id WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901' AND c.customer_unique_id IS NOT NULL
 GROUP BY c.customer_unique_id
)
SELECT COUNT(*) AS total_customers,
 SUM(CASE WHEN delivered_orders=1 THEN 1 ELSE 0 END) AS one_order_customers,
 SUM(CASE WHEN delivered_orders>1 THEN 1 ELSE 0 END) AS repeat_customers,
 CAST(100.0*SUM(CASE WHEN delivered_orders>1 THEN 1 ELSE 0 END)/NULLIF(COUNT(*),0) AS decimal(6,2)) AS repeat_customer_pct
FROM customer_orders;

-- 2. Contribution includes all orders by repeat customers, including their first.
;WITH payments_per_order AS (
    SELECT order_id, SUM(payment_value) AS payment_value
    FROM dbo.order_payments GROUP BY order_id
), customer_summary AS (
 SELECT c.customer_unique_id,COUNT(*) AS delivered_orders,SUM(p.payment_value) AS total_payment_value
 FROM dbo.orders o JOIN dbo.customers c ON o.customer_id=c.customer_id LEFT JOIN payments_per_order p ON o.order_id=p.order_id
 WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901' AND c.customer_unique_id IS NOT NULL GROUP BY c.customer_unique_id
), segments AS (
 SELECT CASE WHEN delivered_orders=1 THEN 'One-order customers' ELSE 'Repeat customers' END AS customer_segment,
 delivered_orders,total_payment_value FROM customer_summary
)
SELECT customer_segment,COUNT(*) AS total_customers,SUM(delivered_orders) AS total_orders,
 CAST(100.0*SUM(delivered_orders)/NULLIF(SUM(SUM(delivered_orders)) OVER (),0) AS decimal(6,2)) AS order_share_pct,
 ROUND(SUM(total_payment_value),2) AS total_payment_value,
 CAST(100.0*SUM(total_payment_value)/NULLIF(SUM(SUM(total_payment_value)) OVER (),0) AS decimal(6,2)) AS payment_share_pct
FROM segments GROUP BY customer_segment ORDER BY total_customers DESC;

-- 3. First-to-second order timing; same-day orders are a separate bucket.
;WITH ranked_orders AS (
 SELECT c.customer_unique_id,o.order_purchase_timestamp,
 ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id ORDER BY o.order_purchase_timestamp,o.order_id) AS purchase_number
 FROM dbo.orders o JOIN dbo.customers c ON o.customer_id=c.customer_id WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901' AND c.customer_unique_id IS NOT NULL
), first_two AS (
 SELECT customer_unique_id,
 MAX(CASE WHEN purchase_number=1 THEN order_purchase_timestamp END) AS first_purchase,
 MAX(CASE WHEN purchase_number=2 THEN order_purchase_timestamp END) AS second_purchase
 FROM ranked_orders GROUP BY customer_unique_id
), timing AS (
 SELECT DATEDIFF(DAY,first_purchase,second_purchase) AS days_to_second FROM first_two WHERE second_purchase IS NOT NULL
), buckets AS (
 SELECT CASE WHEN days_to_second=0 THEN 1 WHEN days_to_second<=30 THEN 2 WHEN days_to_second<=90 THEN 3 ELSE 4 END AS sort_order,
 CASE WHEN days_to_second=0 THEN 'Same calendar day' WHEN days_to_second<=30 THEN '1-30 days'
 WHEN days_to_second<=90 THEN '31-90 days' ELSE '91+ days' END AS repeat_timing FROM timing
)
SELECT repeat_timing,COUNT(*) AS repeat_customers,
 CAST(100.0*COUNT(*)/SUM(COUNT(*)) OVER () AS decimal(6,2)) AS pct_of_repeat_customers
FROM buckets GROUP BY sort_order,repeat_timing ORDER BY sort_order;

-- 4. All purchase dates distinguish same-day-only orders from later-date purchases.
;WITH customer_orders AS (
 SELECT c.customer_unique_id,COUNT(*) AS delivered_orders,
 COUNT(DISTINCT CAST(o.order_purchase_timestamp AS date)) AS purchase_dates
 FROM dbo.orders o JOIN dbo.customers c ON o.customer_id=c.customer_id WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901' AND c.customer_unique_id IS NOT NULL
 GROUP BY c.customer_unique_id
), groups AS (
 SELECT CASE WHEN delivered_orders=1 THEN 'One order'
 WHEN purchase_dates=1 THEN 'Multiple orders on one date' ELSE 'Orders on multiple dates' END AS customer_group
 FROM customer_orders
)
SELECT customer_group,COUNT(*) AS total_customers,
 CAST(100.0*COUNT(*)/SUM(COUNT(*)) OVER () AS decimal(6,2)) AS pct_of_all_customers
FROM groups GROUP BY customer_group ORDER BY total_customers DESC;

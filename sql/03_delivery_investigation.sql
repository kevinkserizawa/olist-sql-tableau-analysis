-- Olist portfolio project: Microsoft SQL Server (T-SQL)
-- Recovered from the project conversation. Read-only SELECT statements.
-- Run one numbered question at a time in SSMS; CTEs belong to the next SELECT only.
USE Olist;
GO

-- 1. State delay rates: denominator excludes missing/invalid timing.
;WITH d AS (
 SELECT c.customer_state, CASE WHEN o.order_delivered_customer_date IS NULL OR o.order_estimated_delivery_date IS NULL THEN NULL
    WHEN o.order_delivered_customer_date < o.order_purchase_timestamp THEN NULL
    WHEN CAST(o.order_delivered_customer_date AS date)>CAST(o.order_estimated_delivery_date AS date) THEN 1
    ELSE 0 END AS is_late
 FROM dbo.orders o JOIN dbo.customers c ON o.customer_id=c.customer_id WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901'
)
SELECT customer_state,COUNT(*) AS delivered_orders,COUNT(is_late) AS assessable_orders,
 SUM(is_late) AS late_orders,COUNT(*)-COUNT(is_late) AS unassessable_orders,
 CAST(100.0*SUM(is_late)/NULLIF(COUNT(is_late),0) AS decimal(6,2)) AS late_delivery_pct
FROM d GROUP BY customer_state ORDER BY late_delivery_pct DESC,late_orders DESC,customer_state;

-- 2. RJ by purchase month
;WITH d AS (
 SELECT YEAR(o.order_purchase_timestamp) AS order_year,
 MONTH(o.order_purchase_timestamp) AS order_month,CASE WHEN c.customer_state='RJ' THEN 'RJ' ELSE 'Other states' END AS customer_region,CASE WHEN o.order_delivered_customer_date IS NULL OR o.order_estimated_delivery_date IS NULL THEN NULL
    WHEN o.order_delivered_customer_date < o.order_purchase_timestamp THEN NULL
    WHEN CAST(o.order_delivered_customer_date AS date)>CAST(o.order_estimated_delivery_date AS date) THEN 1
    ELSE 0 END AS is_late
 FROM dbo.orders o JOIN dbo.customers c ON o.customer_id=c.customer_id WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901' AND c.customer_state IS NOT NULL
 AND c.customer_state='RJ'
)
SELECT order_year,order_month,customer_region,COUNT(*) AS delivered_orders,
 COUNT(is_late) AS assessable_orders,SUM(is_late) AS late_orders,
 CAST(100.0*SUM(is_late)/NULLIF(COUNT(is_late),0) AS decimal(6,2)) AS late_delivery_pct
FROM d GROUP BY order_year,order_month,customer_region
ORDER BY order_year,order_month,customer_region;

-- 3. RJ versus other states by purchase month
;WITH d AS (
 SELECT YEAR(o.order_purchase_timestamp) AS order_year,
 MONTH(o.order_purchase_timestamp) AS order_month,CASE WHEN c.customer_state='RJ' THEN 'RJ' ELSE 'Other states' END AS customer_region,CASE WHEN o.order_delivered_customer_date IS NULL OR o.order_estimated_delivery_date IS NULL THEN NULL
    WHEN o.order_delivered_customer_date < o.order_purchase_timestamp THEN NULL
    WHEN CAST(o.order_delivered_customer_date AS date)>CAST(o.order_estimated_delivery_date AS date) THEN 1
    ELSE 0 END AS is_late
 FROM dbo.orders o JOIN dbo.customers c ON o.customer_id=c.customer_id WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901' AND c.customer_state IS NOT NULL
 
)
SELECT order_year,order_month,customer_region,COUNT(*) AS delivered_orders,
 COUNT(is_late) AS assessable_orders,SUM(is_late) AS late_orders,
 CAST(100.0*SUM(is_late)/NULLIF(COUNT(is_late),0) AS decimal(6,2)) AS late_delivery_pct
FROM d GROUP BY order_year,order_month,customer_region
ORDER BY order_year,order_month,customer_region;

-- 4. Actual versus estimated calendar-day duration in affected purchase months.
;WITH d AS (
 SELECT YEAR(o.order_purchase_timestamp) AS order_year,MONTH(o.order_purchase_timestamp) AS order_month,
 CASE WHEN c.customer_state='RJ' THEN 'RJ' ELSE 'Other states' END AS customer_region,
 DATEDIFF(DAY,o.order_purchase_timestamp,o.order_delivered_customer_date) AS actual_days,
 DATEDIFF(DAY,o.order_purchase_timestamp,o.order_estimated_delivery_date) AS estimated_days
 FROM dbo.orders o JOIN dbo.customers c ON o.customer_id=c.customer_id WHERE o.order_status='delivered' AND o.order_purchase_timestamp >= '20171101' AND o.order_purchase_timestamp < '20180401' AND c.customer_state IS NOT NULL
 AND o.order_delivered_customer_date IS NOT NULL AND o.order_estimated_delivery_date IS NOT NULL
 AND o.order_delivered_customer_date >= o.order_purchase_timestamp
)
SELECT order_year,order_month,customer_region,COUNT(*) AS assessed_orders,
 CAST(AVG(1.0*actual_days) AS decimal(10,2)) AS avg_actual_days,
 CAST(AVG(1.0*estimated_days) AS decimal(10,2)) AS avg_estimated_days,
 CAST(AVG(1.0*actual_days-estimated_days) AS decimal(10,2)) AS avg_days_vs_estimate
FROM d GROUP BY order_year,order_month,customer_region ORDER BY order_year,order_month,customer_region;

-- 5. Stage durations: both averages use the same valid orders.
;WITH d AS (
 SELECT YEAR(o.order_purchase_timestamp) AS order_year,MONTH(o.order_purchase_timestamp) AS order_month,
 CASE WHEN c.customer_state='RJ' THEN 'RJ' ELSE 'Other states' END AS customer_region,
 CASE WHEN o.order_delivered_carrier_date IS NOT NULL AND o.order_delivered_customer_date IS NOT NULL
 AND o.order_delivered_carrier_date >= o.order_purchase_timestamp
 AND o.order_delivered_customer_date >= o.order_delivered_carrier_date THEN 1 ELSE 0 END AS valid_stages,
 DATEDIFF(DAY,o.order_purchase_timestamp,o.order_delivered_carrier_date) AS days_to_carrier,
 DATEDIFF(DAY,o.order_delivered_carrier_date,o.order_delivered_customer_date) AS days_after_carrier
 FROM dbo.orders o JOIN dbo.customers c ON o.customer_id=c.customer_id WHERE o.order_status='delivered' AND o.order_purchase_timestamp >= '20171101' AND o.order_purchase_timestamp < '20180401' AND c.customer_state IS NOT NULL
)
SELECT order_year,order_month,customer_region,COUNT(*) AS delivered_orders,SUM(valid_stages) AS orders_used,
 COUNT(*)-SUM(valid_stages) AS excluded_orders,
 CAST(AVG(CASE WHEN valid_stages=1 THEN 1.0*days_to_carrier END) AS decimal(10,2)) AS avg_days_to_carrier,
 CAST(AVG(CASE WHEN valid_stages=1 THEN 1.0*days_after_carrier END) AS decimal(10,2)) AS avg_days_after_carrier
FROM d GROUP BY order_year,order_month,customer_region ORDER BY order_year,order_month,customer_region;

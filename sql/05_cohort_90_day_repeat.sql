-- Olist portfolio project: Microsoft SQL Server (T-SQL)
-- Recovered from the project conversation. Read-only SELECT statements.
-- Run one numbered question at a time in SSMS; CTEs belong to the next SELECT only.
USE Olist;
GO

-- Final faster version: distinct purchase dates then ROW_NUMBER, not correlated EXISTS.
-- First observed delivered purchase uses all available earlier history.
-- Cohorts Feb 2017-May 2018 have 90 calendar days before Aug 31 cutoff.
;WITH customer_purchase_dates AS (
 SELECT DISTINCT c.customer_unique_id,CAST(o.order_purchase_timestamp AS date) AS purchase_date
 FROM dbo.orders o JOIN dbo.customers c ON o.customer_id=c.customer_id WHERE o.order_status='delivered' AND o.order_purchase_timestamp < '20180901'
 AND c.customer_unique_id IS NOT NULL
), ranked_dates AS (
 SELECT customer_unique_id,purchase_date,
 ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY purchase_date) AS date_number
 FROM customer_purchase_dates
), first_two_dates AS (
 SELECT customer_unique_id,
 MAX(CASE WHEN date_number=1 THEN purchase_date END) AS first_purchase_date,
 MAX(CASE WHEN date_number=2 THEN purchase_date END) AS second_purchase_date
 FROM ranked_dates WHERE date_number<=2 GROUP BY customer_unique_id
)
SELECT YEAR(first_purchase_date) AS first_purchase_year,MONTH(first_purchase_date) AS first_purchase_month,
 COUNT(*) AS eligible_customers,
 SUM(CASE WHEN second_purchase_date<=DATEADD(DAY,90,first_purchase_date) THEN 1 ELSE 0 END) AS repeat_customers_90d,
 CAST(100.0*SUM(CASE WHEN second_purchase_date<=DATEADD(DAY,90,first_purchase_date) THEN 1 ELSE 0 END)
 /NULLIF(COUNT(*),0) AS decimal(6,2)) AS repeat_rate_90d_pct
FROM first_two_dates WHERE first_purchase_date >= '20170201' AND first_purchase_date < '20180601'
GROUP BY YEAR(first_purchase_date),MONTH(first_purchase_date)
ORDER BY first_purchase_year,first_purchase_month;

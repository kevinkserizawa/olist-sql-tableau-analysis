-- Olist portfolio project: Microsoft SQL Server (T-SQL)
-- Recovered from the project conversation. Read-only SELECT statements.
-- Run one numbered question at a time in SSMS; CTEs belong to the next SELECT only.
USE Olist;
GO

-- These are the checks recovered here, not the complete earlier Phase 4 audit.
-- 1. Purchase-date coverage and delivered-order counts.
SELECT YEAR(order_purchase_timestamp) AS order_year,
    MONTH(order_purchase_timestamp) AS order_month,
    MIN(order_purchase_timestamp) AS first_purchase,
    MAX(order_purchase_timestamp) AS last_purchase,
    COUNT(*) AS all_orders,
    SUM(CASE WHEN order_status='delivered' THEN 1 ELSE 0 END) AS delivered_orders
FROM dbo.orders
GROUP BY YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp)
ORDER BY order_year, order_month;

-- 2. Delivered orders without payment records: observed one order in September 2016.
SELECT o.order_id, o.order_purchase_timestamp, o.order_status
FROM dbo.orders AS o
WHERE o.order_status='delivered'
  AND NOT EXISTS (SELECT 1 FROM dbo.order_payments AS p WHERE p.order_id=o.order_id)
ORDER BY o.order_purchase_timestamp;

-- 3. Known timestamp anomalies: flag; do not delete automatically.
SELECT
    SUM(CASE WHEN order_delivered_carrier_date < order_purchase_timestamp THEN 1 ELSE 0 END) AS carrier_before_purchase,
    SUM(CASE WHEN order_delivered_customer_date < order_delivered_carrier_date THEN 1 ELSE 0 END) AS customer_before_carrier,
    SUM(CASE WHEN order_delivered_carrier_date < order_approved_at THEN 1 ELSE 0 END) AS carrier_before_approval
FROM dbo.orders;

-- 4. Relationship validation. NULL product categories are deliberately excluded.
SELECT 'orders -> customers' AS relationship, COUNT(*) AS unmatched_rows
FROM dbo.orders o LEFT JOIN dbo.customers c ON o.customer_id=c.customer_id WHERE c.customer_id IS NULL
UNION ALL SELECT 'order_items -> orders', COUNT(*)
FROM dbo.order_items i LEFT JOIN dbo.orders o ON i.order_id=o.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'order_items -> products', COUNT(*)
FROM dbo.order_items i LEFT JOIN dbo.products p ON i.product_id=p.product_id WHERE p.product_id IS NULL
UNION ALL SELECT 'order_items -> sellers', COUNT(*)
FROM dbo.order_items i LEFT JOIN dbo.sellers s ON i.seller_id=s.seller_id WHERE s.seller_id IS NULL
UNION ALL SELECT 'order_payments -> orders', COUNT(*)
FROM dbo.order_payments p LEFT JOIN dbo.orders o ON p.order_id=o.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'order_reviews -> orders', COUNT(*)
FROM dbo.order_reviews r LEFT JOIN dbo.orders o ON r.order_id=o.order_id WHERE o.order_id IS NULL
UNION ALL SELECT 'products -> category_translation', COUNT(*)
FROM dbo.products p LEFT JOIN dbo.category_translation c ON p.product_category_name=c.product_category_name
WHERE p.product_category_name IS NOT NULL AND c.product_category_name IS NULL;

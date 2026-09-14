-- Olist portfolio project: Microsoft SQL Server (T-SQL)
-- Recovered from the project conversation. Read-only SELECT statements.
-- Run one numbered question at a time in SSMS; CTEs belong to the next SELECT only.
USE Olist;
GO

-- Q1. Monthly payments and delivered orders (payments include freight).
SELECT YEAR(o.order_purchase_timestamp) AS order_year,
    MONTH(o.order_purchase_timestamp) AS order_month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(p.payment_value),2) AS total_payment_value
FROM dbo.orders o LEFT JOIN dbo.order_payments p ON o.order_id=p.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901'
GROUP BY YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp)
ORDER BY order_year, order_month;

-- Q2. Category merchandise sales: excludes freight; no payments join.
SELECT TRIM(COALESCE(ct.product_category_name_english, p.product_category_name, 'unknown')) AS product_category,
    COUNT(*) AS items_sold, COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price),2) AS merchandise_sales
FROM dbo.orders o JOIN dbo.order_items oi ON o.order_id=oi.order_id
LEFT JOIN dbo.products p ON oi.product_id=p.product_id
LEFT JOIN dbo.category_translation ct ON p.product_category_name=ct.product_category_name
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901'
GROUP BY TRIM(COALESCE(ct.product_category_name_english, p.product_category_name, 'unknown'))
ORDER BY merchandise_sales DESC, product_category;

-- Q3. Categories by orders. Orders may appear in multiple categories.
SELECT TRIM(COALESCE(ct.product_category_name_english, p.product_category_name, 'unknown')) AS product_category,
    COUNT(*) AS items_sold, COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price),2) AS merchandise_sales
FROM dbo.orders o JOIN dbo.order_items oi ON o.order_id=oi.order_id
LEFT JOIN dbo.products p ON oi.product_id=p.product_id
LEFT JOIN dbo.category_translation ct ON p.product_category_name=ct.product_category_name
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901'
GROUP BY TRIM(COALESCE(ct.product_category_name_english, p.product_category_name, 'unknown'))
ORDER BY total_orders DESC, merchandise_sales DESC, product_category;

-- Q4. Customer state. A customer can appear in more than one state.
;WITH payments_per_order AS (
    SELECT order_id, SUM(payment_value) AS payment_value
    FROM dbo.order_payments GROUP BY order_id
)
SELECT c.customer_state, COUNT(DISTINCT c.customer_unique_id) AS total_customers,
    COUNT(*) AS total_orders, ROUND(SUM(p.payment_value),2) AS total_payment_value
FROM dbo.orders o JOIN dbo.customers c ON o.customer_id=c.customer_id
LEFT JOIN payments_per_order p ON o.order_id=p.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901'
GROUP BY c.customer_state ORDER BY total_payment_value DESC, c.customer_state;

-- Q5. Payment methods. Order counts across methods can overlap.
SELECT p.payment_type, COUNT(*) AS payment_records,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(p.payment_value),2) AS total_payment_value
FROM dbo.orders o JOIN dbo.order_payments p ON o.order_id=p.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901'
GROUP BY p.payment_type ORDER BY total_orders DESC, p.payment_type;

-- Q6. Delivery classification. This percentage includes unassessable orders.
;WITH delivery_classification AS (
    SELECT o.order_id, CASE
        WHEN o.order_delivered_customer_date IS NULL
          OR o.order_estimated_delivery_date IS NULL THEN 'Unknown'
        WHEN o.order_delivered_customer_date < o.order_purchase_timestamp
            THEN 'Invalid chronology'
        WHEN CAST(o.order_delivered_customer_date AS date)
             <= CAST(o.order_estimated_delivery_date AS date) THEN 'On time'
        ELSE 'Late'
    END AS delivery_performance
    FROM dbo.orders AS o WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901'
)
SELECT delivery_performance, COUNT(*) AS total_orders,
    CAST(100.0*COUNT(*)/SUM(COUNT(*)) OVER () AS decimal(6,2)) AS pct_of_delivered_orders
FROM delivery_classification GROUP BY delivery_performance ORDER BY total_orders DESC;

-- Q7. Reviews: average per order first, then average across reviewed orders.
;WITH delivery_classification AS (
    SELECT o.order_id, CASE
        WHEN o.order_delivered_customer_date IS NULL
          OR o.order_estimated_delivery_date IS NULL THEN 'Unknown'
        WHEN o.order_delivered_customer_date < o.order_purchase_timestamp
            THEN 'Invalid chronology'
        WHEN CAST(o.order_delivered_customer_date AS date)
             <= CAST(o.order_estimated_delivery_date AS date) THEN 'On time'
        ELSE 'Late'
    END AS delivery_performance
    FROM dbo.orders AS o WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901'
), reviews_per_order AS (
    SELECT order_id,
        AVG(CAST(review_score AS decimal(10,4))) AS order_avg_review_score
    FROM dbo.order_reviews WHERE review_score BETWEEN 1 AND 5
    GROUP BY order_id
)
SELECT d.delivery_performance, COUNT(*) AS total_orders,
    COUNT(r.order_avg_review_score) AS reviewed_orders,
    CAST(AVG(r.order_avg_review_score) AS decimal(10,2)) AS avg_review_score
FROM delivery_classification d LEFT JOIN reviews_per_order r ON d.order_id=r.order_id
GROUP BY d.delivery_performance ORDER BY total_orders DESC;

-- Q8. Seller merchandise sales. Multi-seller orders count for each participating seller.
SELECT oi.seller_id, s.seller_state, COUNT(DISTINCT oi.order_id) AS total_orders,
    COUNT(*) AS items_sold, ROUND(SUM(oi.price),2) AS merchandise_sales
FROM dbo.orders o JOIN dbo.order_items oi ON o.order_id=oi.order_id
LEFT JOIN dbo.sellers s ON oi.seller_id=s.seller_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901'
GROUP BY oi.seller_id,s.seller_state ORDER BY merchandise_sales DESC,oi.seller_id;

-- Q9. Sales leaders and associated order reviews, not direct seller ratings.
;WITH seller_orders AS (
    SELECT oi.seller_id,o.order_id,SUM(oi.price) AS merchandise_sales
    FROM dbo.orders o JOIN dbo.order_items oi ON o.order_id=oi.order_id
    WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901'
    GROUP BY oi.seller_id,o.order_id
), reviews_per_order AS (
    SELECT order_id,
        AVG(CAST(review_score AS decimal(10,4))) AS order_avg_review_score
    FROM dbo.order_reviews WHERE review_score BETWEEN 1 AND 5
    GROUP BY order_id
)
SELECT so.seller_id,COUNT(*) AS total_orders,
    ROUND(SUM(so.merchandise_sales),2) AS merchandise_sales,
    COUNT(r.order_avg_review_score) AS reviewed_orders,
    CAST(AVG(r.order_avg_review_score) AS decimal(10,2)) AS avg_order_review_score
FROM seller_orders so LEFT JOIN reviews_per_order r ON so.order_id=r.order_id
GROUP BY so.seller_id ORDER BY merchandise_sales DESC,so.seller_id;

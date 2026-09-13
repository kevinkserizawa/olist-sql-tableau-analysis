-- Olist portfolio project: Microsoft SQL Server (T-SQL)
-- Recovered from the project conversation.
-- Run this entire file.

USE Olist;
GO

-- TRIM is included to remove trailing spaces from category labels.
 
SELECT oi.order_id,oi.order_item_id,oi.product_id,oi.seller_id,
 TRIM(COALESCE(ct.product_category_name_english, p.product_category_name, 'unknown')) AS product_category,oi.price AS merchandise_sales,oi.freight_value
FROM dbo.orders o JOIN dbo.order_items oi ON o.order_id=oi.order_id
LEFT JOIN dbo.products p ON oi.product_id=p.product_id
LEFT JOIN dbo.category_translation ct ON p.product_category_name=ct.product_category_name
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '20170201'
  AND o.order_purchase_timestamp < '20180901';

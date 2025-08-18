-- SELECT * FROM customers;
-- SELECT * FROM order_items;
-- SELECT * FROM orders;
-- SELECT * FROM staffs;
-- SELECT * FROM stores;
-- SELECT * FROM brands;



-- list brands by number of sales (highest to lowest)

WITH product_quantities AS (
SELECT oi.product_id, 
	quantity, 
    p.brand_id, 
    brand_name
FROM order_items oi
JOIN products p
	ON oi.product_id = p.product_id
JOIN brands b
	ON p.brand_id = b.brand_id
)
SELECT brand_name, 
	SUM(quantity) as total_quantity_sales
FROM product_quantities
GROUP BY brand_name
ORDER BY SUM(quantity) DESC
;



-- list brands by revenue  (highest to lowest)

WITH order_products_id AS (
SELECT oi.product_id, 
	quantity, 
    oi.list_price, 
    discount, 
    p.brand_id, 
    brand_name
FROM order_items oi
JOIN products p
	ON oi.product_id = p.product_id
JOIN brands b
	ON p.brand_id = b.brand_id
),
compute_revenue AS (
SELECT *,
	quantity * (list_price * (1 - discount)) AS revenue
FROM order_products_id
)
SELECT brand_name, 
	ROUND(SUM(revenue), 2) as total_revenue
FROM compute_revenue
GROUP BY brand_name
ORDER BY SUM(revenue) DESC
;



-- list number of repeat and new customers

WITH get_customer_status AS (
SELECT c.customer_id, 
	first_name, 
    last_name,
	CASE WHEN COUNT(DISTINCT o.order_id) > 1 THEN 'Repeat'
	ELSE 'New'
    END AS customer_status
FROM customers c
JOIN orders o
	ON o.customer_id = c.customer_id
GROUP BY c.customer_id, first_name, last_name
)
SELECT customer_status, 
	COUNT(customer_status) AS amount
FROM get_customer_status
GROUP BY customer_status
;



-- list total customers, percentage of repeat customers by store 

WITH get_store_customer_status AS (
SELECT c.customer_id, 
	s.store_name,
	CASE WHEN COUNT(DISTINCT o.order_id) > 1 THEN 'Repeat'
	ELSE 'New'
    END AS customer_status
FROM customers c
JOIN orders o
	ON o.customer_id = c.customer_id
JOIN stores s
	ON o.store_id = s.store_id
GROUP BY c.customer_id, s.store_name
)
SELECT store_name, 
	COUNT(CASE WHEN customer_status = 'Repeat' THEN 1 END) AS repeat_customers,
	COUNT(CASE WHEN customer_status = 'New' THEN 1 END) AS new_customers,
	COUNT(*) AS total_customers,
	ROUND(100.0 * COUNT(CASE WHEN customer_status = 'Repeat' THEN 1 END) / COUNT(*) , 2) AS percent_repeat_customers
FROM get_store_customer_status
GROUP BY store_name
ORDER BY 4 DESC
;


-- list brands with the most total discount (in USD). 

WITH get_discount AS (
SELECT oi.product_id, 
	quantity, 
    oi.list_price, 
    discount, 
    p.brand_id, 
    brand_name,
	quantity * (oi.list_price * oi.discount) AS discount_in_usd
FROM order_items oi
JOIN products p
	ON oi.product_id = p.product_id
JOIN brands b
	ON p.brand_id = b.brand_id
)
SELECT brand_name, 
	SUM(quantity) AS total_quantity_sales, 
	ROUND(SUM(discount_in_usd), 2) AS total_discount
FROM get_discount
GROUP BY brand_name
ORDER BY SUM(discount_in_usd) DESC
;



--  annual revenue of stores

WITH get_year_sales AS (
SELECT o.order_id, 
	SUBSTRING(order_date, 1, 4) AS `year`, 
    quantity, 
    list_price, 
    discount, 
    store_name
FROM orders o
JOIN order_items oi
	ON o.order_id = oi.order_id
JOIN stores s
	ON o.store_id = s.store_id
)
SELECT `year`, 
	ROUND(SUM(CASE WHEN store_name = 'Baldwin Bikes' THEN quantity * (list_price * (1 - discount)) ELSE 0 END), 2) AS Baldwin_Bikes_revenue,
	ROUND(SUM(CASE WHEN store_name = 'Rowlett Bikes' THEN quantity * (list_price * (1 - discount)) ELSE 0 END), 2) AS Rowlett_Bikes_revenue,
	ROUND(SUM(CASE WHEN store_name = 'Santa Cruz Bikes' THEN quantity * (list_price * (1 - discount)) ELSE 0 END), 2) AS SantaCruz_Bikes_revenue
FROM get_year_sales
GROUP BY `year`
;



-- top 5 categories by revenue per store

WITH get_category_sales AS (
SELECT oi.product_id, 
	oi.quantity, 
    oi.list_price, 
    discount, 
	oi.quantity * (oi.list_price * (1 - discount)) AS revenue,
	category_name, 
    store_name
FROM orders o
JOIN order_items oi 
	ON oi.order_id = o.order_id
JOIN products p 
	ON oi.product_id = p.product_id
JOIN categories cat
	ON p.category_id = cat.category_id
JOIN stores s
	ON o.store_id = s.store_id
),
category_total_revenue AS (
SELECT store_name, 
	category_name, 
	SUM(revenue) AS total_revenue
FROM get_category_sales
GROUP BY store_name, category_name
),
rank_categories AS (
SELECT store_name, 
	ROW_NUMBER() OVER(PARTITION BY store_name ORDER BY total_revenue DESC) AS category_rank,
	category_name, 
    total_revenue
FROM category_total_revenue
)
SELECT *
FROM rank_categories
WHERE category_rank <= 5
ORDER BY store_name
;
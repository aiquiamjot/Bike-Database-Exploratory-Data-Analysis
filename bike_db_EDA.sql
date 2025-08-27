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



-- Which customers made the most orders?

WITH get_total_orders AS (
SELECT o.customer_id, 
	first_name, 
    last_name,
	COUNT(o.order_id) AS total_order
FROM orders o
JOIN customers c
	ON c.customer_id = o.customer_id
GROUP BY o.customer_id, first_name, last_name
)
SELECT customer_id, first_name, last_name, MAX(total_order) AS highest_total_order
FROM get_total_orders
WHERE total_order = (SELECT MAX(total_order) FROM get_total_orders)
GROUP BY customer_id, first_name, last_name
;



-- Which customers spent the most? List top 10.

WITH get_total_customer_cost AS (
SELECT o.customer_id, 
	product_id, 
	quantity * (list_price * (1 - discount)) AS cost,
    first_name, 
    last_name
FROM order_items oi
JOIN orders o
	ON oi.order_id = o.order_id
JOIN customers c
	ON o.customer_id = c.customer_id 
)
SELECT customer_id, first_name, last_name, SUM(cost) AS total_cost
FROM get_total_customer_cost
GROUP BY customer_id, first_name, last_name
ORDER BY SUM(cost) DESC LIMIT 10
;



-- What is the average order value (AOV) per customer?

WITH get_total_orders AS (
SELECT o.customer_id, 
	first_name,
    last_name,
	COUNT(o.order_id) AS total_order
FROM orders o
JOIN customers c
	ON c.customer_id = o.customer_id
GROUP BY o.customer_id, first_name, last_name
),
get_total_cost AS (
SELECT o.customer_id,
	SUM(quantity * (list_price * (1 - discount))) AS total_cost
FROM order_items oi
JOIN orders o
	ON oi.order_id = o.order_id
JOIN customers c
	ON o.customer_id = c.customer_id
GROUP BY o.customer_id
) 
SELECT gto.customer_id, 
	first_name, 
	last_name, 
	total_order,
    total_cost,
    ROUND(total_cost / total_order, 2) AS average_order_value
FROM get_total_orders gto
JOIN get_total_cost gtc
	ON gto.customer_id = gtc.customer_id
-- WHERE total_order = (SELECT MAX(total_order) FROM get_total_orders) # uncomment to get customers with highest total transactions
ORDER BY (total_cost / total_order) DESC
;



-- Which products have the highest revenue per unit sold (premium items)?

WITH get_product_revenue AS (
SELECT quantity, 
	oi.list_price, 
    discount, 
    oi.product_id, 
    product_name,
    quantity * (oi.list_price * (1 - discount)) AS revenue
FROM order_items oi
JOIN products p
	ON oi.product_id = p.product_id
),
get_revenue_per_unit AS (
SELECT product_id, 
	product_name,
	SUM(quantity) AS total_quantity,
    SUM(revenue) AS total_revenue
FROM get_product_revenue
GROUP BY product_id, product_name
)
SELECT product_name,
	ROUND((total_revenue / total_quantity), 2) AS revenue_per_unit
FROM get_revenue_per_unit 
ORDER BY (total_revenue / total_quantity) DESC
;



-- What is the average discount per category?

WITH get_category_discount AS (
SELECT 
	(quantity * oi.list_price * discount) AS discount_usd,
    category_name
FROM order_items oi
JOIN products p 
	ON oi.product_id = p.product_id
JOIN categories cat
	ON p.category_id = cat.category_id
)
SELECT category_name, 
    COUNT(*) AS total_sales,
	ROUND(MIN(discount_usd), 2) AS min_discount,
	ROUND(MAX(discount_usd), 2) AS max_discount,
	ROUND(AVG(discount_usd), 2) AS average_discount
FROM get_category_discount
GROUP BY category_name
ORDER BY average_discount DESC
;



-- Which product categories are most common in repeat orders?

WITH get_row_num_order AS (
SELECT 
	customer_id, 
	order_id,
	order_date,
	ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date) AS row_num_order
FROM orders
),
get_repeat_categories AS (
SELECT 
	grno.customer_id, 
	grno.order_id,
    order_date,
    category_name
FROM get_row_num_order grno
JOIN order_items oi
	ON grno.order_id = oi.order_id
JOIN products p
	ON oi.product_id = p.product_id
JOIN categories cat 
	ON p.category_id = cat.category_id
WHERE row_num_order > 1
)
SELECT 
	category_name,
	COUNT(*) AS total_repeat_sales
FROM get_repeat_categories
GROUP BY category_name
ORDER BY total_repeat_sales DESC
;



-- Which products are frequently bought together?

-- this code takes into account the product ids. 
-- theoretically, this should return the same values if product id and product name is 1:1
SELECT 
	oi1.product_id AS product_id1,
    p1.product_name AS product1,
    oi2.product_id AS product_id2,
    p2.product_name AS product2,
    COUNT(*) AS purchase_frequency
FROM order_items oi1
JOIN order_items oi2
	ON oi1.order_id = oi2.order_id
    AND oi1.product_id < oi2.product_id
JOIN products p1
	ON oi1.product_id = p1.product_id
JOIN products p2
	ON oi2.product_id = p2.product_id
GROUP BY oi1.product_id, p1.product_name, oi2.product_id, p2.product_name
ORDER BY purchase_frequency DESC
;


-- this query uses only the product names. apparently, some product names have multiple product ids.
-- we use this query instead to disregard the multiple product ID issue
SELECT 
    p1.product_name AS product1,
    p2.product_name AS product2,
    COUNT(*) AS purchase_frequency
FROM order_items oi1
JOIN order_items oi2
	ON oi1.order_id = oi2.order_id
    AND oi1.product_id < oi2.product_id
JOIN products p1
	ON oi1.product_id = p1.product_id
JOIN products p2
	ON oi2.product_id = p2.product_id
GROUP BY p1.product_name, p2.product_name
ORDER BY purchase_frequency DESC
;


-- checking if product_id maps to multiple product names
SELECT product_id, COUNT(DISTINCT product_name) AS name_count
FROM products
GROUP BY product_id
HAVING COUNT(DISTINCT product_name) > 1;


-- checking if product_name maps to multiple IDs
SELECT product_name, COUNT(DISTINCT product_id) AS id_count
FROM products
GROUP BY product_name
HAVING COUNT(DISTINCT product_id) > 1;
-- indeed, we have multiple IDs


-- this query returns that product names with multiple IDs, and all the IDs mapped to it.
SELECT product_name, GROUP_CONCAT(product_id ORDER BY product_id) AS product_ids
FROM products
GROUP BY product_name
HAVING COUNT(DISTINCT product_id) > 1;



-- Which products were not sold?

SELECT p.product_id,
	p.product_name,
	p.list_price
FROM products p 
LEFT JOIN order_items oi
	ON p.product_id = oi.product_id
WHERE order_id IS NULL
ORDER BY p.product_name
;


/*
=================================================================
======================== CUSTOMER REPORT ========================
=================================================================

Purpose: 
	- This report consolidates key customer metrics and behaviors
    
Highlights:
1. gather essential fields such as customer id, and customer name
2. segment customers into categories: VIP, regular, new
	VIP = customer life span is greater than 12 months, and spends more than 10000 USD
    Regular = customer life span is greater than 12 months, and spends less than 10000 USD
    New = customer life span is less than 12 months
3. aggregates customer-level metrics:
	- total orders
    - total revenue
    - total quantity purchased
    - total products
    - life span (in months)
    - total on-time deliveries
    - total late deliveries
    - total in-store purchases
4. calculate valuable KPIs:
	- recency (months since last order)
    - average order value
    - average monthly spend
=================================================================
*/

SELECT *
FROM orders o
JOIN customers c 
	ON o.customer_id = c.customer_id


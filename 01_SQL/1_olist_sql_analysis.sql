/* ==========================================================================
   PROJECT : E-Commerce Profitability and LTV Optimization Suite
   PART    : 01 - SQL extraction, analysis and cleaning
   DATASET : Olist Brazilian E-Commerce Public Dataset (Kaggle), 2016-2018,
             about 99k orders across 8 related tables
   TOOLS   : MySQL, MySQL Workbench
   AUTHOR  : Tajudeen Rabiu
   FOCUS   : Customer behaviour, retention and engagement
   ========================================================================== */


/* ==========================================================================
   SECTION 1 - SETUP AND DATA IMPORT
   Note: orders, olist_customers_dataset, order_items, order_payments, sellers
   and product_category were imported with the MySQL Workbench Table Import
   Wizard. products and order_reviews are loaded below with LOAD DATA, so that
   empty values become NULL instead of failing the import.
   ========================================================================== */

CREATE DATABASE olist;
USE olist;

/* allow importing data from local CSV files */
SET GLOBAL local_infile = 1;

/* products_full: product category, description and dimension details */
CREATE TABLE products_full (
  product_id VARCHAR(32), product_category_name VARCHAR(100),
  product_name_lenght INT, product_description_lenght INT, product_photos_qty INT,
  product_weight_g INT, product_length_cm INT, product_height_cm INT, product_width_cm INT);
  
  
/* to load product records from a CSV file into the products_full table and clean missing values. */
LOAD DATA LOCAL INFILE 'C:/Users/dell/Desktop/Portfolio/Olist/products.csv'
INTO TABLE products_full
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(product_id, @cat, @n, @d, @ph, @w, @l, @h, @wd)
SET product_category_name = NULLIF(@cat,''), product_name_lenght = NULLIF(@n,''),
    product_description_lenght = NULLIF(@d,''), product_photos_qty = NULLIF(@ph,''),
    product_weight_g = NULLIF(@w,''), product_length_cm = NULLIF(@l,''),
    product_height_cm = NULLIF(@h,''), product_width_cm = NULLIF(TRIM(TRAILING '\r' FROM @wd),'');

/* order_reviews_full: customer ratings, comments and review timestamps */
CREATE TABLE order_reviews_full (
  review_id VARCHAR(32), order_id VARCHAR(32), review_score INT,
  review_comment_title VARCHAR(255), review_comment_message TEXT,
  review_creation_date DATETIME, review_answer_timestamp DATETIME);
  
  
/* to import customer review data from a CSV file into the order_reviews_full table and clean missing timestamp values. */
LOAD DATA LOCAL INFILE 'C:/Users/dell/Desktop/Portfolio/Olist/order_reviews.csv'
INTO TABLE order_reviews_full
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(review_id, 
 order_id,
 review_score, 
 review_comment_title,
 review_comment_message, @c, @a)
SET review_creation_date = NULLIF(@c,''),
    review_answer_timestamp = NULLIF(TRIM(TRAILING '\r' FROM @a),'');

/* fix the product_category column name, which arrived with a hidden BOM character from the CSV.
   Already run once during setup; running it again gives an error because the column is already renamed. */
ALTER TABLE product_category
RENAME COLUMN `ï»¿product_category_name` TO product_category_name;

/* indexes on frequently joined columns to speed up the analysis queries */
CREATE INDEX idx_oi_order ON order_items (order_id(32));
CREATE INDEX idx_oi_seller ON order_items (seller_id(32));
CREATE INDEX idx_o_order ON orders (order_id(32));
CREATE INDEX idx_s_seller ON sellers (seller_id(32));

/* DQ01 - row count of every table, to validate the imports */
SELECT 'customers' t, COUNT(*) n FROM olist_customers_dataset
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'reviews', COUNT(*) FROM order_reviews_full
UNION ALL SELECT 'products', COUNT(*) FROM products_full
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'category_translation', COUNT(*) FROM product_category;


/* ==========================================================================
   SECTION 2 - BUSINESS QUESTIONS (Q01 - Q10)
   ========================================================================== */

/* Q01 - BEHAVIOUR: monthly delivered orders and revenue */
SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(p.payment_value), 2) AS revenue
FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY month
ORDER BY month;

/* Q02 - BEHAVIOUR: top 10 product categories by revenue and orders */
SELECT COALESCE(c.product_category_name_english, p.product_category_name) AS category,
       COUNT(DISTINCT oi.order_id) AS orders,
       ROUND(SUM(oi.price), 2) AS revenue
FROM order_items oi
JOIN products_full p ON oi.product_id = p.product_id
LEFT JOIN product_category c ON p.product_category_name = c.product_category_name
GROUP BY category
ORDER BY revenue DESC
LIMIT 10;

/* Q03 - BEHAVIOUR: payment methods by orders, value share and average installments */
SELECT payment_type,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(SUM(payment_value), 2) AS total_value,
       ROUND(100 * SUM(payment_value) / (SELECT SUM(payment_value) FROM order_payments), 1) AS pct_of_value,
       ROUND(AVG(payment_installments), 1) AS avg_installments
FROM order_payments
GROUP BY payment_type
ORDER BY total_value DESC;

/* Q04 - ENGAGEMENT: top 10 customer states by share of late deliveries */
SELECT c.customer_state AS state,
       COUNT(*) AS delivered_orders,
       SUM(o.order_delivered_customer_date > o.order_estimated_delivery_date) AS late_orders,
       ROUND(100 * AVG(o.order_delivered_customer_date > o.order_estimated_delivery_date), 1) AS pct_late
FROM orders o
JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date <> ''
GROUP BY state
ORDER BY pct_late DESC
LIMIT 10;

/* Q05 - top 5 seller states by number of sellers */
SELECT 
	seller_state, COUNT(*) AS sellers 
FROM sellers 
GROUP BY seller_state 
ORDER BY 2 DESC LIMIT 5;

/* Q06 - ENGAGEMENT: review scores for on-time vs late deliveries */
SELECT CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'Late' ELSE 'On time' END AS delivery,
       COUNT(*) AS reviews,
       ROUND(AVG(r.review_score), 2) AS avg_score,
       ROUND(100 * AVG(r.review_score <= 2), 1) AS pct_bad_reviews
FROM orders o
JOIN order_reviews_full r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date <> ''
GROUP BY delivery;

/* Q07 - RETENTION: how many customers buy once, twice or more */
SELECT orders_per_customer,
       COUNT(*) AS customers,
       ROUND(100 * COUNT(*) / (SELECT COUNT(DISTINCT customer_unique_id) FROM olist_customers_dataset), 2) AS pct
FROM (
  SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS orders_per_customer
  FROM orders o
  JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
  GROUP BY c.customer_unique_id
) t
GROUP BY orders_per_customer
ORDER BY orders_per_customer;

/* Q08 - categories where shipping costs the most relative to price (min 500 items) */
SELECT COALESCE(c.product_category_name_english, p.product_category_name) AS category,
       COUNT(*) AS items,
       ROUND(SUM(oi.price), 2) AS revenue,
       ROUND(SUM(oi.freight_value), 2) AS freight,
       ROUND(100 * SUM(oi.freight_value) / SUM(oi.price), 1) AS freight_pct_of_price
FROM order_items oi
JOIN products_full p ON oi.product_id = p.product_id
LEFT JOIN product_category c ON p.product_category_name = c.product_category_name
GROUP BY category
HAVING items >= 500
ORDER BY freight_pct_of_price DESC
LIMIT 10;

/* Q09 - top 10 sellers by revenue, with their state and late-delivery rate */
SELECT oi.seller_id,
       s.seller_state,
       COUNT(DISTINCT oi.order_id) AS orders,
       ROUND(SUM(oi.price), 2) AS revenue,
       ROUND(100 * AVG(o.order_delivered_customer_date > o.order_estimated_delivery_date), 1) AS pct_late
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN sellers s ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date <> ''
GROUP BY oi.seller_id, s.seller_state
ORDER BY revenue DESC
LIMIT 10;

/* Q10 - order status summary: number of orders and payment value per status */
SELECT o.order_status,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(p.payment_value), 2) AS value
FROM orders o
JOIN order_payments p ON o.order_id = p.order_id
GROUP BY o.order_status
ORDER BY orders DESC;

/* Q11 - BEHAVIOUR: do customers who use more credit installments place bigger orders */
SELECT CASE WHEN payment_installments <= 1 THEN '1 (paid in full)'
            WHEN payment_installments <= 3 THEN '2-3'
            WHEN payment_installments <= 6 THEN '4-6'
            ELSE '7+' END AS installments,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(AVG(payment_value), 2) AS avg_payment
FROM order_payments
WHERE payment_type = 'credit_card'
GROUP BY installments
ORDER BY MIN(payment_installments);


/* ==========================================================================
   SECTION 3 - BUILD THE CLEAN ANALYTICS TABLE (orders_clean)
   One row per order. This single table feeds Python, Power BI and Excel,
   so every tool reports the same numbers.
   ========================================================================== */

/* relax strict mode so empty date strings do not stop the build */
SET SESSION sql_mode = '';

/* combine orders, customers, items, payments and reviews into one table */
CREATE TABLE orders_clean AS
SELECT o.order_id,
       c.customer_unique_id,
       c.customer_state,
       o.order_status,
       DATE(o.order_purchase_timestamp) AS purchase_date,
       DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS purchase_month,
       DATE(NULLIF(o.order_delivered_customer_date, '')) AS delivered_date,
       DATE(o.order_estimated_delivery_date) AS estimated_date,
       DATEDIFF(NULLIF(o.order_delivered_customer_date, ''), o.order_purchase_timestamp) AS delivery_days,
       CASE WHEN NULLIF(o.order_delivered_customer_date, '') IS NULL THEN NULL
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END AS is_late,
       i.items, i.product_revenue, i.freight,
       p.payment_total, p.payment_type, p.installments,
       r.review_score
FROM orders o
JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
LEFT JOIN (SELECT order_id, COUNT(*) AS items, SUM(price) AS product_revenue, SUM(freight_value) AS freight
           FROM order_items GROUP BY order_id) i ON o.order_id = i.order_id
LEFT JOIN (SELECT order_id, SUM(payment_value) AS payment_total, MAX(payment_type) AS payment_type,
                  MAX(payment_installments) AS installments
           FROM order_payments GROUP BY order_id) p ON o.order_id = p.order_id
LEFT JOIN (SELECT order_id, AVG(review_score) AS review_score
           FROM order_reviews_full GROUP BY order_id) r ON o.order_id = r.order_id;

/* fill delivered_date, delivery_days and is_late from the source orders table, because the NULLIF step above left them empty. Safe-update mode is switched off so the UPDATE can run */
SET SQL_SAFE_UPDATES = 0;

UPDATE orders_clean oc
JOIN orders o ON oc.order_id = o.order_id
SET oc.delivered_date = DATE(o.order_delivered_customer_date),
    oc.delivery_days = DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp),
    oc.is_late = (o.order_delivered_customer_date > o.order_estimated_delivery_date)
WHERE o.order_delivered_customer_date > '2000-01-01';


/* ==========================================================================
   SECTION 4 - DATA QUALITY CHECKS
   ========================================================================== */

/* DQ02 - delivery dates after the fix (expected: only 8 delivered orders without a date) */
SELECT
  COUNT(*) AS total_rows,
  SUM(delivered_date IS NULL) AS no_delivered_date,
  SUM(delivery_days IS NULL) AS no_days,
  SUM(order_status = 'delivered' AND delivered_date IS NULL) AS delivered_but_no_date
FROM orders_clean;

/* DQ03 - duplicates and missing values (unique orders, customer, payment, items, review, delivery range) */
SELECT
  COUNT(*) AS total_rows,
  COUNT(DISTINCT order_id) AS unique_orders,
  SUM(customer_unique_id IS NULL) AS no_customer,
  SUM(payment_total IS NULL) AS no_payment,
  SUM(product_revenue IS NULL) AS no_items,
  SUM(review_score IS NULL) AS no_review,
  MIN(delivery_days) AS min_days,
  MAX(delivery_days) AS max_days
FROM orders_clean;

/* DQ04 - status of the orders with no items (mostly unavailable or cancelled) */
SELECT order_status, COUNT(*) AS orders
FROM orders_clean
WHERE product_revenue IS NULL
GROUP BY order_status
ORDER BY orders DESC;


/* ==========================================================================
   SECTION 5 - HEADLINE KPIs (delivered orders)
   Used for the README and to cross-check the Power BI cards.
   ========================================================================== */

SELECT
  COUNT(*) AS total_orders,
  COUNT(DISTINCT customer_unique_id) AS customers,
  ROUND(SUM(payment_total), 2) AS gmv,
  ROUND(AVG(payment_total), 2) AS aov,
  ROUND(COUNT(*) / COUNT(DISTINCT customer_unique_id), 3) AS orders_per_customer,
  ROUND(AVG(review_score), 2) AS avg_review,
  ROUND(100 * AVG(is_late), 1) AS late_pct,
  ROUND(AVG(delivery_days), 1) AS avg_delivery_days
FROM orders_clean
WHERE order_status = 'delivered';

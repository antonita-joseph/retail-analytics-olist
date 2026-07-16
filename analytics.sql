-- ============================================================
-- Project: Advanced SQL Retail Analytics
-- Dataset: Brazilian E-Commerce Public Dataset by Olist
-- Database: PostgreSQL
-- File: analysis.sql
-- Purpose: Perform retail, customer, product, seller, payment,
--          review, and delivery analysis
-- ============================================================


-- ============================================================
-- IMPORTANT DATA-MODEL NOTES
-- ============================================================
-- 1. customer_id identifies the customer record associated with
--    a specific order.
--
-- 2. customer_unique_id should be used to identify the same
--    customer across multiple orders.
--
-- 3. An order can contain multiple order items.
--
-- 4. An order can contain multiple payment records.
--
-- 5. Joining order_items and order_payments directly can multiply
--    rows and overstate revenue. Aggregate each table separately
--    before combining them.
--
-- 6. Revenue calculations in this file generally use:
--       price + freight_value
--    from order_items.
--
-- 7. Unless otherwise specified, commercial analyses use only
--    delivered orders.


-- ============================================================
-- SECTION 1: BASIC DATA EXPLORATION
-- ============================================================


-- 1.1 Count the number of rows in each table

SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM customers

UNION ALL

SELECT 'orders', COUNT(*)
FROM orders

UNION ALL

SELECT 'order_items', COUNT(*)
FROM order_items

UNION ALL

SELECT 'order_payments', COUNT(*)
FROM order_payments

UNION ALL

SELECT 'order_reviews', COUNT(*)
FROM order_reviews

UNION ALL

SELECT 'products', COUNT(*)
FROM products

UNION ALL

SELECT 'sellers', COUNT(*)
FROM sellers

UNION ALL

SELECT 'product_category_name_translation', COUNT(*)
FROM product_category_name_translation

UNION ALL

SELECT 'geolocation', COUNT(*)
FROM geolocation

ORDER BY table_name;


-- 1.2 Display sample customer records

SELECT *
FROM customers
LIMIT 10;


-- 1.3 Display sample order records

SELECT *
FROM orders
ORDER BY order_purchase_timestamp
LIMIT 10;


-- 1.4 Determine the available order date range

SELECT
    MIN(order_purchase_timestamp) AS earliest_order_date,
    MAX(order_purchase_timestamp) AS latest_order_date
FROM orders;


-- 1.5 Count distinct business entities

SELECT
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT oi.product_id) AS products_sold,
    COUNT(DISTINCT oi.seller_id) AS active_sellers
FROM orders AS o
JOIN customers AS c
    ON o.customer_id = c.customer_id
LEFT JOIN order_items AS oi
    ON o.order_id = oi.order_id;


-- ============================================================
-- SECTION 2: DATA-QUALITY VALIDATION
-- ============================================================


-- 2.1 Check duplicate primary identifiers in customers

SELECT
    customer_id,
    COUNT(*) AS duplicate_count
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;


-- 2.2 Check duplicate order identifiers

SELECT
    order_id,
    COUNT(*) AS duplicate_count
FROM orders
GROUP BY order_id
HAVING COUNT(*) > 1;


-- 2.3 Check duplicate order-item composite keys

SELECT
    order_id,
    order_item_id,
    COUNT(*) AS duplicate_count
FROM order_items
GROUP BY
    order_id,
    order_item_id
HAVING COUNT(*) > 1;


-- 2.4 Check duplicate payment composite keys

SELECT
    order_id,
    payment_sequential,
    COUNT(*) AS duplicate_count
FROM order_payments
GROUP BY
    order_id,
    payment_sequential
HAVING COUNT(*) > 1;


-- 2.5 Check for orders without corresponding customers

SELECT
    o.order_id,
    o.customer_id
FROM orders AS o
LEFT JOIN customers AS c
    ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;


-- 2.6 Check for order items without corresponding orders

SELECT
    oi.order_id,
    oi.order_item_id
FROM order_items AS oi
LEFT JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;


-- 2.7 Check for order items without corresponding products

SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id
FROM order_items AS oi
LEFT JOIN products AS p
    ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;


-- 2.8 Check for order items without corresponding sellers

SELECT
    oi.order_id,
    oi.order_item_id,
    oi.seller_id
FROM order_items AS oi
LEFT JOIN sellers AS s
    ON oi.seller_id = s.seller_id
WHERE s.seller_id IS NULL;


-- 2.9 Check for negative monetary values

SELECT
    order_id,
    order_item_id,
    price,
    freight_value
FROM order_items
WHERE price < 0
   OR freight_value < 0;


-- 2.10 Check for invalid review scores

SELECT
    review_id,
    order_id,
    review_score
FROM order_reviews
WHERE review_score NOT BETWEEN 1 AND 5;


-- 2.11 Count null values in important order timestamps

SELECT
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (
        WHERE order_purchase_timestamp IS NULL
    ) AS missing_purchase_timestamp,
    COUNT(*) FILTER (
        WHERE order_approved_at IS NULL
    ) AS missing_approval_timestamp,
    COUNT(*) FILTER (
        WHERE order_delivered_customer_date IS NULL
    ) AS missing_customer_delivery_timestamp,
    COUNT(*) FILTER (
        WHERE order_estimated_delivery_date IS NULL
    ) AS missing_estimated_delivery_timestamp
FROM orders;


-- ============================================================
-- SECTION 3: BASIC JOINS
-- ============================================================


-- 3.1 Orders with customer location

SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp
FROM orders AS o
JOIN customers AS c
    ON o.customer_id = c.customer_id
ORDER BY o.order_purchase_timestamp DESC;


-- 3.2 Order items with products and sellers

SELECT
    oi.order_id,
    oi.order_item_id,
    oi.product_id,
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    oi.seller_id,
    s.seller_city,
    s.seller_state,
    oi.price,
    oi.freight_value
FROM order_items AS oi
JOIN products AS p
    ON oi.product_id = p.product_id
JOIN sellers AS s
    ON oi.seller_id = s.seller_id
LEFT JOIN product_category_name_translation AS pct
    ON p.product_category_name = pct.product_category_name
ORDER BY
    oi.order_id,
    oi.order_item_id;


-- 3.3 Complete order-item transaction view

SELECT
    o.order_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    oi.order_item_id,
    oi.product_id,
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    oi.seller_id,
    s.seller_city,
    s.seller_state,
    oi.price,
    oi.freight_value,
    oi.price + oi.freight_value AS item_total_value
FROM orders AS o
JOIN customers AS c
    ON o.customer_id = c.customer_id
JOIN order_items AS oi
    ON o.order_id = oi.order_id
JOIN products AS p
    ON oi.product_id = p.product_id
JOIN sellers AS s
    ON oi.seller_id = s.seller_id
LEFT JOIN product_category_name_translation AS pct
    ON p.product_category_name = pct.product_category_name
ORDER BY
    o.order_purchase_timestamp,
    o.order_id,
    oi.order_item_id;


-- ============================================================
-- SECTION 4: ORDER AND REVENUE KPIs
-- ============================================================


-- 4.1 Total number of orders

SELECT
    COUNT(*) AS total_orders
FROM orders;


-- 4.2 Delivered orders

SELECT
    COUNT(*) AS delivered_orders
FROM orders
WHERE order_status = 'delivered';


-- 4.3 Order counts by status

SELECT
    order_status,
    COUNT(*) AS order_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_orders
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;


-- 4.4 Total delivered product revenue

SELECT
    ROUND(SUM(oi.price), 2) AS product_revenue
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';


-- 4.5 Total delivered freight revenue

SELECT
    ROUND(SUM(oi.freight_value), 2) AS freight_revenue
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';


-- 4.6 Total delivered order-item value

SELECT
    ROUND(
        SUM(oi.price + oi.freight_value),
        2
    ) AS total_order_value
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered';


-- 4.7 Order-level financial totals

WITH order_financials AS (
    SELECT
        oi.order_id,
        SUM(oi.price) AS product_value,
        SUM(oi.freight_value) AS freight_value,
        SUM(oi.price + oi.freight_value) AS total_order_value,
        COUNT(*) AS item_count
    FROM order_items AS oi
    GROUP BY oi.order_id
)

SELECT
    o.order_id,
    o.order_purchase_timestamp,
    ofn.item_count,
    ROUND(ofn.product_value, 2) AS product_value,
    ROUND(ofn.freight_value, 2) AS freight_value,
    ROUND(ofn.total_order_value, 2) AS total_order_value
FROM orders AS o
JOIN order_financials AS ofn
    ON o.order_id = ofn.order_id
WHERE o.order_status = 'delivered'
ORDER BY total_order_value DESC;


-- 4.8 Average order value

WITH order_financials AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM order_items AS oi
    GROUP BY oi.order_id
)

SELECT
    ROUND(AVG(ofn.order_value), 2) AS average_order_value
FROM order_financials AS ofn
JOIN orders AS o
    ON ofn.order_id = o.order_id
WHERE o.order_status = 'delivered';


-- 4.9 Average number of items per order

WITH order_item_counts AS (
    SELECT
        order_id,
        COUNT(*) AS item_count
    FROM order_items
    GROUP BY order_id
)

SELECT
    ROUND(AVG(item_count), 2) AS average_items_per_order
FROM order_item_counts;


-- 4.10 Minimum, maximum, and average delivered order value

WITH order_financials AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM order_items AS oi
    GROUP BY oi.order_id
)

SELECT
    ROUND(MIN(ofn.order_value), 2) AS minimum_order_value,
    ROUND(AVG(ofn.order_value), 2) AS average_order_value,
    ROUND(MAX(ofn.order_value), 2) AS maximum_order_value
FROM order_financials AS ofn
JOIN orders AS o
    ON ofn.order_id = o.order_id
WHERE o.order_status = 'delivered';


-- ============================================================
-- SECTION 5: TIME-BASED SALES ANALYSIS
-- ============================================================


-- 5.1 Orders by year

SELECT
    EXTRACT(YEAR FROM order_purchase_timestamp)::INTEGER AS order_year,
    COUNT(*) AS order_count
FROM orders
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY order_year
ORDER BY order_year;


-- 5.2 Orders by month

SELECT
    DATE_TRUNC(
        'month',
        order_purchase_timestamp
    )::DATE AS order_month,
    COUNT(*) AS order_count
FROM orders
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY order_month
ORDER BY order_month;


-- 5.3 Monthly delivered revenue

WITH monthly_sales AS (
    SELECT
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )::DATE AS order_month,
        COUNT(DISTINCT o.order_id) AS delivered_orders,
        SUM(oi.price) AS product_revenue,
        SUM(oi.freight_value) AS freight_revenue,
        SUM(oi.price + oi.freight_value) AS total_revenue
    FROM orders AS o
    JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY order_month
)

SELECT
    order_month,
    delivered_orders,
    ROUND(product_revenue, 2) AS product_revenue,
    ROUND(freight_revenue, 2) AS freight_revenue,
    ROUND(total_revenue, 2) AS total_revenue
FROM monthly_sales
ORDER BY order_month;


-- 5.4 Monthly average order value

WITH order_financials AS (
    SELECT
        o.order_id,
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )::DATE AS order_month,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM orders AS o
    JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        o.order_id,
        order_month
)

SELECT
    order_month,
    COUNT(*) AS order_count,
    ROUND(AVG(order_value), 2) AS average_order_value
FROM order_financials
GROUP BY order_month
ORDER BY order_month;


-- 5.5 Orders by day of week

SELECT
    EXTRACT(
        ISODOW FROM order_purchase_timestamp
    )::INTEGER AS day_number,
    TO_CHAR(
        order_purchase_timestamp,
        'FMDay'
    ) AS day_name,
    COUNT(*) AS order_count
FROM orders
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY
    day_number,
    day_name
ORDER BY day_number;


-- 5.6 Orders by hour of day

SELECT
    EXTRACT(
        HOUR FROM order_purchase_timestamp
    )::INTEGER AS purchase_hour,
    COUNT(*) AS order_count
FROM orders
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY purchase_hour
ORDER BY purchase_hour;


-- 5.7 Monthly revenue growth using LAG

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )::DATE AS order_month,
        SUM(oi.price + oi.freight_value) AS revenue
    FROM orders AS o
    JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY order_month
),

revenue_comparison AS (
    SELECT
        order_month,
        revenue,
        LAG(revenue) OVER (
            ORDER BY order_month
        ) AS previous_month_revenue
    FROM monthly_revenue
)

SELECT
    order_month,
    ROUND(revenue, 2) AS current_month_revenue,
    ROUND(previous_month_revenue, 2) AS previous_month_revenue,
    ROUND(
        revenue - previous_month_revenue,
        2
    ) AS absolute_growth,
    ROUND(
        100.0
        * (revenue - previous_month_revenue)
        / NULLIF(previous_month_revenue, 0),
        2
    ) AS growth_percentage
FROM revenue_comparison
ORDER BY order_month;


-- 5.8 Cumulative revenue

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )::DATE AS order_month,
        SUM(oi.price + oi.freight_value) AS revenue
    FROM orders AS o
    JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY order_month
)

SELECT
    order_month,
    ROUND(revenue, 2) AS monthly_revenue,
    ROUND(
        SUM(revenue) OVER (
            ORDER BY order_month
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ),
        2
    ) AS cumulative_revenue
FROM monthly_revenue
ORDER BY order_month;


-- ============================================================
-- SECTION 6: CUSTOMER ANALYSIS
-- ============================================================


-- 6.1 Number of unique customers

SELECT
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;


-- 6.2 Customers by state

SELECT
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers
GROUP BY customer_state
ORDER BY unique_customers DESC;


-- 6.3 Top customer cities

SELECT
    customer_city,
    customer_state,
    COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers
GROUP BY
    customer_city,
    customer_state
ORDER BY unique_customers DESC
LIMIT 20;


-- 6.4 Number of orders per unique customer

SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS order_count
FROM customers AS c
JOIN orders AS o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id
ORDER BY order_count DESC;


-- 6.5 One-time and repeat customers

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers AS c
    JOIN orders AS o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)

SELECT
    CASE
        WHEN order_count = 1 THEN 'One-time customer'
        ELSE 'Repeat customer'
    END AS customer_type,
    COUNT(*) AS customer_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_percentage
FROM customer_orders
GROUP BY customer_type
ORDER BY customer_count DESC;


-- 6.6 Repeat-purchase rate

WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count
    FROM customers AS c
    JOIN orders AS o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    COUNT(*) AS customers_with_delivered_orders,
    COUNT(*) FILTER (
        WHERE order_count > 1
    ) AS repeat_customers,
    ROUND(
        100.0
        * COUNT(*) FILTER (WHERE order_count > 1)
        / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_purchase_rate
FROM customer_orders;


-- 6.7 Customer-level lifetime value

WITH order_financials AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM order_items AS oi
    GROUP BY oi.order_id
)

SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(SUM(ofn.order_value), 2) AS customer_lifetime_value,
    ROUND(AVG(ofn.order_value), 2) AS average_order_value,
    MIN(o.order_purchase_timestamp) AS first_purchase_date,
    MAX(o.order_purchase_timestamp) AS latest_purchase_date
FROM customers AS c
JOIN orders AS o
    ON c.customer_id = o.customer_id
JOIN order_financials AS ofn
    ON o.order_id = ofn.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
ORDER BY customer_lifetime_value DESC;


-- 6.8 Top 20 customers by lifetime value

WITH order_financials AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM order_items AS oi
    GROUP BY oi.order_id
),

customer_value AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        SUM(ofn.order_value) AS lifetime_value
    FROM customers AS c
    JOIN orders AS o
        ON c.customer_id = o.customer_id
    JOIN order_financials AS ofn
        ON o.order_id = ofn.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    customer_unique_id,
    order_count,
    ROUND(lifetime_value, 2) AS lifetime_value,
    DENSE_RANK() OVER (
        ORDER BY lifetime_value DESC
    ) AS value_rank
FROM customer_value
ORDER BY value_rank
LIMIT 20;


-- 6.9 Time between first and latest customer purchases

WITH customer_purchase_dates AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS order_count,
        MIN(o.order_purchase_timestamp) AS first_purchase,
        MAX(o.order_purchase_timestamp) AS latest_purchase
    FROM customers AS c
    JOIN orders AS o
        ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)

SELECT
    customer_unique_id,
    order_count,
    first_purchase,
    latest_purchase,
    latest_purchase::DATE - first_purchase::DATE
        AS customer_relationship_days
FROM customer_purchase_dates
WHERE order_count > 1
ORDER BY customer_relationship_days DESC;


-- 6.10 Customer purchase sequence using ROW_NUMBER

SELECT
    c.customer_unique_id,
    o.order_id,
    o.order_purchase_timestamp,
    ROW_NUMBER() OVER (
        PARTITION BY c.customer_unique_id
        ORDER BY
            o.order_purchase_timestamp,
            o.order_id
    ) AS purchase_sequence
FROM customers AS c
JOIN orders AS o
    ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
ORDER BY
    c.customer_unique_id,
    purchase_sequence;


-- ============================================================
-- SECTION 7: RFM CUSTOMER SEGMENTATION
-- ============================================================
-- R = Recency
-- F = Frequency
-- M = Monetary value
--
-- Recency is calculated relative to the latest purchase date in
-- the dataset rather than the current system date.


WITH dataset_reference AS (
    SELECT
        MAX(order_purchase_timestamp)::DATE AS reference_date
    FROM orders
),

order_financials AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM order_items AS oi
    GROUP BY oi.order_id
),

customer_metrics AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp)::DATE
            AS latest_purchase_date,
        COUNT(DISTINCT o.order_id)
            AS frequency,
        SUM(ofn.order_value)
            AS monetary_value
    FROM customers AS c
    JOIN orders AS o
        ON c.customer_id = o.customer_id
    JOIN order_financials AS ofn
        ON o.order_id = ofn.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

rfm_values AS (
    SELECT
        cm.customer_unique_id,
        dr.reference_date - cm.latest_purchase_date
            AS recency_days,
        cm.frequency,
        cm.monetary_value
    FROM customer_metrics AS cm
    CROSS JOIN dataset_reference AS dr
),

rfm_scores AS (
    SELECT
        customer_unique_id,
        recency_days,
        frequency,
        monetary_value,

        6 - NTILE(5) OVER (
            ORDER BY recency_days
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY frequency
        ) AS frequency_score,

        NTILE(5) OVER (
            ORDER BY monetary_value
        ) AS monetary_score
    FROM rfm_values
)

SELECT
    customer_unique_id,
    recency_days,
    frequency,
    ROUND(monetary_value, 2) AS monetary_value,
    recency_score,
    frequency_score,
    monetary_score,
    CONCAT(
        recency_score,
        frequency_score,
        monetary_score
    ) AS rfm_score,
    CASE
        WHEN recency_score >= 4
         AND frequency_score >= 4
         AND monetary_score >= 4
            THEN 'Champions'

        WHEN recency_score >= 3
         AND frequency_score >= 3
         AND monetary_score >= 3
            THEN 'Loyal customers'

        WHEN recency_score >= 4
         AND frequency_score <= 2
            THEN 'Recent customers'

        WHEN recency_score <= 2
         AND frequency_score >= 3
            THEN 'At risk'

        WHEN recency_score = 1
         AND frequency_score = 1
            THEN 'Lost customers'

        ELSE 'Potential customers'
    END AS customer_segment
FROM rfm_scores
ORDER BY
    recency_score DESC,
    frequency_score DESC,
    monetary_score DESC;


-- ============================================================
-- SECTION 8: PRODUCT AND CATEGORY ANALYSIS
-- ============================================================


-- 8.1 Number of products by category

SELECT
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    COUNT(DISTINCT p.product_id) AS product_count
FROM products AS p
LEFT JOIN product_category_name_translation AS pct
    ON p.product_category_name = pct.product_category_name
GROUP BY product_category
ORDER BY product_count DESC;


-- 8.2 Top categories by quantity sold

SELECT
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    COUNT(*) AS items_sold
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation AS pct
    ON p.product_category_name = pct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY product_category
ORDER BY items_sold DESC
LIMIT 20;


-- 8.3 Top categories by revenue

SELECT
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS freight_revenue,
    ROUND(
        SUM(oi.price + oi.freight_value),
        2
    ) AS total_revenue
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation AS pct
    ON p.product_category_name = pct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY product_category
ORDER BY total_revenue DESC
LIMIT 20;


-- 8.4 Top products by quantity sold

SELECT
    oi.product_id,
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    COUNT(*) AS units_sold
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation AS pct
    ON p.product_category_name = pct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    oi.product_id,
    product_category
ORDER BY units_sold DESC
LIMIT 20;


-- 8.5 Top products by revenue

SELECT
    oi.product_id,
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    COUNT(*) AS units_sold,
    ROUND(SUM(oi.price), 2) AS product_revenue
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation AS pct
    ON p.product_category_name = pct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY
    oi.product_id,
    product_category
ORDER BY product_revenue DESC
LIMIT 20;


-- 8.6 Average product price by category

SELECT
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    COUNT(*) AS sold_items,
    ROUND(AVG(oi.price), 2) AS average_selling_price
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation AS pct
    ON p.product_category_name = pct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY product_category
HAVING COUNT(*) >= 10
ORDER BY average_selling_price DESC;


-- 8.7 Freight as a percentage of product value by category

SELECT
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    ROUND(SUM(oi.price), 2) AS product_value,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(
        100.0
        * SUM(oi.freight_value)
        / NULLIF(SUM(oi.price), 0),
        2
    ) AS freight_percentage
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation AS pct
    ON p.product_category_name = pct.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY product_category
HAVING SUM(oi.price) > 0
ORDER BY freight_percentage DESC;


-- 8.8 Category revenue ranking

WITH category_revenue AS (
    SELECT
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS product_category,
        SUM(oi.price + oi.freight_value) AS revenue
    FROM order_items AS oi
    JOIN orders AS o
        ON oi.order_id = o.order_id
    JOIN products AS p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation AS pct
        ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY product_category
)

SELECT
    product_category,
    ROUND(revenue, 2) AS revenue,
    DENSE_RANK() OVER (
        ORDER BY revenue DESC
    ) AS revenue_rank,
    ROUND(
        100.0 * revenue / SUM(revenue) OVER (),
        2
    ) AS revenue_share_percentage
FROM category_revenue
ORDER BY revenue_rank;


-- 8.9 Top three products within each category

WITH product_sales AS (
    SELECT
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS product_category,
        oi.product_id,
        COUNT(*) AS units_sold,
        SUM(oi.price) AS product_revenue
    FROM order_items AS oi
    JOIN orders AS o
        ON oi.order_id = o.order_id
    JOIN products AS p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation AS pct
        ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY
        product_category,
        oi.product_id
),

ranked_products AS (
    SELECT
        product_category,
        product_id,
        units_sold,
        product_revenue,
        DENSE_RANK() OVER (
            PARTITION BY product_category
            ORDER BY product_revenue DESC
        ) AS product_rank
    FROM product_sales
)

SELECT
    product_category,
    product_id,
    units_sold,
    ROUND(product_revenue, 2) AS product_revenue,
    product_rank
FROM ranked_products
WHERE product_rank <= 3
ORDER BY
    product_category,
    product_rank;


-- ============================================================
-- SECTION 9: SELLER ANALYSIS
-- ============================================================


-- 9.1 Sellers by state

SELECT
    seller_state,
    COUNT(DISTINCT seller_id) AS seller_count
FROM sellers
GROUP BY seller_state
ORDER BY seller_count DESC;


-- 9.2 Top sellers by delivered revenue

SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(DISTINCT oi.order_id) AS order_count,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS product_revenue,
    ROUND(SUM(oi.freight_value), 2) AS freight_value,
    ROUND(
        SUM(oi.price + oi.freight_value),
        2
    ) AS total_revenue
FROM sellers AS s
JOIN order_items AS oi
    ON s.seller_id = oi.seller_id
JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    s.seller_id,
    s.seller_city,
    s.seller_state
ORDER BY total_revenue DESC
LIMIT 20;


-- 9.3 Seller average order-item value

SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    COUNT(*) AS items_sold,
    ROUND(AVG(oi.price), 2) AS average_item_price
FROM sellers AS s
JOIN order_items AS oi
    ON s.seller_id = oi.seller_id
JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    s.seller_id,
    s.seller_city,
    s.seller_state
HAVING COUNT(*) >= 10
ORDER BY average_item_price DESC;


-- 9.4 Seller share of total product revenue

WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        SUM(oi.price) AS revenue
    FROM order_items AS oi
    JOIN orders AS o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
)

SELECT
    seller_id,
    ROUND(revenue, 2) AS revenue,
    ROUND(
        100.0 * revenue / SUM(revenue) OVER (),
        2
    ) AS revenue_share_percentage,
    DENSE_RANK() OVER (
        ORDER BY revenue DESC
    ) AS seller_rank
FROM seller_revenue
ORDER BY seller_rank;


-- 9.5 Seller performance by delivery lateness

SELECT
    oi.seller_id,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    COUNT(DISTINCT o.order_id) FILTER (
        WHERE o.order_delivered_customer_date
              > o.order_estimated_delivery_date
    ) AS late_orders,
    ROUND(
        100.0
        * COUNT(DISTINCT o.order_id) FILTER (
            WHERE o.order_delivered_customer_date
                  > o.order_estimated_delivery_date
        )
        / NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS late_delivery_rate
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY oi.seller_id
HAVING COUNT(DISTINCT o.order_id) >= 10
ORDER BY late_delivery_rate DESC;


-- ============================================================
-- SECTION 10: PAYMENT ANALYSIS
-- ============================================================


-- 10.1 Payment records by payment type

SELECT
    payment_type,
    COUNT(*) AS payment_record_count,
    ROUND(SUM(payment_value), 2) AS payment_value
FROM order_payments
GROUP BY payment_type
ORDER BY payment_value DESC;


-- 10.2 Payment-type share

SELECT
    payment_type,
    COUNT(*) AS payment_record_count,
    ROUND(SUM(payment_value), 2) AS payment_value,
    ROUND(
        100.0
        * SUM(payment_value)
        / SUM(SUM(payment_value)) OVER (),
        2
    ) AS payment_value_percentage
FROM order_payments
GROUP BY payment_type
ORDER BY payment_value DESC;


-- 10.3 Average payment value by type

SELECT
    payment_type,
    COUNT(*) AS payment_count,
    ROUND(AVG(payment_value), 2) AS average_payment_value
FROM order_payments
GROUP BY payment_type
ORDER BY average_payment_value DESC;


-- 10.4 Credit-card installment distribution

SELECT
    payment_installments,
    COUNT(*) AS payment_count,
    ROUND(AVG(payment_value), 2) AS average_payment_value,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM order_payments
WHERE payment_type = 'credit_card'
GROUP BY payment_installments
ORDER BY payment_installments;


-- 10.5 Orders using multiple payment records

SELECT
    order_id,
    COUNT(*) AS payment_record_count,
    COUNT(DISTINCT payment_type) AS payment_type_count,
    ROUND(SUM(payment_value), 2) AS total_payment_value
FROM order_payments
GROUP BY order_id
HAVING COUNT(*) > 1
ORDER BY payment_record_count DESC;


-- 10.6 Compare order-item totals with payment totals

WITH item_totals AS (
    SELECT
        order_id,
        SUM(price + freight_value) AS item_total
    FROM order_items
    GROUP BY order_id
),

payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM order_payments
    GROUP BY order_id
)

SELECT
    it.order_id,
    ROUND(it.item_total, 2) AS item_total,
    ROUND(pt.payment_total, 2) AS payment_total,
    ROUND(
        pt.payment_total - it.item_total,
        2
    ) AS difference
FROM item_totals AS it
JOIN payment_totals AS pt
    ON it.order_id = pt.order_id
WHERE ABS(pt.payment_total - it.item_total) > 0.01
ORDER BY ABS(pt.payment_total - it.item_total) DESC;


-- ============================================================
-- SECTION 11: DELIVERY ANALYSIS
-- ============================================================


-- 11.1 Average approval time in hours

SELECT
    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_approved_at
                    - order_purchase_timestamp
                )
            ) / 3600.0
        )::NUMERIC,
        2
    ) AS average_approval_hours
FROM orders
WHERE order_purchase_timestamp IS NOT NULL
  AND order_approved_at IS NOT NULL;


-- 11.2 Average carrier handover time in days

SELECT
    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_carrier_date
                    - order_approved_at
                )
            ) / 86400.0
        )::NUMERIC,
        2
    ) AS average_carrier_handover_days
FROM orders
WHERE order_approved_at IS NOT NULL
  AND order_delivered_carrier_date IS NOT NULL;


-- 11.3 Average delivery time in days

SELECT
    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_purchase_timestamp
                )
            ) / 86400.0
        )::NUMERIC,
        2
    ) AS average_delivery_days
FROM orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL;


-- 11.4 On-time versus late deliveries

SELECT
    CASE
        WHEN order_delivered_customer_date
             <= order_estimated_delivery_date
            THEN 'On time'
        ELSE 'Late'
    END AS delivery_status,
    COUNT(*) AS order_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_deliveries
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_status
ORDER BY order_count DESC;


-- 11.5 Average delivery delay or early-delivery days

SELECT
    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_estimated_delivery_date
                )
            ) / 86400.0
        )::NUMERIC,
        2
    ) AS average_days_relative_to_estimate
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL;


-- 11.6 Delivery performance by customer state

SELECT
    c.customer_state,
    COUNT(*) AS delivered_orders,
    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    o.order_delivered_customer_date
                    - o.order_purchase_timestamp
                )
            ) / 86400.0
        )::NUMERIC,
        2
    ) AS average_delivery_days,
    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE o.order_delivered_customer_date
                  > o.order_estimated_delivery_date
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS late_delivery_rate
FROM orders AS o
JOIN customers AS c
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY average_delivery_days DESC;


-- 11.7 Delivery-time categories

SELECT
    CASE
        WHEN order_delivered_customer_date::DATE
             - order_purchase_timestamp::DATE <= 7
            THEN '0-7 days'

        WHEN order_delivered_customer_date::DATE
             - order_purchase_timestamp::DATE <= 14
            THEN '8-14 days'

        WHEN order_delivered_customer_date::DATE
             - order_purchase_timestamp::DATE <= 30
            THEN '15-30 days'

        ELSE 'More than 30 days'
    END AS delivery_time_group,
    COUNT(*) AS order_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS order_percentage
FROM orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
GROUP BY delivery_time_group
ORDER BY
    MIN(
        order_delivered_customer_date::DATE
        - order_purchase_timestamp::DATE
    );


-- ============================================================
-- SECTION 12: REVIEW AND CUSTOMER-SATISFACTION ANALYSIS
-- ============================================================


-- 12.1 Review-score distribution

SELECT
    review_score,
    COUNT(*) AS review_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS review_percentage
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;


-- 12.2 Average review score

SELECT
    ROUND(AVG(review_score), 2) AS average_review_score
FROM order_reviews;


-- 12.3 Reviews containing written comments

SELECT
    COUNT(*) AS total_reviews,
    COUNT(*) FILTER (
        WHERE review_comment_message IS NOT NULL
          AND TRIM(review_comment_message) <> ''
    ) AS reviews_with_comments,
    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE review_comment_message IS NOT NULL
              AND TRIM(review_comment_message) <> ''
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS comment_rate
FROM order_reviews;


-- 12.4 Review score by delivery status

SELECT
    CASE
        WHEN o.order_delivered_customer_date
             <= o.order_estimated_delivery_date
            THEN 'On time'
        ELSE 'Late'
    END AS delivery_status,
    COUNT(*) AS review_count,
    ROUND(AVG(r.review_score), 2) AS average_review_score
FROM order_reviews AS r
JOIN orders AS o
    ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_status
ORDER BY average_review_score DESC;


-- 12.5 Average review score by category

SELECT
    COALESCE(
        pct.product_category_name_english,
        p.product_category_name,
        'Unknown'
    ) AS product_category,
    COUNT(DISTINCT r.review_id) AS review_count,
    ROUND(AVG(r.review_score), 2) AS average_review_score
FROM order_reviews AS r
JOIN order_items AS oi
    ON r.order_id = oi.order_id
JOIN products AS p
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation AS pct
    ON p.product_category_name = pct.product_category_name
GROUP BY product_category
HAVING COUNT(DISTINCT r.review_id) >= 20
ORDER BY average_review_score DESC;


-- 12.6 Relationship between delivery duration and review score

SELECT
    r.review_score,
    COUNT(*) AS review_count,
    ROUND(
        AVG(
            EXTRACT(
                EPOCH FROM (
                    o.order_delivered_customer_date
                    - o.order_purchase_timestamp
                )
            ) / 86400.0
        )::NUMERIC,
        2
    ) AS average_delivery_days
FROM order_reviews AS r
JOIN orders AS o
    ON r.order_id = o.order_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY r.review_score
ORDER BY r.review_score;


-- ============================================================
-- SECTION 13: GEOGRAPHIC ANALYSIS
-- ============================================================


-- 13.1 Orders by customer state

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS order_count
FROM customers AS c
JOIN orders AS o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_state
ORDER BY order_count DESC;


-- 13.2 Revenue by customer state

SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    ROUND(
        SUM(oi.price + oi.freight_value),
        2
    ) AS total_revenue
FROM customers AS c
JOIN orders AS o
    ON c.customer_id = o.customer_id
JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue DESC;


-- 13.3 Average order value by customer state

WITH order_financials AS (
    SELECT
        o.order_id,
        c.customer_state,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM orders AS o
    JOIN customers AS c
        ON o.customer_id = c.customer_id
    JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        o.order_id,
        c.customer_state
)

SELECT
    customer_state,
    COUNT(*) AS order_count,
    ROUND(AVG(order_value), 2) AS average_order_value
FROM order_financials
GROUP BY customer_state
ORDER BY average_order_value DESC;


-- 13.4 Same-state versus cross-state transactions

SELECT
    CASE
        WHEN c.customer_state = s.seller_state
            THEN 'Same state'
        ELSE 'Different state'
    END AS transaction_type,
    COUNT(*) AS item_count,
    ROUND(
        SUM(oi.price + oi.freight_value),
        2
    ) AS total_value
FROM order_items AS oi
JOIN orders AS o
    ON oi.order_id = o.order_id
JOIN customers AS c
    ON o.customer_id = c.customer_id
JOIN sellers AS s
    ON oi.seller_id = s.seller_id
WHERE o.order_status = 'delivered'
GROUP BY transaction_type
ORDER BY item_count DESC;


-- ============================================================
-- SECTION 14: ADVANCED WINDOW-FUNCTION ANALYSIS
-- ============================================================


-- 14.1 Rank months by revenue within each year

WITH monthly_revenue AS (
    SELECT
        EXTRACT(
            YEAR FROM o.order_purchase_timestamp
        )::INTEGER AS order_year,
        EXTRACT(
            MONTH FROM o.order_purchase_timestamp
        )::INTEGER AS order_month,
        SUM(oi.price + oi.freight_value) AS revenue
    FROM orders AS o
    JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY
        order_year,
        order_month
)

SELECT
    order_year,
    order_month,
    ROUND(revenue, 2) AS revenue,
    DENSE_RANK() OVER (
        PARTITION BY order_year
        ORDER BY revenue DESC
    ) AS revenue_rank_within_year
FROM monthly_revenue
ORDER BY
    order_year,
    revenue_rank_within_year;


-- 14.2 Three-month moving average revenue

WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC(
            'month',
            o.order_purchase_timestamp
        )::DATE AS order_month,
        SUM(oi.price + oi.freight_value) AS revenue
    FROM orders AS o
    JOIN order_items AS oi
        ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY order_month
)

SELECT
    order_month,
    ROUND(revenue, 2) AS monthly_revenue,
    ROUND(
        AVG(revenue) OVER (
            ORDER BY order_month
            ROWS BETWEEN 2 PRECEDING
            AND CURRENT ROW
        ),
        2
    ) AS three_month_moving_average
FROM monthly_revenue
ORDER BY order_month;


-- 14.3 Quartile classification of orders by value

WITH order_financials AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM order_items AS oi
    JOIN orders AS o
        ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
),

order_quartiles AS (
    SELECT
        order_id,
        order_value,
        NTILE(4) OVER (
            ORDER BY order_value
        ) AS value_quartile
    FROM order_financials
)

SELECT
    order_id,
    ROUND(order_value, 2) AS order_value,
    value_quartile,
    CASE value_quartile
        WHEN 1 THEN 'Low-value orders'
        WHEN 2 THEN 'Lower-middle orders'
        WHEN 3 THEN 'Upper-middle orders'
        WHEN 4 THEN 'High-value orders'
    END AS value_segment
FROM order_quartiles
ORDER BY order_value DESC;


-- 14.4 Contribution of each category to cumulative revenue

WITH category_revenue AS (
    SELECT
        COALESCE(
            pct.product_category_name_english,
            p.product_category_name,
            'Unknown'
        ) AS product_category,
        SUM(oi.price + oi.freight_value) AS revenue
    FROM order_items AS oi
    JOIN orders AS o
        ON oi.order_id = o.order_id
    JOIN products AS p
        ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation AS pct
        ON p.product_category_name = pct.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY product_category
),

revenue_distribution AS (
    SELECT
        product_category,
        revenue,
        SUM(revenue) OVER (
            ORDER BY revenue DESC
            ROWS BETWEEN UNBOUNDED PRECEDING
            AND CURRENT ROW
        ) AS cumulative_revenue,
        SUM(revenue) OVER () AS total_revenue
    FROM category_revenue
)

SELECT
    product_category,
    ROUND(revenue, 2) AS revenue,
    ROUND(
        100.0 * revenue / total_revenue,
        2
    ) AS revenue_percentage,
    ROUND(
        100.0 * cumulative_revenue / total_revenue,
        2
    ) AS cumulative_revenue_percentage
FROM revenue_distribution
ORDER BY revenue DESC;


-- ============================================================
-- SECTION 15: OPTIONAL REUSABLE VIEWS
-- ============================================================


-- 15.1 Order financial summary view

CREATE OR REPLACE VIEW vw_order_financial_summary AS

SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    COUNT(oi.order_item_id) AS item_count,
    SUM(oi.price) AS product_value,
    SUM(oi.freight_value) AS freight_value,
    SUM(oi.price + oi.freight_value) AS total_order_value
FROM orders AS o
LEFT JOIN order_items AS oi
    ON o.order_id = oi.order_id
GROUP BY
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp;


-- Query the order financial summary view

SELECT *
FROM vw_order_financial_summary
ORDER BY total_order_value DESC NULLS LAST
LIMIT 20;


-- 15.2 Customer summary view

CREATE OR REPLACE VIEW vw_customer_summary AS

SELECT
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT o.order_id) FILTER (
        WHERE o.order_status = 'delivered'
    ) AS delivered_orders,
    MIN(o.order_purchase_timestamp) AS first_purchase_date,
    MAX(o.order_purchase_timestamp) AS latest_purchase_date,
    COALESCE(
        SUM(v.total_order_value) FILTER (
            WHERE o.order_status = 'delivered'
        ),
        0
    ) AS customer_lifetime_value
FROM customers AS c
LEFT JOIN orders AS o
    ON c.customer_id = o.customer_id
LEFT JOIN vw_order_financial_summary AS v
    ON o.order_id = v.order_id
GROUP BY c.customer_unique_id;


-- Query the customer summary view

SELECT
    customer_unique_id,
    total_orders,
    delivered_orders,
    first_purchase_date,
    latest_purchase_date,
    ROUND(customer_lifetime_value, 2)
        AS customer_lifetime_value
FROM vw_customer_summary
ORDER BY customer_lifetime_value DESC
LIMIT 20;


-- 15.3 Monthly sales view

CREATE OR REPLACE VIEW vw_monthly_sales AS

SELECT
    DATE_TRUNC(
        'month',
        o.order_purchase_timestamp
    )::DATE AS order_month,
    COUNT(DISTINCT o.order_id) AS delivered_orders,
    COUNT(oi.order_item_id) AS items_sold,
    SUM(oi.price) AS product_revenue,
    SUM(oi.freight_value) AS freight_revenue,
    SUM(oi.price + oi.freight_value) AS total_revenue
FROM orders AS o
JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY order_month;


-- Query the monthly sales view

SELECT
    order_month,
    delivered_orders,
    items_sold,
    ROUND(product_revenue, 2) AS product_revenue,
    ROUND(freight_revenue, 2) AS freight_revenue,
    ROUND(total_revenue, 2) AS total_revenue
FROM vw_monthly_sales
ORDER BY order_month;


-- ============================================================
-- SECTION 16: EXECUTIVE KPI SUMMARY
-- ============================================================


WITH order_financials AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM order_items AS oi
    GROUP BY oi.order_id
),

delivered_order_metrics AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        ofn.order_value
    FROM orders AS o
    JOIN customers AS c
        ON o.customer_id = c.customer_id
    JOIN order_financials AS ofn
        ON o.order_id = ofn.order_id
    WHERE o.order_status = 'delivered'
),

customer_frequency AS (
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM delivered_order_metrics
    GROUP BY customer_unique_id
),

review_metrics AS (
    SELECT
        AVG(review_score) AS average_review_score
    FROM order_reviews
),

delivery_metrics AS (
    SELECT
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_purchase_timestamp
                )
            ) / 86400.0
        ) AS average_delivery_days,

        100.0
        * COUNT(*) FILTER (
            WHERE order_delivered_customer_date
                  <= order_estimated_delivery_date
        )
        / NULLIF(COUNT(*), 0) AS on_time_delivery_rate
    FROM orders
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)

SELECT
    COUNT(DISTINCT dom.order_id)
        AS delivered_orders,

    COUNT(DISTINCT dom.customer_unique_id)
        AS delivered_customers,

    ROUND(SUM(dom.order_value), 2)
        AS total_revenue,

    ROUND(AVG(dom.order_value), 2)
        AS average_order_value,

    ROUND(
        100.0
        * COUNT(*) FILTER (
            WHERE cf.order_count > 1
        )
        / NULLIF(COUNT(*), 0),
        2
    ) AS repeat_customer_rate,

    ROUND(rm.average_review_score, 2)
        AS average_review_score,

    ROUND(dm.average_delivery_days::NUMERIC, 2)
        AS average_delivery_days,

    ROUND(dm.on_time_delivery_rate::NUMERIC, 2)
        AS on_time_delivery_rate

FROM delivered_order_metrics AS dom
JOIN customer_frequency AS cf
    ON dom.customer_unique_id = cf.customer_unique_id
CROSS JOIN review_metrics AS rm
CROSS JOIN delivery_metrics AS dm
GROUP BY
    rm.average_review_score,
    dm.average_delivery_days,
    dm.on_time_delivery_rate;


-- ============================================================
-- END OF FILE
-- ============================================================

One correction is needed in the final executive KPI query: calculating the repeat-customer rate after joining customer frequency back to every order would count repeat customers multiple times. Replace the final section with this more accurate version:

-- ============================================================
-- SECTION 16: EXECUTIVE KPI SUMMARY
-- ============================================================

WITH order_financials AS (
    SELECT
        oi.order_id,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM order_items AS oi
    GROUP BY oi.order_id
),

delivered_order_metrics AS (
    SELECT
        o.order_id,
        c.customer_unique_id,
        ofn.order_value
    FROM orders AS o
    JOIN customers AS c
        ON o.customer_id = c.customer_id
    JOIN order_financials AS ofn
        ON o.order_id = ofn.order_id
    WHERE o.order_status = 'delivered'
),

order_kpis AS (
    SELECT
        COUNT(DISTINCT order_id) AS delivered_orders,
        COUNT(DISTINCT customer_unique_id)
            AS delivered_customers,
        SUM(order_value) AS total_revenue,
        AVG(order_value) AS average_order_value
    FROM delivered_order_metrics
),

customer_frequency AS (
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS order_count
    FROM delivered_order_metrics
    GROUP BY customer_unique_id
),

customer_kpis AS (
    SELECT
        100.0
        * COUNT(*) FILTER (WHERE order_count > 1)
        / NULLIF(COUNT(*), 0)
            AS repeat_customer_rate
    FROM customer_frequency
),

review_kpis AS (
    SELECT
        AVG(review_score) AS average_review_score
    FROM order_reviews
),

delivery_kpis AS (
    SELECT
        AVG(
            EXTRACT(
                EPOCH FROM (
                    order_delivered_customer_date
                    - order_purchase_timestamp
                )
            ) / 86400.0
        ) AS average_delivery_days,

        100.0
        * COUNT(*) FILTER (
            WHERE order_delivered_customer_date
                  <= order_estimated_delivery_date
        )
        / NULLIF(COUNT(*), 0)
            AS on_time_delivery_rate
    FROM orders
    WHERE order_status = 'delivered'
      AND order_purchase_timestamp IS NOT NULL
      AND order_delivered_customer_date IS NOT NULL
      AND order_estimated_delivery_date IS NOT NULL
)

SELECT
    ok.delivered_orders,
    ok.delivered_customers,
    ROUND(ok.total_revenue, 2)
        AS total_revenue,
    ROUND(ok.average_order_value, 2)
        AS average_order_value,
    ROUND(ck.repeat_customer_rate, 2)
        AS repeat_customer_rate,
    ROUND(rk.average_review_score, 2)
        AS average_review_score,
    ROUND(dk.average_delivery_days::NUMERIC, 2)
        AS average_delivery_days,
    ROUND(dk.on_time_delivery_rate::NUMERIC, 2)
        AS on_time_delivery_rate
FROM order_kpis AS ok
CROSS JOIN customer_kpis AS ck
CROSS JOIN review_kpis AS rk
CROSS JOIN delivery_kpis AS dk;
-- ============================================================
-- Project: Advanced SQL Retail Analytics
-- Dataset: Brazilian E-Commerce Public Dataset by Olist
-- Database: PostgreSQL
-- File: schema.sql
-- Purpose: Create the complete relational database schema
-- ============================================================


-- ============================================================
-- 1. OPTIONAL DATABASE CREATION
-- ============================================================
-- Run this statement separately while connected to PostgreSQL.
-- Do not run it if the database already exists.

CREATE DATABASE olist_retail_analytics;


-- ============================================================
-- 2. DROP EXISTING TABLES
-- ============================================================
-- Tables are dropped in reverse dependency order so that
-- foreign-key constraints do not cause errors.

DROP TABLE IF EXISTS order_reviews CASCADE;
DROP TABLE IF EXISTS order_payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS sellers CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS product_category_name_translation CASCADE;
DROP TABLE IF EXISTS geolocation CASCADE;


-- ============================================================
-- 3. CREATE PRODUCT CATEGORY TRANSLATION TABLE
-- ============================================================

CREATE TABLE product_category_name_translation (
    product_category_name VARCHAR(100) PRIMARY KEY,
    product_category_name_english VARCHAR(100)
);


-- ============================================================
-- 4. CREATE CUSTOMERS TABLE
-- ============================================================

CREATE TABLE customers (
    customer_id VARCHAR(32) PRIMARY KEY,
    customer_unique_id VARCHAR(32) NOT NULL,
    customer_zip_code_prefix INTEGER,
    customer_city VARCHAR(100),
    customer_state CHAR(2),

    CONSTRAINT chk_customer_zip_code
        CHECK (
            customer_zip_code_prefix IS NULL
            OR customer_zip_code_prefix >= 0
        )
);


-- ============================================================
-- 5. CREATE SELLERS TABLE
-- ============================================================

CREATE TABLE sellers (
    seller_id VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix INTEGER,
    seller_city VARCHAR(100),
    seller_state CHAR(2),

    CONSTRAINT chk_seller_zip_code
        CHECK (
            seller_zip_code_prefix IS NULL
            OR seller_zip_code_prefix >= 0
        )
);


-- ============================================================
-- 6. CREATE PRODUCTS TABLE
-- ============================================================

CREATE TABLE products (
    product_id VARCHAR(32) PRIMARY KEY,
    product_category_name VARCHAR(100),
    product_name_length INTEGER,
    product_description_length INTEGER,
    product_photos_qty INTEGER,
    product_weight_g NUMERIC(10, 2),
    product_length_cm NUMERIC(10, 2),
    product_height_cm NUMERIC(10, 2),
    product_width_cm NUMERIC(10, 2),

    CONSTRAINT fk_products_category
        FOREIGN KEY (product_category_name)
        REFERENCES product_category_name_translation (
            product_category_name
        )
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_product_name_length
        CHECK (
            product_name_length IS NULL
            OR product_name_length >= 0
        ),

    CONSTRAINT chk_product_description_length
        CHECK (
            product_description_length IS NULL
            OR product_description_length >= 0
        ),

    CONSTRAINT chk_product_photos
        CHECK (
            product_photos_qty IS NULL
            OR product_photos_qty >= 0
        ),

    CONSTRAINT chk_product_weight
        CHECK (
            product_weight_g IS NULL
            OR product_weight_g >= 0
        ),

    CONSTRAINT chk_product_length
        CHECK (
            product_length_cm IS NULL
            OR product_length_cm >= 0
        ),

    CONSTRAINT chk_product_height
        CHECK (
            product_height_cm IS NULL
            OR product_height_cm >= 0
        ),

    CONSTRAINT chk_product_width
        CHECK (
            product_width_cm IS NULL
            OR product_width_cm >= 0
        )
);


-- ============================================================
-- 7. CREATE ORDERS TABLE
-- ============================================================

CREATE TABLE orders (
    order_id VARCHAR(32) PRIMARY KEY,
    customer_id VARCHAR(32) NOT NULL,
    order_status VARCHAR(30) NOT NULL,
    order_purchase_timestamp TIMESTAMP,
    order_approved_at TIMESTAMP,
    order_delivered_carrier_date TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP,

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_order_status
        CHECK (
            order_status IN (
                'approved',
                'canceled',
                'created',
                'delivered',
                'invoiced',
                'processing',
                'shipped',
                'unavailable'
            )
        )
);


-- ============================================================
-- 8. CREATE ORDER ITEMS TABLE
-- ============================================================
-- One order may contain multiple items.
-- Therefore, the primary key is:
-- (order_id, order_item_id)

CREATE TABLE order_items (
    order_id VARCHAR(32) NOT NULL,
    order_item_id INTEGER NOT NULL,
    product_id VARCHAR(32) NOT NULL,
    seller_id VARCHAR(32) NOT NULL,
    shipping_limit_date TIMESTAMP,
    price NUMERIC(12, 2) NOT NULL,
    freight_value NUMERIC(12, 2) NOT NULL,

    CONSTRAINT pk_order_items
        PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_order_items_seller
        FOREIGN KEY (seller_id)
        REFERENCES sellers(seller_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_order_item_id
        CHECK (order_item_id > 0),

    CONSTRAINT chk_order_item_price
        CHECK (price >= 0),

    CONSTRAINT chk_order_item_freight
        CHECK (freight_value >= 0)
);


-- ============================================================
-- 9. CREATE ORDER PAYMENTS TABLE
-- ============================================================
-- One order can have multiple payment records.
-- The payment_sequential column identifies each payment record.

CREATE TABLE order_payments (
    order_id VARCHAR(32) NOT NULL,
    payment_sequential INTEGER NOT NULL,
    payment_type VARCHAR(30) NOT NULL,
    payment_installments INTEGER NOT NULL,
    payment_value NUMERIC(12, 2) NOT NULL,

    CONSTRAINT pk_order_payments
        PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT fk_order_payments_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT chk_payment_sequential
        CHECK (payment_sequential > 0),

    CONSTRAINT chk_payment_type
        CHECK (
            payment_type IN (
                'boleto',
                'credit_card',
                'debit_card',
                'not_defined',
                'voucher'
            )
        ),

    CONSTRAINT chk_payment_installments
        CHECK (payment_installments >= 0),

    CONSTRAINT chk_payment_value
        CHECK (payment_value >= 0)
);


-- ============================================================
-- 10. CREATE ORDER REVIEWS TABLE
-- ============================================================
-- review_id alone is not unique in the source dataset.
-- order_id alone is also not unique.
-- The combination of review_id and order_id is unique.

CREATE TABLE order_reviews (
    review_id VARCHAR(32) NOT NULL,
    order_id VARCHAR(32) NOT NULL,
    review_score INTEGER NOT NULL,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date TIMESTAMP,
    review_answer_timestamp TIMESTAMP,

    CONSTRAINT pk_order_reviews
        PRIMARY KEY (review_id, order_id),

    CONSTRAINT fk_order_reviews_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT chk_review_score
        CHECK (review_score BETWEEN 1 AND 5)
);


-- ============================================================
-- 11. CREATE GEOLOCATION TABLE
-- ============================================================
-- The geolocation ZIP-code prefix is not unique.
-- The source contains multiple latitude and longitude records
-- for the same ZIP-code prefix.
--
-- A generated identifier is therefore used as the primary key.
--
-- This table is not connected directly by a foreign key because
-- customer and seller ZIP-code prefixes can match multiple
-- geolocation records.

CREATE TABLE geolocation (
    geolocation_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    geolocation_zip_code_prefix INTEGER NOT NULL,
    geolocation_lat NUMERIC(10, 7),
    geolocation_lng NUMERIC(10, 7),
    geolocation_city VARCHAR(100),
    geolocation_state CHAR(2),

    CONSTRAINT chk_geolocation_zip_code
        CHECK (geolocation_zip_code_prefix >= 0),

    CONSTRAINT chk_geolocation_latitude
        CHECK (
            geolocation_lat IS NULL
            OR geolocation_lat BETWEEN -90 AND 90
        ),

    CONSTRAINT chk_geolocation_longitude
        CHECK (
            geolocation_lng IS NULL
            OR geolocation_lng BETWEEN -180 AND 180
        )
);


-- ============================================================
-- 12. CREATE INDEXES
-- ============================================================
-- PostgreSQL automatically creates indexes for primary keys.
-- The following indexes improve joins, filtering, and analytics.


-- Customer indexes

CREATE INDEX idx_customers_unique_id
    ON customers(customer_unique_id);

CREATE INDEX idx_customers_zip_code
    ON customers(customer_zip_code_prefix);

CREATE INDEX idx_customers_state
    ON customers(customer_state);


-- Seller indexes

CREATE INDEX idx_sellers_zip_code
    ON sellers(seller_zip_code_prefix);

CREATE INDEX idx_sellers_state
    ON sellers(seller_state);


-- Product indexes

CREATE INDEX idx_products_category
    ON products(product_category_name);


-- Order indexes

CREATE INDEX idx_orders_customer_id
    ON orders(customer_id);

CREATE INDEX idx_orders_status
    ON orders(order_status);

CREATE INDEX idx_orders_purchase_timestamp
    ON orders(order_purchase_timestamp);

CREATE INDEX idx_orders_customer_purchase
    ON orders(customer_id, order_purchase_timestamp);


-- Order item indexes

CREATE INDEX idx_order_items_product_id
    ON order_items(product_id);

CREATE INDEX idx_order_items_seller_id
    ON order_items(seller_id);

CREATE INDEX idx_order_items_shipping_limit
    ON order_items(shipping_limit_date);


-- Payment indexes

CREATE INDEX idx_order_payments_type
    ON order_payments(payment_type);


-- Review indexes

CREATE INDEX idx_order_reviews_order_id
    ON order_reviews(order_id);

CREATE INDEX idx_order_reviews_score
    ON order_reviews(review_score);


-- Geolocation indexes

CREATE INDEX idx_geolocation_zip_code
    ON geolocation(geolocation_zip_code_prefix);

CREATE INDEX idx_geolocation_state
    ON geolocation(geolocation_state);


-- ============================================================
-- 13. TABLE AND COLUMN COMMENTS
-- ============================================================

COMMENT ON TABLE customers IS
    'Customers associated with Olist orders.';

COMMENT ON COLUMN customers.customer_id IS
    'Order-level customer identifier.';

COMMENT ON COLUMN customers.customer_unique_id IS
    'Identifier used to recognize the same customer across multiple orders.';


COMMENT ON TABLE orders IS
    'Order-level status and lifecycle timestamps.';

COMMENT ON TABLE order_items IS
    'Products and sellers associated with each order.';

COMMENT ON TABLE order_payments IS
    'Payment methods, installments, and values associated with orders.';

COMMENT ON TABLE order_reviews IS
    'Customer review scores and review comments.';

COMMENT ON TABLE products IS
    'Product categories, dimensions, weight, and descriptive attributes.';

COMMENT ON TABLE sellers IS
    'Seller identifiers and location attributes.';

COMMENT ON TABLE product_category_name_translation IS
    'Translation of Portuguese product-category names into English.';

COMMENT ON TABLE geolocation IS
    'Latitude and longitude observations associated with Brazilian ZIP-code prefixes.';


-- ============================================================
-- 14. OPTIONAL VERIFICATION QUERIES
-- ============================================================
-- These queries can be run after executing the schema file.

SELECT
    table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;


SELECT
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type
FROM information_schema.table_constraints AS tc
WHERE tc.table_schema = 'public'
ORDER BY
    tc.table_name,
    tc.constraint_type,
    tc.constraint_name;


-- ============================================================
-- END OF FILE
-- ============================================================
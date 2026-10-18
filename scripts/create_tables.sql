-- Olist e-commerce schema for nl_sql_analytics.
-- Tables live in the default public schema.
-- Re-runnable: drops and recreates the Olist tables (and all data in them).
-- Usage: psql -U postgres -d nl_sql_analytics -f scripts/create_tables.sql

DROP TABLE IF EXISTS
    order_reviews,
    order_payments,
    order_items,
    orders,
    geolocation,
    products,
    sellers,
    customers,
    product_category_name_translation
    CASCADE;

-- Lookup / dimension tables ---------------------------------------------------

CREATE TABLE product_category_name_translation (
    product_category_name         text PRIMARY KEY,
    product_category_name_english text NOT NULL
);
COMMENT ON TABLE product_category_name_translation IS
    'Portuguese -> English category names. Not every product category has a translation: always LEFT JOIN from products.';

CREATE TABLE customers (
    customer_id              text PRIMARY KEY,
    customer_unique_id       text NOT NULL,
    customer_zip_code_prefix text NOT NULL,
    customer_city            text NOT NULL,
    customer_state           char(2) NOT NULL
);
COMMENT ON TABLE customers IS
    'One row per order-customer. customer_id is unique per order (1:1 with orders).';
COMMENT ON COLUMN customers.customer_id IS
    'Per-order customer key. Do NOT use to count distinct people.';
COMMENT ON COLUMN customers.customer_unique_id IS
    'The real person. Use COUNT(DISTINCT customer_unique_id) for number of customers and repeat-customer analysis.';
COMMENT ON COLUMN customers.customer_state IS 'Brazilian state code, e.g. SP, RJ, MG.';

CREATE TABLE sellers (
    seller_id              text PRIMARY KEY,
    seller_zip_code_prefix text NOT NULL,
    seller_city            text NOT NULL,
    seller_state           char(2) NOT NULL
);
COMMENT ON TABLE sellers IS
    'Sellers connect to orders only through order_items; one order can have several sellers.';

CREATE TABLE products (
    product_id                 text PRIMARY KEY,
    product_category_name      text,  -- soft link: no FK, some categories lack a translation
    product_name_lenght        integer,  -- column names keep the source spelling
    product_description_lenght integer,
    product_photos_qty         integer,
    product_weight_g           integer,
    product_length_cm          integer,
    product_height_cm          integer,
    product_width_cm           integer
);
COMMENT ON COLUMN products.product_category_name IS
    'Portuguese category name; NULL for some products. Join product_category_name_translation with LEFT JOIN for English names.';
COMMENT ON COLUMN products.product_name_lenght IS 'Number of characters in the product name (source spelling "lenght").';
COMMENT ON COLUMN products.product_description_lenght IS 'Number of characters in the product description (source spelling "lenght").';

CREATE TABLE geolocation (
    geolocation_zip_code_prefix text NOT NULL,
    geolocation_lat             double precision NOT NULL,
    geolocation_lng             double precision NOT NULL,
    geolocation_city            text NOT NULL,
    geolocation_state           char(2) NOT NULL
);
COMMENT ON TABLE geolocation IS
    'Many rows per zip prefix; not a key. Aggregate to one row per geolocation_zip_code_prefix before joining to customers or sellers.';

-- Fact tables -----------------------------------------------------------------

CREATE TABLE orders (
    order_id                      text PRIMARY KEY,
    customer_id                   text NOT NULL REFERENCES customers (customer_id),
    order_status                  text NOT NULL,
    order_purchase_timestamp      timestamp NOT NULL,
    order_approved_at             timestamp,
    order_delivered_carrier_date  timestamp,
    order_delivered_customer_date timestamp,
    order_estimated_delivery_date timestamp NOT NULL
);
COMMENT ON TABLE orders IS
    'One row per order. Timestamps are Brazil local time. Use order_purchase_timestamp for order dates and monthly trends.';
COMMENT ON COLUMN orders.order_status IS
    'e.g. delivered, shipped, canceled, unavailable, invoiced, processing, created, approved.';
COMMENT ON COLUMN orders.order_delivered_customer_date IS
    'Actual delivery date; compare with order_estimated_delivery_date to find late deliveries. NULL if not delivered.';

CREATE TABLE order_items (
    order_id            text NOT NULL REFERENCES orders (order_id),
    order_item_id       integer NOT NULL,
    product_id          text NOT NULL REFERENCES products (product_id),
    seller_id           text NOT NULL REFERENCES sellers (seller_id),
    shipping_limit_date timestamp NOT NULL,
    price               numeric(10, 2) NOT NULL,
    freight_value       numeric(10, 2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);
COMMENT ON TABLE order_items IS
    'One row per item in an order (order_item_id = 1, 2, 3...). Some orders have no items. '
    'Joining order_items and order_payments to orders at the same time multiplies rows: aggregate each child table first.';
COMMENT ON COLUMN order_items.price IS 'Item price in BRL, excluding freight.';

CREATE TABLE order_payments (
    order_id             text NOT NULL REFERENCES orders (order_id),
    payment_sequential   integer NOT NULL,
    payment_type         text NOT NULL,
    payment_installments integer NOT NULL,
    payment_value        numeric(10, 2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);
COMMENT ON TABLE order_payments IS
    'One row per payment method used on an order. Payment value is what the customer paid, not recognized revenue. '
    'Do not join with order_items without aggregating first (row fan-out inflates sums).';
COMMENT ON COLUMN order_payments.payment_type IS 'e.g. credit_card, boleto, voucher, debit_card, not_defined.';

CREATE TABLE order_reviews (
    review_id               text NOT NULL,
    order_id                text NOT NULL REFERENCES orders (order_id),
    review_score            smallint NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_comment_title    text,
    review_comment_message  text,
    review_creation_date    timestamp NOT NULL,
    review_answer_timestamp timestamp NOT NULL,
    PRIMARY KEY (review_id, order_id)
);
COMMENT ON TABLE order_reviews IS
    'Customer reviews (scores 1-5). review_id alone is not unique. Some orders have no review; an order can have more than one.';

-- Indexes for common joins and filters ----------------------------------------

CREATE INDEX ON customers (customer_unique_id);
CREATE INDEX ON customers (customer_zip_code_prefix);
CREATE INDEX ON sellers (seller_zip_code_prefix);
CREATE INDEX ON products (product_category_name);
CREATE INDEX ON geolocation (geolocation_zip_code_prefix);
CREATE INDEX ON orders (customer_id);
CREATE INDEX ON orders (order_purchase_timestamp);
CREATE INDEX ON order_items (product_id);
CREATE INDEX ON order_items (seller_id);
CREATE INDEX ON order_reviews (order_id);

# Business Definitions

How the agent calculates common business terms on the Olist database. These definitions are included in the LLM prompt so the same question always gets the same calculation. If a question uses one of these terms, follow the definition here and state it as an assumption in the answer. If a question explicitly asks for something different (e.g. "including canceled orders"), follow the question.

## Orders

**Order count**
All orders, any status, unless the question narrows it (e.g. "delivered orders", "canceled orders").
```sql
SELECT COUNT(*) FROM orders;
```

**Order date / order month**
Use `orders.order_purchase_timestamp`. For monthly trends, group by `date_trunc('month', order_purchase_timestamp)`.

**Delivered order**
`order_status = 'delivered'`.

## Money

**Revenue / sales**
Sum of item prices on delivered orders, excluding freight. Currency is BRL.
```sql
SELECT SUM(oi.price)
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';
```

**Freight**
`SUM(order_items.freight_value)`, on delivered orders unless stated otherwise.

**Payment value**
What customers paid, including freight: `SUM(order_payments.payment_value)`. This is not revenue. Use it only for questions about payments or payment types.

**Average order value (AOV)**
Revenue divided by the number of delivered orders that have items. Aggregate items per order first:
```sql
SELECT AVG(order_total)
FROM (
    SELECT oi.order_id, SUM(oi.price) AS order_total
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.order_id
) t;
```

## Customers

**Number of customers**
`COUNT(DISTINCT customers.customer_unique_id)`. Never count `customer_id`: it is a new ID per order.

**Repeat customer**
A `customer_unique_id` with more than one order.

**Customer location**
`customers.customer_state` / `customer_city`. State codes are two-letter Brazilian states (SP = São Paulo, RJ = Rio de Janeiro, MG = Minas Gerais, ...).

## Delivery

**Late delivery**
A delivered order where `order_delivered_customer_date > order_estimated_delivery_date`. Orders without a delivery date are excluded, not counted as late.

**Delivery time**
Days from purchase to delivery, delivered orders only:
`EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400`.

## Products and sellers

**Product category**
English name from `product_category_name_translation`, falling back to the Portuguese name, then `'unknown'`:
```sql
COALESCE(t.product_category_name_english, p.product_category_name, 'unknown')
-- FROM products p LEFT JOIN product_category_name_translation t
--   ON t.product_category_name = p.product_category_name
```

**Orders per category / seller**
Count distinct orders, not item rows: `COUNT(DISTINCT oi.order_id)`. One order can contain several items from several categories and sellers.

## Reviews

**Average review score**
`AVG(order_reviews.review_score)` (scale 1–5). Reviews link to products and sellers only through `orders` → `order_items`.

## Data period and caveats

- Orders span roughly September 2016 to October 2018. The first months of 2016 and the last months of 2018 have very few orders; mention this when showing trends, and do not read them as real drops or spikes.
- There is no "today" in this dataset. Interpret relative dates ("last year", "last month") against the latest order date in the data, and state that assumption.
- Never join `order_items` and `order_payments` to `orders` in the same query without aggregating each one per order first: the row fan-out inflates sums.

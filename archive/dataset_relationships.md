# Olist Dataset Relationships

Image version: [dataset_relationships.svg](dataset_relationships.svg)

```mermaid
erDiagram
    customers ||--|| orders : "customer_id"
    orders ||--o{ order_items : "order_id"
    orders ||--o{ order_payments : "order_id"
    orders ||--o{ order_reviews : "order_id"
    products ||--o{ order_items : "product_id"
    sellers ||--o{ order_items : "seller_id"
    product_category_name_translation |o--o{ products : "product_category_name (soft)"
    geolocation }o..o{ customers : "zip prefix (not a key)"
    geolocation }o..o{ sellers : "zip prefix (not a key)"

    customers {
        string customer_id PK
        string customer_unique_id
        string customer_zip_code_prefix
        string customer_city
        string customer_state
    }
    orders {
        string order_id PK
        string customer_id FK
        string order_status
        timestamp order_purchase_timestamp
        timestamp order_approved_at
        timestamp order_delivered_carrier_date
        timestamp order_delivered_customer_date
        timestamp order_estimated_delivery_date
    }
    order_items {
        string order_id PK, FK
        int order_item_id PK
        string product_id FK
        string seller_id FK
        timestamp shipping_limit_date
        numeric price
        numeric freight_value
    }
    order_payments {
        string order_id PK, FK
        int payment_sequential PK
        string payment_type
        int payment_installments
        numeric payment_value
    }
    order_reviews {
        string review_id PK
        string order_id PK, FK
        int review_score
        string review_comment_title
        string review_comment_message
        timestamp review_creation_date
        timestamp review_answer_timestamp
    }
    products {
        string product_id PK
        string product_category_name FK
        int product_name_lenght
        int product_description_lenght
        int product_photos_qty
        int product_weight_g
        int product_length_cm
        int product_height_cm
        int product_width_cm
    }
    sellers {
        string seller_id PK
        string seller_zip_code_prefix
        string seller_city
        string seller_state
    }
    product_category_name_translation {
        string product_category_name PK
        string product_category_name_english
    }
    geolocation {
        string geolocation_zip_code_prefix
        numeric geolocation_lat
        numeric geolocation_lng
        string geolocation_city
        string geolocation_state
    }
```

## Notes (verified against the CSVs in this folder)

| Table | Rows |
|---|---|
| customers | 99,441 |
| orders | 99,441 |
| order_items | 112,650 |
| order_payments | 103,886 |
| order_reviews | 99,224 |
| products | 32,951 |
| sellers | 3,095 |
| geolocation | 1,000,163 |
| product_category_name_translation | 71 |

- **orders ↔ customers is 1 : 1.** Every order has its own `customer_id` (99,441 orders, 99,441 distinct IDs). Use `customer_unique_id` to identify real, repeat customers.
- **All order, customer, product, and seller links are complete** — 0 orphan foreign keys.
- **Not every order has children:** 775 orders have no items, 1 has no payment, 768 have no review.
- **Sellers connect to orders only through `order_items`;** one order can involve several sellers.
- **`review_id` is not unique on its own** (814 repeats); the key is `(review_id, order_id)`.
- **Category translation is a soft link:** 610 products have no category, and `pc_gamer` and `portateis_cozinha_e_preparadores_de_alimentos` (13 products) have no English translation. Use a LEFT JOIN.
- **Geolocation is not a key target:** zip prefixes repeat (19,015 distinct across ~1M rows), and 157 customer and 7 seller prefixes are missing. Aggregate to one row per prefix before joining.
- **Fan-out warning:** joining `orders` to two child tables at once (e.g. items and payments) multiplies rows and inflates sums. Aggregate each child table first.

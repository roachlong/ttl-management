-- Switch to your order_management database
USE order_management;

-- 1) Insert ~100 customers
INSERT INTO customers (first_name, last_name, email, phone)
SELECT
  first_names[f] AS first_name,
  last_names[l]  AS last_name,
  LOWER(first_names[f] || '.' || last_names[l]) || ROUND((RANDOM() * 1000)::NUMERIC, 0) || '@example.com' AS email,
  LPAD(CAST(FLOOR(RANDOM() * 9000000000 + 1000000000) AS INT)::STRING, 10, '0') AS phone
FROM
  GENERATE_SERIES(1,100) AS g(i),
  LATERAL (
    SELECT ARRAY['Alice','Bob','Charlie','David','Eve','Frank','Grace','Hannah','Ivy','Jack'] AS first_names
  ),
  LATERAL (
    SELECT ARRAY['Smith','Johnson','Williams','Jones','Brown','Davis','Miller','Wilson','Moore','Taylor'] AS last_names
  ),
  LATERAL (
    -- pick a random index into each array
    SELECT
      CAST(FLOOR(RANDOM()*ARRAY_LENGTH(first_names, 1)::float + 1) AS INT) AS f,
      CAST(FLOOR(RANDOM()*ARRAY_LENGTH(last_names, 1)::float  + 1) AS INT) AS l
  );

-- 2) Insert 50 products
INSERT INTO products (name, description, sku, price)
SELECT
  'Product ' || i AS name,
  'Description for product ' || i AS description,
  'SKU-' || LPAD(i::STRING, 4, '0') AS sku,
  ROUND((RANDOM() * 100 + 1)::NUMERIC, 2) AS price
FROM GENERATE_SERIES(1,50) AS g(i);

-- 3) Insert 200 orders (total_amount = 0 placeholder for now)
INSERT INTO orders (customer_id, order_status, total_amount, placed_at, updated_at)
SELECT
  (SELECT customer_id FROM customers ORDER BY RANDOM() LIMIT 1) AS customer_id,
  (ARRAY['pending','processing','shipped','delivered','cancelled'])[CAST(FLOOR(RANDOM()*5 + 1) AS INT)] AS order_status,
  0.00 AS total_amount,
  NOW() - (RANDOM() * 30 || ' days')::INTERVAL AS placed_at,
  NOW() AS updated_at
FROM GENERATE_SERIES(1,200);

-- 4) Insert order_items: 1–5 random line-items per order
INSERT INTO order_items (order_id, product_id, quantity, unit_price, created_at)
SELECT
  o.order_id,
  p.product_id,
  CAST(CEIL(RANDOM()*5) AS INT)      AS quantity,
  p.price                            AS unit_price,
  o.placed_at + (RANDOM()*2 || ' hours')::INTERVAL AS created_at
FROM orders AS o
JOIN LATERAL (
  -- pick a random subset of products
  SELECT product_id, price
  FROM products
  ORDER BY RANDOM()
  LIMIT CAST(FLOOR(RANDOM()*5 + 1) AS INT)
) AS p ON TRUE;

-- 5) Recompute each order’s total_amount from its items
UPDATE orders
SET total_amount = t.sum
FROM (
  SELECT order_id, SUM(quantity * unit_price) AS sum
  FROM order_items
  GROUP BY order_id
) AS t
WHERE orders.order_id = t.order_id;

-- 6) One payment per order
INSERT INTO payments (order_id, amount, method, paid_at)
SELECT
  order_id,
  total_amount,
  (ARRAY['credit_card','paypal','bank_transfer','cash'])[CAST(FLOOR(RANDOM()*4 + 1) AS INT)] AS method,
  placed_at + (RANDOM()*48 || ' hours')::INTERVAL AS paid_at
FROM orders;

-- 7) Shipments for non-cancelled orders
INSERT INTO shipments (order_id, carrier, tracking_no, shipped_at, delivered_at)
SELECT
  order_id,
  (ARRAY['UPS','FedEx','DHL','USPS'])[CAST(FLOOR(RANDOM()*4 + 1) AS INT)] AS carrier,
  SUBSTRING(uuid_v4()::STRING, 1, 8)                              AS tracking_no,
  placed_at + (RANDOM()*72 || ' hours')::INTERVAL                AS shipped_at,
  placed_at + ((RANDOM()*72) + (RANDOM()*72) || ' hours')::INTERVAL AS delivered_at
FROM orders
WHERE order_status IN ('processing','shipped','delivered');

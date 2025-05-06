-- Create and switch to your database
CREATE DATABASE IF NOT EXISTS order_management;
USE order_management;

-- Enable the UUID extension (if not already enabled)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- CUSTOMERS
CREATE TABLE IF NOT EXISTS customers (
    customer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name   STRING    NOT NULL,
    last_name    STRING    NOT NULL,
    email        STRING    NOT NULL UNIQUE,
    phone        STRING,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- PRODUCTS
CREATE TABLE IF NOT EXISTS products (
    product_id   UUID       PRIMARY KEY DEFAULT gen_random_uuid(),
    name         STRING     NOT NULL,
    description  STRING,
    sku          STRING     NOT NULL UNIQUE,
    price        DECIMAL(10,2) NOT NULL CHECK (price >= 0),
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ORDERS
CREATE TABLE IF NOT EXISTS orders (
    order_id     UUID       PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id  UUID       NOT NULL REFERENCES customers(customer_id),
    order_status STRING     NOT NULL DEFAULT 'pending',
    total_amount DECIMAL(12,2) NOT NULL CHECK (total_amount >= 0),
    placed_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ON orders (customer_id);
CREATE INDEX ON orders (order_status);

-- ORDER ITEMS (line‐items)
CREATE TABLE IF NOT EXISTS order_items (
    order_item_id UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id      UUID      NOT NULL REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id    UUID      NOT NULL REFERENCES products(product_id),
    quantity      INT       NOT NULL CHECK (quantity > 0),
    unit_price    DECIMAL(10,2) NOT NULL CHECK (unit_price >= 0),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ON order_items (order_id);
CREATE INDEX ON order_items (product_id);

-- PAYMENTS
CREATE TABLE IF NOT EXISTS payments (
    payment_id   UUID       PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id     UUID       NOT NULL REFERENCES orders(order_id),
    amount       DECIMAL(12,2) NOT NULL CHECK (amount >= 0),
    method       STRING     NOT NULL,  -- e.g. 'credit_card', 'paypal'
    paid_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ON payments (order_id);

-- SHIPMENTS
CREATE TABLE IF NOT EXISTS shipments (
    shipment_id   UUID       PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id      UUID       NOT NULL REFERENCES orders(order_id),
    carrier       STRING     NOT NULL,  -- e.g. 'UPS', 'FedEx'
    tracking_no   STRING     UNIQUE,
    shipped_at    TIMESTAMPTZ,
    delivered_at  TIMESTAMPTZ
);
CREATE INDEX ON shipments (order_id);

-- OPTIONAL: Trigger to keep updated_at in sync
CREATE OR REPLACE FUNCTION update_timestamp() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- End of schema

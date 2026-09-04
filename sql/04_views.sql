USE supplycore;

-- Inventory overview

CREATE OR REPLACE VIEW inventory_overview AS
SELECT
    i.inventory_id,
    w.name AS warehouse_name,
    w.city,
    b.name AS brand_name,
    f.name AS family_name,
    pm.name AS model_name,
    pv.storage,
    pv.color,
    pv.sku,
    i.quantity
FROM inventory AS i
JOIN warehouse AS w
    ON w.warehouse_id = i.warehouse_id
JOIN product_variant AS pv
    ON pv.variant_id = i.variant_id
JOIN product_model AS pm
    ON pm.model_id = pv.model_id
JOIN family AS f
    ON f.family_id = pm.family_id
JOIN brand AS b
    ON b.brand_id = f.brand_id;


-- Sales order summary

CREATE OR REPLACE VIEW sales_order_summary AS
SELECT
    so.sales_order_id,
    c.full_name AS customer_name,
    w.name AS warehouse_name,
    so.status,
    so.created_at,
    so.confirmed_at,
    COUNT(soi.sales_order_item_id) AS item_count,
    SUM(soi.quantity) AS total_quantity,
    SUM(soi.quantity * soi.unit_price) AS total_amount
FROM sales_order AS so
JOIN customer AS c
    ON c.customer_id = so.customer_id
JOIN warehouse AS w
    ON w.warehouse_id = so.warehouse_id
JOIN sales_order_item AS soi
    ON soi.sales_order_id = so.sales_order_id
GROUP BY
    so.sales_order_id,
    c.full_name,
    w.name,
    so.status,
    so.created_at,
    so.confirmed_at;


-- Low stock products

CREATE OR REPLACE VIEW low_stock_products AS
SELECT
    warehouse_name,
    city,
    brand_name,
    model_name,
    storage,
    color,
    sku,
    quantity
FROM inventory_overview
WHERE quantity < 10;
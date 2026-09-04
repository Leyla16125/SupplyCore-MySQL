USE supplycore;

-- Categories and brands

INSERT INTO category (name)
VALUES
    ('Smartphones'),
    ('Laptops');

INSERT INTO brand (name)
VALUES
    ('Apple'),
    ('Samsung');


-- Product families

INSERT INTO family (name, category_id, brand_id)
VALUES
(
    'iPhone',
    (SELECT category_id
     FROM category
     WHERE name = 'Smartphones'),
    (SELECT brand_id
     FROM brand
     WHERE name = 'Apple')
),
(
    'Galaxy S',
    (SELECT category_id
     FROM category
     WHERE name = 'Smartphones'),
    (SELECT brand_id
     FROM brand
     WHERE name = 'Samsung')
);


-- Product models

INSERT INTO product_model (name, family_id)
VALUES
(
    'iPhone 17',
    (SELECT family_id
     FROM family
     WHERE name = 'iPhone')
),
(
    'iPhone 17 Pro',
    (SELECT family_id
     FROM family
     WHERE name = 'iPhone')
),
(
    'iPhone 17 Pro Max',
    (SELECT family_id
     FROM family
     WHERE name = 'iPhone')
),
(
    'Galaxy S25',
    (SELECT family_id
     FROM family
     WHERE name = 'Galaxy S')
),
(
    'Galaxy S25 Ultra',
    (SELECT family_id
     FROM family
     WHERE name = 'Galaxy S')
);


-- Product variants

INSERT INTO product_variant (
    model_id,
    storage,
    color,
    sku
)
VALUES
(
    (SELECT model_id
     FROM product_model
     WHERE name = 'iPhone 17 Pro Max'),
    '256GB',
    'Deep Blue',
    'IP17PM-256-DBL'
),
(
    (SELECT model_id
     FROM product_model
     WHERE name = 'iPhone 17 Pro Max'),
    '512GB',
    'Deep Blue',
    'IP17PM-512-DBL'
),
(
    (SELECT model_id
     FROM product_model
     WHERE name = 'iPhone 17 Pro Max'),
    '256GB',
    'Silver',
    'IP17PM-256-SLV'
);


-- Warehouses

INSERT INTO warehouse (name, city)
VALUES
    ('Baku Warehouse', 'Baku'),
    ('Nakhchivan Warehouse', 'Nakhchivan'),
    ('Ganja Warehouse', 'Ganja');


-- Suppliers

INSERT INTO supplier (name, country)
VALUES
    ('ABC Distribution', 'Azerbaijan'),
    ('Global Tech Supply', 'Turkey');


-- Initial inventory

INSERT INTO inventory (
    warehouse_id,
    variant_id,
    quantity
)
VALUES
(
    (SELECT warehouse_id
     FROM warehouse
     WHERE name = 'Baku Warehouse'),
    (SELECT variant_id
     FROM product_variant
     WHERE sku = 'IP17PM-256-DBL'),
    20
),
(
    (SELECT warehouse_id
     FROM warehouse
     WHERE name = 'Baku Warehouse'),
    (SELECT variant_id
     FROM product_variant
     WHERE sku = 'IP17PM-512-DBL'),
    10
),
(
    (SELECT warehouse_id
     FROM warehouse
     WHERE name = 'Baku Warehouse'),
    (SELECT variant_id
     FROM product_variant
     WHERE sku = 'IP17PM-256-SLV'),
    15
),
(
    (SELECT warehouse_id
     FROM warehouse
     WHERE name = 'Nakhchivan Warehouse'),
    (SELECT variant_id
     FROM product_variant
     WHERE sku = 'IP17PM-256-DBL'),
    8
),
(
    (SELECT warehouse_id
     FROM warehouse
     WHERE name = 'Nakhchivan Warehouse'),
    (SELECT variant_id
     FROM product_variant
     WHERE sku = 'IP17PM-512-DBL'),
    5
),
(
    (SELECT warehouse_id
     FROM warehouse
     WHERE name = 'Nakhchivan Warehouse'),
    (SELECT variant_id
     FROM product_variant
     WHERE sku = 'IP17PM-256-SLV'),
    7
);


-- Purchase order

INSERT INTO purchase_order (
    supplier_id,
    status,
    order_date
)
VALUES
(
    (SELECT supplier_id
     FROM supplier
     WHERE name = 'ABC Distribution'),
    'ORDERED',
    CURRENT_DATE
);

SET @purchase_order_id = LAST_INSERT_ID();

INSERT INTO purchase_order_item (
    purchase_order_id,
    variant_id,
    quantity,
    unit_cost
)
VALUES
(
    @purchase_order_id,
    (SELECT variant_id
     FROM product_variant
     WHERE sku = 'IP17PM-256-DBL'),
    30,
    1800.00
);
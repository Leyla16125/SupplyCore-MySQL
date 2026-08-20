CREATE DATABASE IF NOT EXISTS supplycore;
USE supplycore;

-- Product structure

CREATE TABLE category (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE brand (
    brand_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

CREATE TABLE family (
    family_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category_id INT NOT NULL,
    brand_id INT NOT NULL,

    FOREIGN KEY (category_id) REFERENCES category(category_id),
    FOREIGN KEY (brand_id) REFERENCES brand(brand_id)
);

CREATE TABLE product_model (
    model_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    family_id INT NOT NULL,

    FOREIGN KEY (family_id) REFERENCES family(family_id)
);

CREATE TABLE product_variant (
    variant_id INT AUTO_INCREMENT PRIMARY KEY,
    model_id INT NOT NULL,
    storage VARCHAR(50) NOT NULL,
    color VARCHAR(50) NOT NULL,
    sku VARCHAR(100) NOT NULL UNIQUE,

    FOREIGN KEY (model_id) REFERENCES product_model(model_id),

    UNIQUE (model_id, storage, color)
);

-- Warehouses and inventory

CREATE TABLE warehouse (
    warehouse_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL
);

CREATE TABLE inventory (
    inventory_id INT AUTO_INCREMENT PRIMARY KEY,
    warehouse_id INT NOT NULL,
    variant_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 0,

    FOREIGN KEY (warehouse_id) REFERENCES warehouse(warehouse_id),
    FOREIGN KEY (variant_id) REFERENCES product_variant(variant_id),

    UNIQUE (warehouse_id, variant_id)
);

-- Suppliers and purchasing

CREATE TABLE supplier (
    supplier_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    country VARCHAR(100) NOT NULL
);

CREATE TABLE purchase_order (
    purchase_order_id INT AUTO_INCREMENT PRIMARY KEY,
    supplier_id INT NOT NULL,
    status VARCHAR(50) NOT NULL,
    order_date DATE NOT NULL,

    FOREIGN KEY (supplier_id) REFERENCES supplier(supplier_id)
);

CREATE TABLE purchase_order_item (
    purchase_order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    purchase_order_id INT NOT NULL,
    variant_id INT NOT NULL,
    quantity INT NOT NULL,
    unit_cost DECIMAL(10,2) NOT NULL,

    FOREIGN KEY (purchase_order_id)
        REFERENCES purchase_order(purchase_order_id),

    FOREIGN KEY (variant_id)
        REFERENCES product_variant(variant_id)
);
USE supplycore;

-- Inventory rules

ALTER TABLE inventory
ADD CONSTRAINT chk_inventory_quantity
CHECK (quantity >= 0);


-- Purchase order rules

ALTER TABLE purchase_order
ADD CONSTRAINT chk_purchase_order_status
CHECK (status IN ('CREATED', 'ORDERED', 'RECEIVED', 'CANCELLED'));


-- Purchase item rules

ALTER TABLE purchase_order_item
ADD CONSTRAINT chk_purchase_quantity
CHECK (quantity > 0);

ALTER TABLE purchase_order_item
ADD CONSTRAINT chk_purchase_unit_cost
CHECK (unit_cost > 0);


-- Sales order rules

ALTER TABLE sales_order
ADD CONSTRAINT chk_sales_order_status
CHECK (
    status IN (
        'DRAFT',
        'CONFIRMED',
        'CANCELLED'
    )
);

-- Sales item rules

ALTER TABLE sales_order_item
ADD CONSTRAINT chk_sales_quantity
CHECK (quantity > 0);

ALTER TABLE sales_order_item
ADD CONSTRAINT chk_sales_unit_price
CHECK (unit_price > 0);

-- Stock movement rules

ALTER TABLE stock_movement
ADD CONSTRAINT chk_stock_movement_type
CHECK (
    movement_type IN (
        'PURCHASE',
        'SALE',
        'TRANSFER_IN',
        'TRANSFER_OUT',
        'RETURN_IN'
    )
);

ALTER TABLE stock_movement
ADD CONSTRAINT chk_stock_movement_quantity
CHECK (quantity > 0);
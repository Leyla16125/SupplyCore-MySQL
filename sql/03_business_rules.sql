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
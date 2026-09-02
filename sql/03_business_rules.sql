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


-- Warehouse transfer rules

ALTER TABLE warehouse_transfer
ADD CONSTRAINT chk_transfer_warehouses
CHECK (from_warehouse_id <> to_warehouse_id);

ALTER TABLE warehouse_transfer
ADD CONSTRAINT chk_transfer_status
CHECK (
    status IN (
        'COMPLETED',
        'CANCELLED'
    )
);


-- Sales return rules

ALTER TABLE sales_return
ADD CONSTRAINT chk_sales_return_status
CHECK (
    status IN (
        'COMPLETED',
        'CANCELLED'
    )
);

ALTER TABLE sales_return_item
ADD CONSTRAINT chk_sales_return_quantity
CHECK (quantity > 0);


DROP PROCEDURE IF EXISTS return_sales_item;

DELIMITER //

CREATE PROCEDURE return_sales_item (
    IN p_sales_order_id INT,
    IN p_variant_id INT,
    IN p_quantity INT
)
BEGIN
    DECLARE v_order_status VARCHAR(30);
    DECLARE v_warehouse_id INT;
    DECLARE v_sold_quantity INT DEFAULT NULL;
    DECLARE v_returned_quantity INT DEFAULT 0;
    DECLARE v_return_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Lock order

    SELECT
        status,
        warehouse_id
    INTO
        v_order_status,
        v_warehouse_id
    FROM sales_order
    WHERE sales_order_id = p_sales_order_id
    FOR UPDATE;

    IF v_order_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Sales order not found';
    END IF;

    IF v_order_status <> 'CONFIRMED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only confirmed orders can be returned';
    END IF;

    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Return quantity must be greater than zero';
    END IF;

    -- Validate sold item

    SELECT quantity
    INTO v_sold_quantity
    FROM sales_order_item
    WHERE sales_order_id = p_sales_order_id
      AND variant_id = p_variant_id;

    IF v_sold_quantity IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Product was not sold in this order';
    END IF;

    -- Validate previous returns

    SELECT COALESCE(SUM(sri.quantity), 0)
    INTO v_returned_quantity
    FROM sales_return_item AS sri
    JOIN sales_return AS sr
        ON sr.return_id = sri.return_id
    WHERE sr.sales_order_id = p_sales_order_id
      AND sri.variant_id = p_variant_id
      AND sr.status = 'COMPLETED';

    IF v_returned_quantity + p_quantity > v_sold_quantity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Return quantity exceeds sold quantity';
    END IF;

    -- Create return

    INSERT INTO sales_return (
        sales_order_id
    )
    VALUES (
        p_sales_order_id
    );

    SET v_return_id = LAST_INSERT_ID();

    INSERT INTO sales_return_item (
        return_id,
        variant_id,
        quantity
    )
    VALUES (
        v_return_id,
        p_variant_id,
        p_quantity
    );

    -- Update inventory

    INSERT INTO inventory (
        warehouse_id,
        variant_id,
        quantity
    )
    VALUES (
        v_warehouse_id,
        p_variant_id,
        p_quantity
    )
    ON DUPLICATE KEY UPDATE
        inventory.quantity = inventory.quantity + VALUES(quantity);

    -- Record movement

    INSERT INTO stock_movement (
        warehouse_id,
        variant_id,
        movement_type,
        quantity,
        reference_type,
        reference_id
    )
    VALUES (
        v_warehouse_id,
        p_variant_id,
        'RETURN_IN',
        p_quantity,
        'SALES_RETURN',
        v_return_id
    );

    COMMIT;
END //

DELIMITER ;
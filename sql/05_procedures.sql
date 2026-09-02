DROP PROCEDURE IF EXISTS confirm_sales_order;

DELIMITER //

CREATE PROCEDURE confirm_sales_order (
    IN p_sales_order_id INT
)
BEGIN
    DECLARE v_order_status VARCHAR(30);
    DECLARE v_warehouse_id INT;
    DECLARE v_item_count INT DEFAULT 0;
    DECLARE v_insufficient_stock INT DEFAULT 0;

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

    IF v_order_status <> 'DRAFT' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only draft orders can be confirmed';
    END IF;

    -- Validate order items

    SELECT COUNT(*)
    INTO v_item_count
    FROM sales_order_item
    WHERE sales_order_id = p_sales_order_id;

    IF v_item_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot confirm an empty order';
    END IF;

    -- Lock inventory

    SELECT i.inventory_id
    FROM inventory AS i
    JOIN sales_order_item AS soi
        ON soi.variant_id = i.variant_id
    WHERE soi.sales_order_id = p_sales_order_id
      AND i.warehouse_id = v_warehouse_id
    FOR UPDATE;

    -- Validate stock

    SELECT COUNT(*)
    INTO v_insufficient_stock
    FROM sales_order_item AS soi
    LEFT JOIN inventory AS i
        ON i.variant_id = soi.variant_id
       AND i.warehouse_id = v_warehouse_id
    WHERE soi.sales_order_id = p_sales_order_id
      AND (
          i.inventory_id IS NULL
          OR i.quantity < soi.quantity
      );

    IF v_insufficient_stock > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient stock for one or more items';
    END IF;

    -- Update inventory

    UPDATE inventory AS i
    JOIN sales_order_item AS soi
        ON soi.variant_id = i.variant_id
    SET i.quantity = i.quantity - soi.quantity
    WHERE soi.sales_order_id = p_sales_order_id
      AND i.warehouse_id = v_warehouse_id;

    -- Record movement

    INSERT INTO stock_movement (
        warehouse_id,
        variant_id,
        movement_type,
        quantity,
        reference_type,
        reference_id
    )
    SELECT
        v_warehouse_id,
        soi.variant_id,
        'SALE',
        soi.quantity,
        'SALES_ORDER',
        p_sales_order_id
    FROM sales_order_item AS soi
    WHERE soi.sales_order_id = p_sales_order_id;

    -- Confirm order

    UPDATE sales_order
    SET
        status = 'CONFIRMED',
        confirmed_at = CURRENT_TIMESTAMP
    WHERE sales_order_id = p_sales_order_id;

    COMMIT;
END //

DELIMITER ;


DROP PROCEDURE IF EXISTS receive_purchase_order;

DELIMITER //

CREATE PROCEDURE receive_purchase_order (
    IN p_purchase_order_id INT,
    IN p_warehouse_id INT
)
BEGIN
    DECLARE v_order_status VARCHAR(50);
    DECLARE v_item_count INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Lock order

    SELECT status
    INTO v_order_status
    FROM purchase_order
    WHERE purchase_order_id = p_purchase_order_id
    FOR UPDATE;

    IF v_order_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Purchase order not found';
    END IF;

    IF v_order_status <> 'ORDERED' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only ordered purchase orders can be received';
    END IF;

    -- Validate order items

    SELECT COUNT(*)
    INTO v_item_count
    FROM purchase_order_item
    WHERE purchase_order_id = p_purchase_order_id;

    IF v_item_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot receive an empty purchase order';
    END IF;

    -- Update inventory

    INSERT INTO inventory (
        warehouse_id,
        variant_id,
        quantity
    )
    SELECT
        p_warehouse_id,
        poi.variant_id,
        poi.quantity
    FROM purchase_order_item AS poi
    WHERE poi.purchase_order_id = p_purchase_order_id
    
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
    SELECT
        p_warehouse_id,
        poi.variant_id,
        'PURCHASE',
        poi.quantity,
        'PURCHASE_ORDER',
        p_purchase_order_id
    FROM purchase_order_item AS poi
    WHERE poi.purchase_order_id = p_purchase_order_id;

    -- Receive order

    UPDATE purchase_order
    SET status = 'RECEIVED'
    WHERE purchase_order_id = p_purchase_order_id;

    COMMIT;
END //

DELIMITER ;
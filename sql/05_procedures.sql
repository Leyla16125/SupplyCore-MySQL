USE supplycore;

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


DROP PROCEDURE IF EXISTS transfer_stock;

DELIMITER //

CREATE PROCEDURE transfer_stock (
    IN p_from_warehouse_id INT,
    IN p_to_warehouse_id INT,
    IN p_variant_id INT,
    IN p_quantity INT
)
BEGIN
    DECLARE v_available_quantity INT DEFAULT NULL;
    DECLARE v_transfer_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;

    -- Validate transfer

    IF p_from_warehouse_id = p_to_warehouse_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Source and destination warehouses must be different';
    END IF;

    IF p_quantity <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Transfer quantity must be greater than zero';
    END IF;

    -- Lock source inventory

    SELECT quantity
    INTO v_available_quantity
    FROM inventory
    WHERE warehouse_id = p_from_warehouse_id
      AND variant_id = p_variant_id
    FOR UPDATE;

    IF v_available_quantity IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Product not found in source warehouse';
    END IF;

    IF v_available_quantity < p_quantity THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Insufficient stock for transfer';
    END IF;

    -- Create transfer

    INSERT INTO warehouse_transfer (
        from_warehouse_id,
        to_warehouse_id
    )
    VALUES (
        p_from_warehouse_id,
        p_to_warehouse_id
    );

    SET v_transfer_id = LAST_INSERT_ID();

    -- Reduce source inventory

    UPDATE inventory
    SET quantity = quantity - p_quantity
    WHERE warehouse_id = p_from_warehouse_id
      AND variant_id = p_variant_id;

    -- Increase destination inventory

    INSERT INTO inventory (
        warehouse_id,
        variant_id,
        quantity
    )
    VALUES (
        p_to_warehouse_id,
        p_variant_id,
        p_quantity
    )
    ON DUPLICATE KEY UPDATE
        inventory.quantity = inventory.quantity + VALUES(quantity);

    -- Record transfer out

    INSERT INTO stock_movement (
        warehouse_id,
        variant_id,
        movement_type,
        quantity,
        reference_type,
        reference_id
    )
    VALUES (
        p_from_warehouse_id,
        p_variant_id,
        'TRANSFER_OUT',
        p_quantity,
        'WAREHOUSE_TRANSFER',
        v_transfer_id
    );

    -- Record transfer in

    INSERT INTO stock_movement (
        warehouse_id,
        variant_id,
        movement_type,
        quantity,
        reference_type,
        reference_id
    )
    VALUES (
        p_to_warehouse_id,
        p_variant_id,
        'TRANSFER_IN',
        p_quantity,
        'WAREHOUSE_TRANSFER',
        v_transfer_id
    );

    COMMIT;
END //

DELIMITER ;


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
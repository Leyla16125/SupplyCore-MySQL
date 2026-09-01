DELIMITER //

CREATE PROCEDURE confirm_sales_order (
    IN p_sales_order_id INT
)
BEGIN
    DECLARE v_order_status VARCHAR(30);
    DECLARE v_warehouse_id INT;
    DECLARE v_insufficient_stock INT DEFAULT 0;

    START TRANSACTION;

    -- Lock the order while it is being processed
    SELECT status, warehouse_id
    INTO v_order_status, v_warehouse_id
    FROM sales_order
    WHERE sales_order_id = p_sales_order_id
    FOR UPDATE;

    -- Only draft orders can be confirmed
    IF v_order_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Order not found';
    END IF;

    IF v_order_status <> 'DRAFT' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Only draft orders can be confirmed';
    END IF;

    IF v_warehouse_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Warehouse is not assigned to the order';
    END IF;

    -- Check stock for every item in the order
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
            SET MESSAGE_TEXT = 'Insufficient stock';
    END IF;

    -- Reduce warehouse stock
    UPDATE inventory AS i
    JOIN sales_order_item AS soi
        ON soi.variant_id = i.variant_id
    SET i.quantity = i.quantity - soi.quantity
    WHERE soi.sales_order_id = p_sales_order_id
      AND i.warehouse_id = v_warehouse_id;

    -- Keep stock history
    INSERT INTO stock_movement (
        warehouse_id,
        variant_id,
        movement_type,
        quantity
    )
    SELECT
        v_warehouse_id,
        soi.variant_id,
        'SALE',
        soi.quantity
    FROM sales_order_item AS soi
    WHERE soi.sales_order_id = p_sales_order_id;

    UPDATE sales_order
    SET status = 'CONFIRMED'
    WHERE sales_order_id = p_sales_order_id;

    COMMIT;
END //

DELIMITER ;
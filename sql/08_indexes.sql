USE supplycore;

-- Sales reporting

CREATE INDEX idx_sales_order_status_confirmed
ON sales_order (status, confirmed_at);


-- Stock movement lookup

CREATE INDEX idx_stock_movement_reference
ON stock_movement (reference_type, reference_id);


-- Product movement history

CREATE INDEX idx_stock_movement_variant_date
ON stock_movement (variant_id, created_at);
USE supplycore;

-- Monthly sales revenue

SELECT
    DATE_FORMAT(so.confirmed_at, '%Y-%m') AS sales_month,
    COUNT(DISTINCT so.sales_order_id) AS order_count,
    SUM(soi.quantity) AS units_sold,
    SUM(soi.quantity * soi.unit_price) AS revenue
FROM sales_order AS so
JOIN sales_order_item AS soi
    ON soi.sales_order_id = so.sales_order_id
WHERE so.status = 'CONFIRMED'
GROUP BY DATE_FORMAT(so.confirmed_at, '%Y-%m')
ORDER BY sales_month;


-- Top-selling products

SELECT
    pm.name AS model_name,
    pv.storage,
    pv.color,
    pv.sku,
    SUM(soi.quantity) AS units_sold,
    SUM(soi.quantity * soi.unit_price) AS revenue
FROM sales_order_item AS soi
JOIN sales_order AS so
    ON so.sales_order_id = soi.sales_order_id
JOIN product_variant AS pv
    ON pv.variant_id = soi.variant_id
JOIN product_model AS pm
    ON pm.model_id = pv.model_id
WHERE so.status = 'CONFIRMED'
GROUP BY
    pm.name,
    pv.storage,
    pv.color,
    pv.sku
ORDER BY units_sold DESC;


-- Sales by brand

SELECT
    b.name AS brand_name,
    SUM(soi.quantity) AS units_sold,
    SUM(soi.quantity * soi.unit_price) AS revenue
FROM sales_order_item AS soi
JOIN sales_order AS so
    ON so.sales_order_id = soi.sales_order_id
JOIN product_variant AS pv
    ON pv.variant_id = soi.variant_id
JOIN product_model AS pm
    ON pm.model_id = pv.model_id
JOIN family AS f
    ON f.family_id = pm.family_id
JOIN brand AS b
    ON b.brand_id = f.brand_id
WHERE so.status = 'CONFIRMED'
GROUP BY
    b.brand_id,
    b.name
ORDER BY revenue DESC;


-- Average order value

SELECT
    ROUND(AVG(total_amount), 2) AS average_order_value
FROM sales_order_summary
WHERE status = 'CONFIRMED';


-- Warehouse stock distribution

SELECT
    warehouse_name,
    city,
    SUM(quantity) AS total_stock
FROM inventory_overview
GROUP BY
    warehouse_name,
    city
ORDER BY total_stock DESC;


-- Monthly revenue growth

WITH monthly_sales AS (
    SELECT
        DATE_FORMAT(so.confirmed_at, '%Y-%m') AS sales_month,
        SUM(soi.quantity * soi.unit_price) AS revenue
    FROM sales_order AS so
    JOIN sales_order_item AS soi
        ON soi.sales_order_id = so.sales_order_id
    WHERE so.status = 'CONFIRMED'
    GROUP BY DATE_FORMAT(so.confirmed_at, '%Y-%m')
),
sales_growth AS (
    SELECT
        sales_month,
        revenue,
        LAG(revenue) OVER (
            ORDER BY sales_month
        ) AS previous_month_revenue
    FROM monthly_sales
)
SELECT
    sales_month,
    revenue,
    previous_month_revenue,
    ROUND(
        (revenue - previous_month_revenue)
        / NULLIF(previous_month_revenue, 0) * 100,
        2
    ) AS growth_percentage
FROM sales_growth
ORDER BY sales_month;
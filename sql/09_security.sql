USE supplycore;

-- Roles

CREATE ROLE IF NOT EXISTS
    'supplycore_admin',
    'supplycore_app',
    'supplycore_analyst';


-- Role privileges

GRANT ALL PRIVILEGES
ON supplycore.*
TO 'supplycore_admin';


GRANT SELECT
ON supplycore.*
TO 'supplycore_analyst';


GRANT SELECT
ON supplycore.*
TO 'supplycore_app';

GRANT INSERT, UPDATE
ON supplycore.customer
TO 'supplycore_app';

GRANT INSERT, UPDATE
ON supplycore.sales_order
TO 'supplycore_app';

GRANT INSERT, UPDATE
ON supplycore.sales_order_item
TO 'supplycore_app';

GRANT EXECUTE
ON PROCEDURE supplycore.confirm_sales_order
TO 'supplycore_app';

GRANT EXECUTE
ON PROCEDURE supplycore.receive_purchase_order
TO 'supplycore_app';

GRANT EXECUTE
ON PROCEDURE supplycore.transfer_stock
TO 'supplycore_app';

GRANT EXECUTE
ON PROCEDURE supplycore.return_sales_item
TO 'supplycore_app';


-- Users

CREATE USER IF NOT EXISTS 'supplycore_admin_user'@'localhost'
IDENTIFIED BY 'Admin_2026!';

CREATE USER IF NOT EXISTS 'supplycore_app_user'@'localhost'
IDENTIFIED BY 'App_2026!';

CREATE USER IF NOT EXISTS 'supplycore_analyst_user'@'localhost'
IDENTIFIED BY 'Analyst_2026!';


-- Assign roles

GRANT 'supplycore_admin'
TO 'supplycore_admin_user'@'localhost';

GRANT 'supplycore_app'
TO 'supplycore_app_user'@'localhost';

GRANT 'supplycore_analyst'
TO 'supplycore_analyst_user'@'localhost';


-- Default roles

SET DEFAULT ROLE 'supplycore_admin'
TO 'supplycore_admin_user'@'localhost';

SET DEFAULT ROLE 'supplycore_app'
TO 'supplycore_app_user'@'localhost';

SET DEFAULT ROLE 'supplycore_analyst'
TO 'supplycore_analyst_user'@'localhost';
# SupplyCore MySQL

SupplyCore məhsulların, anbarların, stokun, təchizatçıların, satınalmaların, satışların, anbarlararası transferlərin və geri qaytarmaların idarə olunması üçün hazırlanmış MySQL verilənlər bazası layihəsidir.

Layihədə relational database dizaynı, data integrity, transaction-lar, business logic, reporting və query performance mövzularına fokuslanılıb.

## Əsas imkanlar

- Məhsullar üçün category, brand, family, model və variant strukturu
- Bir neçə anbar üzrə inventory idarəetməsi
- Təchizatçı və purchase order prosesi
- Müştəri və sales order idarəetməsi
- Transaction daxilində təhlükəsiz stok yenilənməsi
- Anbarlararası stok transferi
- Satış geri qaytarmaları
- Stock movement history
- Reporting üçün VIEW-lar
- Business analytics query-ləri
- Query performansı üçün index-lər
- Role-based database access

## Database strukturu

Verilənlər bazası əsasən aşağıdakı hissələrdən ibarətdir:

- Məhsullar
- Anbar və inventory
- Təchizatçılar və satınalma
- Müştərilər və satışlar
- Satış geri qaytarmaları
- Stock movement
- Anbarlararası transferlər

## ER Diagram

![SupplyCore ER Diagram](docs/supplycore_erd.png)

## SQL faylları

| Fayl | Təyinat |
|------|---------|
| `01_schema.sql` | Table-lar və əlaqələr |
| `02_seed_data.sql` | İlkin nümunə data |
| `03_business_rules.sql` | CHECK constraint-lər və business rules |
| `04_views.sql` | Reporting və inventory VIEW-ları |
| `05_procedures.sql` | Transactional business əməliyyatları |
| `07_analytics.sql` | Business analytics query-ləri |
| `08_indexes.sql` | Query performansı üçün index-lər |
| `09_security.sql` | User, role və privilege-lər |

## Stored Procedures

Layihədə əsas inventory prosesləri üçün aşağıdakı stored procedure-lər yaradılıb:

- `confirm_sales_order`
- `receive_purchase_order`
- `transfer_stock`
- `return_sales_item`

## Inventory Flow

Stok əsasən 4 əməliyyat nəticəsində dəyişir:

1. Purchase order qəbul edilir → inventory artır
2. Sales order təsdiqlənir → inventory azalır
3. Warehouse transfer edilir → stok bir anbardan digərinə keçir
4. Sales return tamamlanır → inventory artır

Bu əməliyyatlar `stock_movement` table-ında qeyd olunur.

## VIEW-lar

Layihədə məlumatların daha rahat oxunması və reporting üçün aşağıdakı VIEW-lar yaradılıb:

- `inventory_overview`
- `sales_order_summary`
- `low_stock_products`

## Analytics

`07_analytics.sql` faylında aşağıdakı business query-lər mövcuddur:

- Aylıq satış gəliri
- Ən çox satılan məhsullar
- Brand üzrə satış nəticələri
- Average Order Value
- Warehouse stock distribution
- Aylıq revenue growth

## Security

Database access role əsaslı qurulub:

- `supplycore_admin`
- `supplycore_app`
- `supplycore_analyst`

Hər role yalnız lazım olan privilege-lərlə məhdudlaşdırılıb.

## Setup

SQL fayllarını aşağıdakı ardıcıllıqla run etmək lazımdır:

1. `01_schema.sql`
2. `02_seed_data.sql`
3. `03_business_rules.sql`
4. `04_views.sql`
5. `05_procedures.sql`
6. `08_indexes.sql`
7. `09_security.sql`

`07_analytics.sql` reporting query-lərindən ibarətdir və database qurulduqdan sonra ayrıca run edilə bilər.

## İstifadə olunan texnologiyalar

- MySQL 8
- MySQL Workbench
- SQL
- Git
- GitHub

## Project Status

Database implementation tamamlanıb. Final validation və documentation mərhələsi davam edir.
-- =====================================================================
-- 01_cek_tabel.sql  ·  Tahap 2.6 – Cek semua tabel setelah upload
-- Tujuan: memastikan 8 tabel ter-upload lengkap dan tipe datanya benar
-- =====================================================================


-- 1) Jumlah baris per tabel ------------------------------------------
-- Harus sama dengan jumlah baris file CSV:
-- customers 99.441 · orders 99.441 · order_items 112.650 · payments 103.886
-- reviews 99.224 · products 32.951 · sellers 3.095 · category_translation 71
SELECT 'customers' AS tabel, COUNT(*) AS jumlah_baris FROM `olist.customers`
UNION ALL SELECT 'orders',               COUNT(*) FROM `olist.orders`
UNION ALL SELECT 'order_items',          COUNT(*) FROM `olist.order_items`
UNION ALL SELECT 'payments',             COUNT(*) FROM `olist.payments`
UNION ALL SELECT 'reviews',              COUNT(*) FROM `olist.reviews`
UNION ALL SELECT 'products',             COUNT(*) FROM `olist.products`
UNION ALL SELECT 'sellers',              COUNT(*) FROM `olist.sellers`
UNION ALL SELECT 'category_translation', COUNT(*) FROM `olist.category_translation`
ORDER BY tabel;


-- 2) Tipe data setiap kolom --------------------------------------------
-- Kolom tanggal (order_purchase_timestamp, order_delivered_customer_date,
-- order_estimated_delivery_date, review_answer_timestamp) harus TIMESTAMP.
SELECT table_name, column_name, data_type
FROM `olist.INFORMATION_SCHEMA.COLUMNS`
ORDER BY table_name, ordinal_position;


-- 3) Contoh isi data ------------------------------------------------------
SELECT * FROM `olist.orders` LIMIT 10;
SELECT * FROM `olist.reviews` LIMIT 10;
SELECT * FROM `olist.category_translation` LIMIT 10;

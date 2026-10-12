-- =====================================================================
-- 02_order_detail.sql
-- Tabel detail: 1 baris = pesanan x seller x kategori
-- Dipakai untuk tabel "Kategori dengan telat tertinggi" dan
-- "Seller paling sering telat" di dashboard.
-- Sumber : olist.orders_clean, olist.order_items, olist.products,
--          olist.category_translation
-- =====================================================================

CREATE OR REPLACE TABLE `olist.order_detail` AS
SELECT DISTINCT
  oc.order_id,
  oi.seller_id,
  COALESCE(t.product_category_name_english,   -- nama kategori bahasa Inggris
           p.product_category_name,           -- jika belum ada terjemahan
           'unknown') AS category,            -- jika produk tanpa kategori
  oc.order_month,
  oc.customer_state,
  oc.late_flag,
  oc.review_score
FROM `olist.orders_clean` oc
JOIN `olist.order_items` oi USING (order_id)
LEFT JOIN `olist.products` p USING (product_id)
LEFT JOIN `olist.category_translation` t
  ON t.product_category_name = p.product_category_name
WHERE oc.late_flag IS NOT NULL;               -- hanya pesanan yang sudah terkirim

-- Catatan: satu pesanan bisa muncul di beberapa baris (beberapa seller/kategori).
-- Karena itu jumlah pesanan selalu dihitung dengan COUNT(DISTINCT order_id).

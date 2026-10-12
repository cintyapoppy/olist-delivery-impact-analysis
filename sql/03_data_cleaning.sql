-- =====================================================================
-- 03_data_cleaning.sql  ·  Tahap 4 – Data Cleaning & Preparation
-- Bagian A: tabel orders_clean (1 baris = 1 pesanan)
-- Bagian B: tabel order_detail (pesanan x seller x kategori)
-- Jalankan Bagian A dulu, baru Bagian B.
-- =====================================================================

-- ---------------------------------------------------------------------
-- BAGIAN A · orders_clean
-- Sumber: orders, customers, reviews · Hasil: 96.203 pesanan terkirim
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `olist.orders_clean` AS

-- 1) Ambil 1 review per pesanan (yang paling akhir dijawab),
--    karena sebagian pesanan punya lebih dari satu review
WITH review_terakhir AS (
  SELECT order_id, review_score
  FROM `olist.reviews`
  WHERE TRUE
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY order_id
    ORDER BY review_answer_timestamp DESC
  ) = 1
),

-- 2) Gabungkan pesanan + pelanggan + review, lalu saring periode & status
base AS (
  SELECT
    o.order_id,
    c.customer_unique_id,                 -- identitas pelanggan sebenarnya (untuk loyalitas)
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    DATE_TRUNC(DATE(o.order_purchase_timestamp), MONTH) AS order_month,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    r.review_score,
    (o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL) AS terkirim
  FROM `olist.orders` o
  JOIN `olist.customers` c USING (customer_id)
  LEFT JOIN review_terakhir r USING (order_id)
  WHERE o.order_status NOT IN ('canceled', 'unavailable')
    AND DATE(o.order_purchase_timestamp) BETWEEN '2017-01-01' AND '2018-08-31'
),

-- 3) Hitung waktu kirim & keterlambatan
kirim AS (
  SELECT
    *,
    IF(terkirim,
       ROUND(TIMESTAMP_DIFF(order_delivered_customer_date,
                            order_purchase_timestamp, HOUR) / 24, 1),
       NULL) AS delivery_days,
    -- terlambat = tiba setelah tanggal estimasi (perbandingan timestamp)
    IF(terkirim,
       order_delivered_customer_date > order_estimated_delivery_date,
       NULL) AS is_late,
    IF(terkirim,
       DATE_DIFF(DATE(order_delivered_customer_date),
                 DATE(order_estimated_delivery_date), DAY),
       NULL) AS late_days
  FROM base
)

-- 4) Kolom label untuk dashboard & kolom loyalitas
SELECT
  order_id,
  customer_unique_id,
  customer_state,
  order_status,
  order_purchase_timestamp,
  order_month,
  order_delivered_customer_date,
  order_estimated_delivery_date,
  review_score,
  terkirim,
  delivery_days,
  late_days,
  is_late,

  -- late_flag: 1 = terlambat, 0 = tepat waktu, NULL = belum/tidak terkirim
  CASE WHEN is_late IS NULL THEN NULL WHEN is_late THEN 1 ELSE 0 END AS late_flag,
  CASE WHEN is_late IS NULL THEN NULL WHEN is_late THEN 'Terlambat' ELSE 'Tepat waktu' END AS status_kirim,

  -- kelompok lama keterlambatan
  CASE
    WHEN is_late IS NULL THEN NULL
    WHEN NOT is_late     THEN 'Tepat'
    WHEN late_days <= 3  THEN '1–3'
    WHEN late_days <= 7  THEN '4–7'
    WHEN late_days <= 14 THEN '8–14'
    ELSE '>14'
  END AS telat_label,
  CASE
    WHEN is_late IS NULL THEN NULL
    WHEN NOT is_late     THEN 1
    WHEN late_days <= 3  THEN 2
    WHEN late_days <= 7  THEN 3
    WHEN late_days <= 14 THEN 4
    ELSE 5
  END AS telat_urut,

  -- kelompok lama pengiriman
  CASE
    WHEN delivery_days IS NULL THEN NULL
    WHEN delivery_days < 5  THEN '<5'
    WHEN delivery_days < 10 THEN '5–9'
    WHEN delivery_days < 15 THEN '10–14'
    WHEN delivery_days < 20 THEN '15–19'
    WHEN delivery_days < 30 THEN '20–29'
    ELSE '30+'
  END AS hari_label,
  CASE
    WHEN delivery_days IS NULL THEN NULL
    WHEN delivery_days < 5  THEN 1
    WHEN delivery_days < 10 THEN 2
    WHEN delivery_days < 15 THEN 3
    WHEN delivery_days < 20 THEN 4
    WHEN delivery_days < 30 THEN 5
    ELSE 6
  END AS hari_urut,

  -- kelompok bintang review
  CASE
    WHEN review_score IS NULL THEN NULL
    WHEN review_score <= 2 THEN 'Bintang 1–2'
    WHEN review_score = 3  THEN 'Bintang 3'
    ELSE 'Bintang 4–5'
  END AS bintang_label,
  CASE
    WHEN review_score IS NULL THEN NULL
    WHEN review_score <= 2 THEN 1
    WHEN review_score = 3  THEN 2
    ELSE 3
  END AS bintang_urut,

  -- loyalitas (berdasarkan customer_unique_id)
  ROW_NUMBER() OVER (PARTITION BY customer_unique_id
                     ORDER BY order_purchase_timestamp) AS urutan_order,
  COUNT(*) OVER (PARTITION BY customer_unique_id)        AS total_order_pelanggan,
  ROW_NUMBER() OVER (PARTITION BY customer_unique_id
                     ORDER BY order_purchase_timestamp) = 1 AS is_first_order,
  COUNT(*) OVER (PARTITION BY customer_unique_id) > 1    AS pelanggan_kembali
FROM kirim;


-- Cek cepat setelah tabel dibuat
SELECT
  COUNTIF(late_flag IS NOT NULL)               AS pesanan_terkirim,   -- 96.203
  ROUND(AVG(late_flag) * 100, 1)               AS pct_terlambat,      -- 8,1
  ROUND(AVG(delivery_days), 1)                 AS rata_hari_kirim,    -- 12,5
  ROUND(AVG(IF(late_flag IS NOT NULL, review_score, NULL)), 2) AS rata_review  -- 4,16
FROM `olist.orders_clean`;


-- ---------------------------------------------------------------------
-- BAGIAN B · order_detail
-- Dipakai untuk tabel "Kategori dengan telat tertinggi" dan
-- "Seller paling sering telat" di dashboard.
-- ---------------------------------------------------------------------

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

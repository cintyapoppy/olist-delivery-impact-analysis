-- =====================================================================
-- 04_analysis.sql  ·  Tahap 5 – Analisis dengan SQL
-- Query analisis untuk setiap pertanyaan bisnis.
-- Angka di komentar = angka yang tampil di dashboard Data Studio.
-- Jalankan satu per satu (blok query, lalu klik Run).
-- =====================================================================


-- Q1. KPI utama ------------------------------------------------------
SELECT
  COUNT(*)                          AS pesanan_terkirim,   -- 96.203
  ROUND(AVG(late_flag) * 100, 1)    AS pct_terlambat,      -- 8,1%
  ROUND(AVG(delivery_days), 1)      AS rata_hari_kirim,    -- 12,5 hari
  ROUND(AVG(review_score), 2)       AS rata_review         -- 4,16
FROM `olist.orders_clean`
WHERE late_flag IS NOT NULL;


-- Q2. Sebaran lama pengiriman ------------------------------------------
-- <5: 14% · 5–9: 34% · 10–14: 25% · 15–19: 13% · 20–29: 10% · 30+: 5%
SELECT
  hari_label,
  COUNT(*) AS pesanan,
  ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM `olist.orders_clean`
WHERE late_flag IS NOT NULL
GROUP BY hari_label, hari_urut
ORDER BY hari_urut;


-- Q3. Komposisi bintang: tepat waktu vs terlambat ------------------------
-- Tepat waktu: 9% / 8% / 83% (rata-rata 4,29)
-- Terlambat  : 54% / 11% / 35% (rata-rata 2,57)
SELECT
  status_kirim,
  bintang_label,
  COUNT(*) AS pesanan,
  ROUND(COUNT(*) * 100 / SUM(COUNT(*)) OVER (PARTITION BY status_kirim), 1) AS pct
FROM `olist.orders_clean`
WHERE late_flag IS NOT NULL AND review_score IS NOT NULL
GROUP BY status_kirim, bintang_label, bintang_urut
ORDER BY status_kirim, bintang_urut;

SELECT status_kirim, ROUND(AVG(review_score), 2) AS rata_review
FROM `olist.orders_clean`
WHERE late_flag IS NOT NULL
GROUP BY status_kirim;


-- Q4. Rata-rata review menurut lama keterlambatan -----------------------
-- Tepat 4,3 · 1–3 hari 3,6 · 4–7 hari 2,1 · 8–14 hari 1,7 · >14 hari 1,7
SELECT
  telat_label,
  COUNT(*) AS pesanan,
  ROUND(AVG(review_score), 1) AS rata_review
FROM `olist.orders_clean`
WHERE late_flag IS NOT NULL
GROUP BY telat_label, telat_urut
ORDER BY telat_urut;


-- Q5. % terlambat per state ---------------------------------------------
-- AL 24% · MA 20% · PI 16% · ... · SP 6% (pembanding)
SELECT
  customer_state,
  COUNT(*) AS pesanan,
  ROUND(AVG(late_flag) * 100, 1) AS pct_terlambat
FROM `olist.orders_clean`
WHERE late_flag IS NOT NULL
GROUP BY customer_state
ORDER BY pct_terlambat DESC;


-- Q6. Kategori dengan % telat tertinggi (minimal 1.000 pesanan) ----------
-- electronics 2.516 / 10% / 4,12 · baby 2.800 / 9% / 4,09 · office_furniture 1.248 / 9% / 3,65
SELECT
  category,
  COUNT(DISTINCT order_id)        AS pesanan,
  ROUND(AVG(late_flag) * 100, 1)  AS pct_terlambat,
  ROUND(AVG(review_score), 2)     AS rata_review
FROM `olist.order_detail`
WHERE category != 'unknown'
GROUP BY category
HAVING COUNT(DISTINCT order_id) >= 1000
ORDER BY pct_terlambat DESC
LIMIT 3;


-- Q7. Seller paling sering telat (minimal 200 pesanan) -------------------
-- 06a2c3… 389 / 23% · 88460e… 246 / 20% · e5a343… 216 / 19%
SELECT
  seller_id,
  COUNT(DISTINCT order_id)        AS pesanan,
  ROUND(AVG(late_flag) * 100, 1)  AS pct_terlambat
FROM `olist.order_detail`
GROUP BY seller_id
HAVING COUNT(DISTINCT order_id) >= 200
ORDER BY pct_terlambat DESC
LIMIT 3;


-- Q8. Tren % terlambat per bulan -----------------------------------------
-- Puncak: Nov 2017 14,3% · Feb 2018 16,0% · Mar 2018 21,4%
SELECT
  order_month,
  COUNT(*) AS pesanan,
  ROUND(AVG(late_flag) * 100, 1) AS pct_terlambat
FROM `olist.orders_clean`
WHERE late_flag IS NOT NULL
GROUP BY order_month
ORDER BY order_month;


-- Q9. Loyalitas: repeat rate berdasarkan pengalaman pesanan pertama -------
-- Pesanan pertama tepat waktu 3,07% · terlambat 2,54%
SELECT
  status_kirim AS pesanan_pertama,
  COUNT(*) AS pelanggan,
  ROUND(AVG(IF(pelanggan_kembali, 1, 0)) * 100, 2) AS repeat_rate_pct
FROM `olist.orders_clean`
WHERE is_first_order AND late_flag IS NOT NULL
GROUP BY status_kirim;

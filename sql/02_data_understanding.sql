-- =====================================================================
-- 02_data_understanding.sql  ·  Tahap 3 – Data Understanding
-- Tujuan: memahami isi data sebelum cleaning, dan menemukan alasan
-- untuk setiap aturan cleaning di Tahap 4.
-- =====================================================================


-- 1) Distribusi status pesanan -----------------------------------------
-- → Pesanan canceled & unavailable tidak pernah dikirim, jadi dibuang.
SELECT order_status, COUNT(*) AS pesanan
FROM `olist.orders`
GROUP BY order_status
ORDER BY pesanan DESC;


-- 2) Jumlah pesanan per bulan -----------------------------------------------
-- → Bulan di 2016 dan setelah Agustus 2018 datanya sangat sedikit,
--   sehingga periode analisis dibatasi Jan 2017 – Agu 2018.
SELECT
  DATE_TRUNC(DATE(order_purchase_timestamp), MONTH) AS bulan,
  COUNT(*) AS pesanan
FROM `olist.orders`
GROUP BY bulan
ORDER BY bulan;


-- 3) Nilai kosong pada kolom tanggal penting ---------------------------------
-- → Pesanan tanpa tanggal terima tidak bisa dihitung keterlambatannya.
SELECT
  COUNTIF(order_delivered_customer_date IS NULL) AS tanpa_tanggal_terima,
  COUNTIF(order_estimated_delivery_date IS NULL) AS tanpa_tanggal_estimasi,
  COUNTIF(order_status = 'delivered'
          AND order_delivered_customer_date IS NULL) AS delivered_tanpa_tanggal
FROM `olist.orders`;


-- 4) Pesanan dengan lebih dari satu review ------------------------------------
-- → Agar baris tidak dobel saat join, dipakai 1 review terbaru per pesanan.
SELECT COUNT(*) AS pesanan_dengan_review_ganda
FROM (
  SELECT order_id
  FROM `olist.reviews`
  GROUP BY order_id
  HAVING COUNT(*) > 1
);


-- 5) customer_id vs customer_unique_id ----------------------------------------
-- → customer_id selalu baru di setiap pesanan; identitas pelanggan
--   sebenarnya adalah customer_unique_id (dipakai untuk analisis loyalitas).
SELECT
  COUNT(DISTINCT customer_id)        AS jumlah_customer_id,
  COUNT(DISTINCT customer_unique_id) AS jumlah_pelanggan_unik
FROM `olist.customers`;


-- 6) Produk tanpa kategori / tanpa terjemahan ---------------------------------
-- → Produk tanpa kategori diberi label 'unknown' di tabel order_detail.
SELECT
  COUNTIF(p.product_category_name IS NULL) AS produk_tanpa_kategori,
  COUNTIF(p.product_category_name IS NOT NULL
          AND t.product_category_name_english IS NULL) AS kategori_tanpa_terjemahan
FROM `olist.products` p
LEFT JOIN `olist.category_translation` t USING (product_category_name);


-- 7) Definisi "terlambat": timestamp vs tanggal saja ---------------------------
-- Tanggal estimasi selalu pukul 00:00, jadi pesanan yang tiba di hari estimasi
-- ikut terhitung terlambat bila dibandingkan per timestamp.
-- → Dipakai perbandingan timestamp (≈ 8,1%); per tanggal saja ≈ 6,8%.
SELECT
  ROUND(AVG(IF(order_delivered_customer_date > order_estimated_delivery_date, 1, 0)) * 100, 1)
    AS pct_telat_timestamp,
  ROUND(AVG(IF(DATE(order_delivered_customer_date) > DATE(order_estimated_delivery_date), 1, 0)) * 100, 1)
    AS pct_telat_tanggal
FROM `olist.orders`
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL
  AND DATE(order_purchase_timestamp) BETWEEN '2017-01-01' AND '2018-08-31';

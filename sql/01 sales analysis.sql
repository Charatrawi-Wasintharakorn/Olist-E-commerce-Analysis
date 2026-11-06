/*
Topic: ยอดขาย - รายได้เติบโตหรือไม่ และหมวดสินค้าไหนเป็นตัวขับเคลื่อน
ขอบเขต: ออเดอร์ที่ delivered และมีวันที่ส่งถึงลูกค้า | รายได้ = SUM(price) ไม่รวมค่าส่ง
*/
USE olist;
GO
 
/* ===================== 1A: ยอดขายรายเดือน + MoM growth ===================== */
 
/*
คำถามธุรกิจ : ยอดขายรายเดือนเป็นอย่างไร และเติบโตเดือนต่อเดือนเท่าไร
ตารางที่ใช้   : orders, order_items
ตัวชี้วัด    : จำนวนออเดอร์, รายได้ (price ไม่รวมค่าส่ง), MoM growth %
หมายเหตุ     : เดือนแรกและเดือนสุดท้ายของข้อมูล Olist ไม่ครบเดือน ควรตัดออกตอนทำกราฟ
*/
WITH monthly AS (
    SELECT DATEFROMPARTS(YEAR(TRY_CAST(o.order_purchase_timestamp AS DATETIME)),
                         MONTH(TRY_CAST(o.order_purchase_timestamp AS DATETIME)), 1) AS month_start,
           COUNT(DISTINCT o.order_id) AS orders,
           SUM(oi.price)              AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(TRY_CAST(o.order_purchase_timestamp AS DATETIME)),
                           MONTH(TRY_CAST(o.order_purchase_timestamp AS DATETIME)), 1)
)
SELECT month_start,
       orders,
       CAST(revenue AS DECIMAL(14,2)) AS revenue,
       CAST(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month_start))
            / NULLIF(LAG(revenue) OVER (ORDER BY month_start), 0) AS DECIMAL(18,2)) AS mom_growth_pct
FROM monthly
WHERE month_start IS NOT NULL
ORDER BY month_start;
GO
 
/* ===================== 1B: รายได้ตามหมวดสินค้า + Pareto ===================== */
 
/*
คำถามธุรกิจ : หมวดสินค้าไหนสร้างรายได้หลัก และรายได้กระจุกตัวที่ไม่กี่หมวดหรือไม่ (Pareto / 80-20)
ตารางที่ใช้   : order_items, orders, products, category_translation
ตัวชี้วัด    : รายได้, % ของรายได้รวม, % สะสม
หมายเหตุ     : หมวดที่ไม่มีคำแปลจัดเป็น 'unknown'
*/
WITH cat AS (
    SELECT COALESCE(t.product_category_name_english, 'unknown') AS category,
           SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN orders o   ON o.order_id = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    LEFT JOIN category_translation t
           ON t.product_category_name = p.product_category_name
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    GROUP BY COALESCE(t.product_category_name_english, 'unknown')
)
SELECT category,
       CAST(revenue AS DECIMAL(14,2)) AS revenue,
       CAST(100.0 * revenue / SUM(revenue) OVER () AS DECIMAL(5,2)) AS pct_of_total,
       CAST(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC
                                       ROWS UNBOUNDED PRECEDING)
            / SUM(revenue) OVER () AS DECIMAL(5,2)) AS cumulative_pct
FROM cat
ORDER BY revenue DESC;
GO
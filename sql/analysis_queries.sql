/*
====================================================================
PROJECT: E-Commerce Customer Analytics (Cohort, LTV & RFM Analysis)
DATABASE: PostgreSQL
DATASET: Online Retail II (2010–2011)
AUTHOR: qrstxlx
====================================================================
*/

-- =================================================================
-- 1. SCHEMA AND RAW DATA LOADING
-- =================================================================

DROP TABLE IF EXISTS online_retail_raw;

CREATE TABLE online_retail_raw (
    invoice TEXT,
    stock_code TEXT,
    description TEXT,
    quantity INT,
    invoice_date TEXT,
    price NUMERIC(10, 2),
    customer_id TEXT,
    country TEXT
);

-- Импорт данных из CSV
COPY online_retail_raw (
    invoice,
    stock_code,
    description,
    quantity,
    invoice_date,
    price,
    customer_id,
    country
)
FROM 'C:/Users/Public/online_retail_II-Year 2010-2011.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    ENCODING 'WIN1252'
);


-- =================================================================
-- 2. DATA CLEANING & DATA MART CREATION
-- =================================================================
-- Filtering:
-- - Exclude receipts without a customer ID (customer_id IS NOT NULL)
-- - Exclude returns and cancellations (invoice NOT LIKE 'C%', quantity > 0)
-- - Price correction (price > 0)
-- - Convert text date to TIMESTAMP type

DROP TABLE IF EXISTS online_retail_clean;

CREATE TABLE online_retail_clean AS
SELECT 
    invoice,
    stock_code,
    description,
    quantity,
    TO_TIMESTAMP(invoice_date, 'MM/DD/YYYY HH24:MI') AS invoice_date,
    price,
    ROUND((quantity * price), 2) AS total_amount,
    customer_id,
    country
FROM online_retail_raw
WHERE customer_id IS NOT NULL
  AND quantity > 0
  AND price > 0
  AND invoice NOT LIKE 'C%';

-- Validation of the volume of cleaned data
SELECT 
    COUNT(*) AS clean_rows,
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(DISTINCT invoice) AS total_invoices,
    ROUND(SUM(total_amount), 2) AS total_revenue,
    MIN(invoice_date) AS min_date,
    MAX(invoice_date) AS max_date
FROM online_retail_clean;


-- =================================================================
-- 3. COHORT RETENTION ANALYSIS (MONTHLY RETENTION RATE)
-- =================================================================

WITH customer_cohort AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(invoice_date))::date AS cohort_month
    FROM online_retail_clean
    GROUP BY customer_id
),
cohort_sizes AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_users
    FROM customer_cohort
    GROUP BY cohort_month
),
customer_activities AS (
    SELECT 
        c.cohort_month,
        (
            (EXTRACT(year FROM o.invoice_date) - EXTRACT(year FROM c.cohort_month)) * 12 +
            (EXTRACT(month FROM o.invoice_date) - EXTRACT(month FROM c.cohort_month))
        ) AS cohort_index,
        o.customer_id
    FROM online_retail_clean o
    JOIN customer_cohort c ON o.customer_id = c.customer_id
),
retention_summary AS (
    SELECT 
        a.cohort_month,
        s.cohort_users,
        a.cohort_index,
        ROUND((COUNT(DISTINCT a.customer_id)::numeric / s.cohort_users) * 100, 1) AS retention_pct
    FROM customer_activities a
    JOIN cohort_sizes s ON a.cohort_month = s.cohort_month
    GROUP BY a.cohort_month, s.cohort_users, a.cohort_index
)
-- Pivot Matrix
SELECT 
    cohort_month,
    cohort_users,
    MAX(CASE WHEN cohort_index = 0 THEN retention_pct END) AS "m0",
    MAX(CASE WHEN cohort_index = 1 THEN retention_pct END) AS "m1",
    MAX(CASE WHEN cohort_index = 2 THEN retention_pct END) AS "m2",
    MAX(CASE WHEN cohort_index = 3 THEN retention_pct END) AS "m3",
    MAX(CASE WHEN cohort_index = 4 THEN retention_pct END) AS "m4",
    MAX(CASE WHEN cohort_index = 5 THEN retention_pct END) AS "m5",
    MAX(CASE WHEN cohort_index = 6 THEN retention_pct END) AS "m6",
    MAX(CASE WHEN cohort_index = 7 THEN retention_pct END) AS "m7",
    MAX(CASE WHEN cohort_index = 8 THEN retention_pct END) AS "m8",
    MAX(CASE WHEN cohort_index = 9 THEN retention_pct END) AS "m9",
    MAX(CASE WHEN cohort_index = 10 THEN retention_pct END) AS "m10",
    MAX(CASE WHEN cohort_index = 11 THEN retention_pct END) AS "m11",
    MAX(CASE WHEN cohort_index = 12 THEN retention_pct END) AS "m12"
FROM retention_summary
GROUP BY cohort_month, cohort_users
ORDER BY cohort_month;


-- =================================================================
-- 4. CALCULATION OF CUMULATIVE LTV (CUMULATIVE LTV PER CUSTOMER)
-- =================================================================

WITH customer_cohort AS (
    SELECT 
        customer_id,
        DATE_TRUNC('month', MIN(invoice_date))::date AS cohort_month
    FROM online_retail_clean
    GROUP BY customer_id
),
cohort_sizes AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_users
    FROM customer_cohort
    GROUP BY cohort_month
),
monthly_cohort_rev AS (
    SELECT 
        c.cohort_month,
        s.cohort_users,
        (
            (EXTRACT(year FROM o.invoice_date) - EXTRACT(year FROM c.cohort_month)) * 12 +
            (EXTRACT(month FROM o.invoice_date) - EXTRACT(month FROM c.cohort_month))
        ) AS cohort_index,
        SUM(o.total_amount) AS month_revenue
    FROM online_retail_clean o
    JOIN customer_cohort c ON o.customer_id = c.customer_id
    JOIN cohort_sizes s ON c.cohort_month = s.cohort_month
    GROUP BY c.cohort_month, s.cohort_users, cohort_index
)
SELECT 
    cohort_month,
    cohort_users,
    cohort_index,
    ROUND(month_revenue, 2) AS month_revenue,
    ROUND(SUM(month_revenue) OVER (PARTITION BY cohort_month ORDER BY cohort_index), 2) AS cumulative_revenue,
    ROUND(
        (SUM(month_revenue) OVER (PARTITION BY cohort_month ORDER BY cohort_index) / cohort_users), 
        2
    ) AS cumulative_ltv
FROM monthly_cohort_rev
ORDER BY cohort_month, cohort_index;


-- =================================================================
-- 5. RFM SEGMENTATION OF THE CUSTOMER BASE
-- =================================================================

WITH max_date_cte AS (
    SELECT MAX(invoice_date) + INTERVAL '1 day' AS reference_date
    FROM online_retail_clean
),
rfm_raw AS (
    SELECT 
        o.customer_id,
        EXTRACT(day FROM (m.reference_date - MAX(o.invoice_date)))::int AS recency_days,
        COUNT(DISTINCT o.invoice) AS frequency,
        ROUND(SUM(o.total_amount), 2) AS monetary
    FROM online_retail_clean o
    CROSS JOIN max_date_cte m
    GROUP BY o.customer_id, m.reference_date
),
rfm_scores AS (
    SELECT 
        customer_id,
        recency_days,
        frequency,
        monetary,
        NTILE(4) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(4) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(4) OVER (ORDER BY monetary ASC) AS m_score
    FROM rfm_raw
),
rfm_segments AS (
    SELECT 
        customer_id,
        recency_days,
        frequency,
        monetary,
        r_score,
        f_score,
        m_score,
        (r_score::text || f_score::text || m_score::text) AS rfm_cell,
        CASE 
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Champions / VIP'
            WHEN r_score >= 3 AND f_score >= 2 THEN 'Loyal Customers'
            WHEN r_score >= 3 AND f_score = 1 THEN 'Recent New Customers'
            WHEN r_score = 2 AND f_score >= 2 THEN 'Potential Loyalists'
            WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk (High Value)'
            WHEN r_score = 1 AND f_score <= 2 THEN 'Hibernating / Lost'
            ELSE 'Promising / Needs Attention'
        END AS customer_segment
    FROM rfm_scores
)
SELECT 
    customer_segment,
    COUNT(*) AS total_customers,
    ROUND((COUNT(*)::numeric / SUM(COUNT(*)) OVER ()) * 100, 2) AS pct_of_customers,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency), 1) AS avg_frequency,
    ROUND(AVG(monetary), 2) AS avg_monetary,
    ROUND(SUM(monetary), 2) AS total_segment_revenue
FROM rfm_segments
GROUP BY customer_segment
ORDER BY total_segment_revenue DESC;
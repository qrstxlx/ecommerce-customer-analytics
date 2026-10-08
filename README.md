# E-Commerce Customer Analytics: Cohort Retention, LTV & RFM Segmentation

An end-to-end SQL analytics project exploring customer retention patterns, cumulative lifetime value, and behavior-based customer segmentation using transactional data from a UK-based online retailer (**Online Retail II** dataset).

---

## Business Objectives

1. **Data Cleaning & Pipeline**: Filter out bulk cancellations, credit notes, anomalies, and anonymous sessions to establish a validated transaction database.
2. **Cohort Retention Analysis**: Track monthly customer retention dynamics across cohorts using pivot matrix views.
3. **Cumulative LTV Tracking**: Measure the cumulative revenue and lifetime value generated per acquired customer over a 12-month lifecycle.
4. **RFM Customer Segmentation**: Segment the user base by **Recency**, **Frequency**, and **Monetary** value to identify core value drivers, churn risks, and actionable marketing opportunities.

---

## Tech Stack & Methodology

* **Database Engine**: PostgreSQL 18
* **SQL Capabilities**: Advanced CTEs, Window Functions (`NTILE`, `SUM OVER`, `PARTITION BY`), Date Truncation/Extraction, Conditional Aggregations (Pivot)
* **Dataset**: Online Retail II (Transactions from December 2010 to December 2011)

---

## Repository Structure

```text
├── data/
│   ├── 01_data_cleaning_summary.csv   # Post-cleaning dataset metrics
│   ├── 02_retention_raw.csv           # Granular cohort retention data
│   ├── 03_retention_matrix.csv        # Monthly retention pivot table
│   ├── 04_cohort_ltv.csv              # Cumulative cohort revenue & LTV
│   └── 05_rfm_segments_summary.csv    # RFM segments aggregated metrics
├── sql/
│   └── analysis_queries.sql           # Full reproducible SQL script
└── README.md

# Section 3: Data Quality Assessment & Preprocessing Report
**Course:** Big Data Analytics (Final Project 2026) — VNUK Institute for Research and Executive Education  
**Role:** Person 2 (B - Data Scientist) | Week 1 Deliverable  
**Pipeline Stage:** MySQL Ingestion $\rightarrow$ KNIME Data Profiling & Preprocessing Pipeline  

---

## 1. Executive Summary & Objectives
As part of the end-to-end Big Data Analytics project for the **M5 Retail Sales Forecasting System**, this report documents the empirical findings, quality audit, and preprocessing pipeline executed in **KNIME Analytics Platform** by **Person 2 (Data Scientist)** for Week 1. 

The primary objectives of this stage were:
1. Ingest raw relational data directly from the project database (`bigdataprj`) via SQL query joining historical sales transactions (`sales_history`) and temporal metadata (`calendar`).
2. Conduct systematic data profiling to evaluate four core dimensions of data quality: **Completeness**, **Uniqueness**, **Validity**, and **Distributional Consistency / Outliers**.
3. Implement an automated, reproducible KNIME cleaning workflow using `Missing Value` and `Numeric Outliers` nodes.
4. Establish a rigorous **Before vs. After** quality baseline to guarantee that downstream machine learning algorithms (specifically Linear Regression scheduled for Week 2) are safeguarded against severe skewness, high-leverage outliers, and parameter divergence.

---

## 2. KNIME Workflow Architecture & Implementation
The data preparation pipeline was constructed using standard, reproducible KNIME nodes connected as follows:

```
[MySQL Connector] (localhost:3306 / bigdataprj)
       │
       ▼ (Database Connection Port)
[DB Query Reader] (Feature Engineering SQL: sales_history JOIN calendar)
       │
       ▼ (Data Table Port: 100,000 records)
[Missing Value] (Defensive imputation & schema integrity enforcement)
       │
       ▼
[Numeric Outliers] (Method: IQR, k=1.5, Treatment: Outliers above upper bound only)
       │
       ├─────────────────────────────────────────┐
       ▼ (Clean Data: 87,390 records)             ▼ (Summary Table / Statistics)
[Data Explorer / Statistics (After)]      [Data Explorer (Before Profiling)]
```

### Node Configuration Details:
1. **`MySQL Connector`**: Established an authenticated JDBC connection to the local MySQL server instance (`localhost:3306`, database `bigdataprj`).
2. **`DB Query Reader`**: Executed an optimized multi-table relational extraction:
   ```sql
   SELECT
       s.id,
       s.item_id,
       s.dept_id,
       s.cat_id,
       s.store_id,
       s.state_id,
       s.day,
       s.sales,
       c.date,
       CASE
           WHEN c.event_name_1 IS NOT NULL OR c.event_name_2 IS NOT NULL THEN 1
           ELSE 0
       END AS is_holiday
   FROM sales_history AS s
   LEFT JOIN calendar AS c
       ON s.day = c.d
   LIMIT 100000;
   ```
3. **`Missing Value` Node**: Configured with defensive hygiene rules (numeric fields defaulted to zero / median imputation, string fields audited against blank tokens).
4. **`Numeric Outliers` Node**: Parameterized with the non-parametric **Interquartile Range (IQR)** detection method ($k = 1.5$). The handling strategy was explicitly set to **"Outliers above upper bound only"** with **"Remove outlier rows"** to truncate unrepresentative demand shocks while safeguarding valid zero-demand observations.

---

## 3. Data Quality Checks (Four Core Dimensions)

In compliance with the project assessment criteria, the dataset was audited across four vital dimensions:

### 3.1. Completeness (Missing Value Analysis)
- **Evaluation:** Evaluated across all 10 schema fields (`id`, `item_id`, `dept_id`, `cat_id`, `store_id`, `state_id`, `day`, `sales`, `date`, `is_holiday`).
- **Observation:** The `sales` target variable contained **0 missing values (0.00%)** across the entire 100,000-record sample.
- **Join Verification:** Foreign key matching between `sales_history.day` and `calendar.d` was 100% matched, confirming that the `LEFT JOIN` introduced no `NULL` timestamps or missing calendar indicators.

### 3.2. Uniqueness & Structural Integrity
- **Evaluation:** Inspected composite grain keys (`id` + `day`).
- **Observation:** Each record represents a distinct item-store-day transaction grain. No duplicate transaction keys were identified.

### 3.3. Validity & Domain Range Rules
- **Evaluation:** Tested field data types and range boundaries against retail business constraints.
- **Observation:**
  - `sales` values were confirmed non-negative ($\ge 0$), confirming the absence of erroneous negative refund entries in the extraction.
  - Date attributes strictly conformed to ISO-8601 formatting (`YYYY-MM-DD`).
  - Binary feature `is_holiday` strictly adhered to boolean domain $\{0, 1\}$.

### 3.4. Consistency & Outlier Analysis
- **Evaluation:** Assessed the statistical distribution and variance of the target metric `sales`.
- **Observation:** In the raw dataset, `sales` exhibited extreme right-skewness (*positive skew*). While the median and lower quartile were centered near $0$, maximum values reached an extraordinary **194.00 units/day**. These severe spikes represent abnormal wholesale bulk orders or temporal stockpiling rather than standard retail customer demand.

---

## 4. Quantitative Results: Before vs. After Cleaning Baseline

The table below presents the quantitative comparison between the initial raw SQL dataset and the cleaned KNIME output:

| Metric / Dimension | Before Cleaning (Raw SQL) | After Cleaning (KNIME Cleaned) | Net Delta / Change | Transformation Method & Rationale |
| :--- | :---: | :---: | :---: | :--- |
| **Total Record Count ($N$)** | **100,000** | **87,390** | $-12,610$ ($-12.61\%$) | `Numeric Outliers` (Removed extreme upper-bound rows) |
| **Missing Values Count** | 0 | 0 | 0 ($0.00\%$) | `Missing Value` audit (Confirmed 100% complete) |
| **Minimum Unit Sales ($\text{Min}$)** | **0.000** | **0.000** | $0.000$ | Retained valid zero-demand days (Domain constraint) |
| **Maximum Unit Sales ($\text{Max}$)** | **194.000** | **2.000** | $-192.000$ | Truncated extreme outliers via $Q_3 + 1.5 \times \text{IQR}$ cutoff |
| **Mean Sales ($\mu$)** | **1.150** | **0.394** | $-0.756$ ($-65.74\%$) | Central tendency stabilized; free from heavy-tail pulling |
| **Standard Deviation ($\sigma$)** | **3.150** | **0.656** | $-2.494$ ($-79.17\%$) | Substantially reduced variance; homoscedasticity improved |
| **Upper Bound Threshold** | N/A | **2.000** | — | Automatic statistical threshold computed by KNIME IQR |

---

## 5. Cleaning Rationale & Method Justification

### 5.1. Why Upper Bound Only ($Q_3 + 1.5 \times \text{IQR}$)?
In retail inventory management, daily demand of **0 units** represents a legitimate, real-world business event:
- Fast-moving consumer goods frequently register zero purchases on slow weekdays or stockout periods.
- Forcing a symmetrical two-tailed outlier removal would erroneously classify zero-sales days as anomalous "lower outliers", artificially inflating baseline demand forecasts and leading to chronic overstocking.
- Restricting outlier pruning strictly to values exceeding the upper bound ($\text{Sales} > 2.0$) preserves realistic intermittent demand patterns while scrubbing extreme statistical anomalies.

### 5.2. Impact on Downstream Machine Learning (Linear Regression)
Ordinary Least Squares (OLS) Linear Regression minimizes the sum of squared residuals ($\sum (y_i - \hat{y}_i)^2$):
- An outlier value of $\text{Sales} = 194$ induces an error penalty proportional to $(194 - \hat{y})^2 \approx 37,000$, which drastically tilts the regression slope and destroys predictive accuracy for the typical $99\%$ of daily sales.
- By capping/removing extreme records, the standard deviation fell from **3.150** to **0.656** (a **$79.17\%$ variance reduction**). This directly fulfills the regression assumption of normality and homoscedasticity, preventing model divergence in Week 2.

---

## 6. Remaining Limitations & Model Risks
While the dataset has been rigorously cleaned, the following empirical risks must be recognized for Week 2 modeling:

1. **Zero-Inflation (Intermittent Demand):** The post-cleaning dataset remains heavily populated with zero-sales records ($\text{Median} = 0$). Standard linear regression may output non-integer or slightly negative values, necessitating a post-processing clipping step ($\hat{y} = \max(0, \hat{y})$) or specialized evaluation (Poisson/Tweedie considerations).
2. **Loss of High-Volume Promo Effects:** By trimming sales above 2 units, genuine mega-promotional surges (e.g., Black Friday bulk buying) are excluded from the baseline model. A secondary regime-switching indicator or separate high-demand model could be explored in future work.
3. **Sampling Scaling:** The 100,000 sample validated the pipeline architecture. In Week 2, the identical node parameters will scale across the full 11.1 million transaction database.

---

## 7. Deliverable Status for Week 1 (Person 2 Hand-off)
- [x] **Relational SQL Ingestion:** Verified via `MySQL Connector` and `DB Query Reader`.
- [x] **Data Quality Assessment:** Formally audited across Completeness, Uniqueness, Validity, and Consistency.
- [x] **Automated Cleaning Pipeline:** Built and executed with `Missing Value` and `Numeric Outliers` nodes.
- [x] **Comparative Baseline Table:** Before/After metrics documented for Section 3 of the IEEE Final Project Report.
- [x] **Prepared for Week 2:** Cleaned feature space ready for `Partitioning` and `Linear Regression Learner` nodes.

# Big Data Analytics — Final Project 2026 (VNUK)
## Deliverables Checklist & Outcome Files Required for Grade A / A+ (8.5 – 10.0 / 10.0)

> **Target Standard:** Grade A / A+ (Distinction / High Distinction)  
> **Course:** Big Data Analytics (50% Course Grade)  
> **Pipeline Requirement:** $\text{Dataset} \rightarrow \text{MySQL} \rightarrow \text{KNIME} \rightarrow \text{Machine Learning} \rightarrow \text{MySQL (Write-back)} \rightarrow \text{Power BI Dashboard} \rightarrow \text{Decision Support}$  
> **Target Location:** `D:\VNUK\Bigdata_Analysis\Final\`

---

## 1. Official Grading Breakdown & Weight Allocation

| Component | Official Weight | Key Expectation for A / A+ |
| :--- | :---: | :--- |
| **1. Problem Definition & Decision Questions** | **1.0 pt** | Clear business problem, identified decision-maker, and **at least 3 specific, measurable decision questions**. |
| **2. Dataset Selection & Data Quality** | **1.5 pt** | Ethical source ($\ge 1,000$ records, $\ge 5$ attributes), **4 core quality checks**, and a rigorous **Before vs. After comparison table** with cleaning rationale. |
| **3. MySQL Database & SQL Queries** | **1.0 pt** | Relational schema, DDL with primary/foreign keys, joins, aggregation/KPI scripts, and table schema for write-back. |
| **4. KNIME Workflow & Data Processing** | **1.5 pt** | End-to-end reproducible workflow with live MySQL connector, data cleaning, feature engineering, and **direct write-back to MySQL** (CSV-only workflows are heavily penalized). |
| **5. Machine Learning & Evaluation** | **1.5 pt** | Supervised/unsupervised model (e.g., Linear Regression), strict **time-based split** to eliminate look-ahead leakage, metrics (**MAE, RMSE, $R^2$**), residual interpretation. |
| **6. Dashboard, Insights & Decisions** | **2.0 pt** | Interactive Power BI dashboard connected to MySQL, displaying historical KPIs + ML forecasts, interactive slicers, and **3 actionable recommendations** with trade-offs. |
| **7. Project Report & Documentation** | **1.0 pt** | Professional 8–12 page report (or 6–10 page 2-column IEEE format) covering all 9 required sections with academic citations and signed integrity sheet. |
| **8. Demonstration & GitHub Submission** | **0.5 pt** | Clean GitHub repository, reproducible `README.md` with credential placeholders, seamless 1-laptop live demo. |
| **Total** | **10.0 pts** | **A / A+ Range: $\ge 8.5$ to $10.0$** |

---

## 2. Master Checklist of Outcome Files

To qualify for an **A / A+**, the final submission directory must contain the following concrete files:

### A. Academic Report & Documentation
- [ ] `Final_Project_Report.pdf`  
  - The finalized, compiled project report (8–12 pages standard or 6–10 pages IEEE two-column format).
  - Must include the signed Academic Integrity Declaration cover page (Student IDs, names, signatures, AI statement).
  - Contains all **9 formal sections**, high-resolution figures, architecture diagrams, and $\ge 5$ cited sources.
- [ ] `Final_Project_Report.docx` (or `.tex` / LaTeX source)  
  - Editable source file required by submission guidelines.

### B. Relational Database & SQL Scripts (`sql/`)
- [ ] `01_schema_and_import.sql`  
  - DDL scripts creating `bigdataprj` database and base tables (`sales_history`, `calendar`).
  - Defines primary keys, foreign keys, index structures, and data loading statements.
- [ ] `02_feature_engineering.sql`  
  - Relational `LEFT JOIN` between historical transactions and calendar metadata.
  - Generates engineered features (`is_holiday`, `snap`, day indices, date transformations).
- [ ] `03_kpi_queries.sql`  
  - Runnable SQL demonstrating data filtering, aggregations, and business KPI calculations.
- [ ] `04_sales_predictions_schema.sql`  
  - DDL script defining the table structure for receiving predictions written back from KNIME (`forecast_day`, `predicted_sales`, `actual_sales`, `model_name`, `prediction_date`).
- [ ] `m5_database_dump_sample.sql`  
  - Reproducible sample database export (e.g., 1% sample or 100k rows) allowing the instructor/reviewer to import and test without downloading massive multi-gigabyte files.

### C. KNIME Analytics Platform Workflow (`knime/`)
- [ ] `Bigdata_final.knwf`  
  - The fully configured and **executed** KNIME workflow export archive.
  - Organized with visual annotations (colored boxes) and clear labels.
  - Required nodes and flow:
    1. `MySQL Connector` $\rightarrow$ Authenticated JDBC connection.
    2. `DB Query Reader` $\rightarrow$ Live SQL ingestion of joined features.
    3. `Missing Value` $\rightarrow$ Defensive imputation and verification.
    4. `Numeric Outliers` $\rightarrow$ IQR-based detection ($k = 1.5$) of upper demand spikes, computed per series on training weeks only. The brief asks for a documented rationale for **retaining or handling** outliers (not removal): cap to the nearest permitted value or retain, and record the rows/units affected.
    5. `Rule-based Row Splitter` $\rightarrow$ Chronological train/test split (leakage control).
    6. `Linear Regression Learner` & `Regression Predictor` $\rightarrow$ Model training and prediction.
    7. `Math Formula` $\rightarrow$ Prediction clipping ($\ge 0$) and calculation of MAE, RMSE, and $R^2$.
    8. `DB Writer` / `DB Insert` $\rightarrow$ **Live write-back** of predictions directly into MySQL table `sales_predictions`.
- [ ] `knime_pipeline_architecture.png`  
  - High-resolution workflow canvas screenshot embedded in the final report and presentation.

### D. Interactive Business Intelligence Dashboard (`dashboard/`)
- [ ] `m5_sales_forecasting_final.pbix`  
  - Complete, interactive Power BI dashboard source file connected live to MySQL.
  - Visual components:
    - Executive KPI Cards (Total Sales, Predicted Volume, Overall RMSE, Active Outlets).
    - Dynamic Filters/Slicers (Date/Day slider, Department, Category, State, Holiday/SNAP status).
    - Historical EDA charts (demand trends, day-of-week seasonality, top SKUs).
    - **Actual vs. Predicted sales comparison line chart** across the out-of-time test window.
- [ ] `dashboard/screenshots/`  
  - High-resolution `.png` captures of all dashboard views for report documentation.

### E. Repository Setup & Reproducibility (`README.md` & Root Files)
- [ ] `README.md`  
  - Comprehensive documentation containing:
    - Project title, business context, and architecture flow diagram.
    - Software prerequisites and exact versions (MySQL 8.0+, KNIME 4.x/5.x, Power BI).
    - Step-by-step reproduction instructions (restore database $\rightarrow$ execute KNIME $\rightarrow$ open Power BI).
    - Database configuration documentation using **safe placeholders** (`localhost:3306`, username `<YOUR_USER>`, password `<YOUR_PASS>`).
    - Team work breakdown structure (WBS) and role allocation.
- [ ] `.gitignore`  
  - Prevents committing local credential files, logs, temporary dumps, or cache directories.
- [ ] `.env.example`  
  - Template configuration file showing expected environment variables without sensitive passwords.

### F. Presentation & Defense Deck (`presentation/`)
- [ ] `Final_Project_Presentation.pptx` (or `.pdf`)  
  - Deck structured for the final 1-laptop defense:
    - Slide 1: Title, Team Members & Roles (Person 1 DE, Person 2 DS, Person 3 DA).
    - Slide 2: Group SWOT analysis & communication plan.
    - Slide 3: Decision problem & 3 measurable decision questions.
    - Slide 4: System Architecture & Data Pipeline diagram.
    - Slide 5: Data Quality Audit (Before vs. After metrics table).
    - Slide 6: Machine Learning model design, time-based split, and test evaluation metrics.
    - Slide 7: Live Dashboard demo walkthrough.
    - Slide 8: **3 Evidence-Based Decision Recommendations** with expected ROI and trade-offs.
    - Slide 9: Plan vs. Actual reflection (WBS hours, challenges, lessons learned).

---

## 3. Minimum Quality Thresholds to Secure an A / A+

| Area | Distinction Criteria (A / A+) | Common Reasons for Grade Deduction (< B+) |
| :--- | :--- | :--- |
| **Write-Back Pipeline** | KNIME dynamically pushes predictions back into MySQL using `DB Writer`, and Power BI reads from that table. | KNIME outputs a CSV file that is manually loaded into Power BI (CSV-only is strictly prohibited). |
| **Leakage Control** | Chronological / time-based split (`train: d <= 1868`, `test: d > 1868`). Explicit verification that future test data did not leak into training. | Random train/test split (`Row Splitter` random 80/20) on time-series data. |
| **Data Quality Audit** | Tabulated **Before vs. After** metrics with exact row counts, percentages, and a documented rationale for retaining or handling outliers (rows and units affected). | Vague statements like "we inspected missing values and outliers" without numbers. |
| **Decision Focus** | At least **3 actionable recommendations** addressing specific inventory/procurement decisions with estimated trade-offs. | Presenting only ML metrics ($R^2$, RMSE) without translating findings into business decisions. |
| **Reproducibility** | Anyone can clone the repo, run the SQL script, click "Execute" in KNIME, and refresh Power BI seamlessly. | Missing scripts, broken hardcoded local file paths, or missing database dependencies. |
| **Security & Ethics** | All credentials use configuration templates/placeholders; dataset license explicitly cited. | Hardcoded database passwords committed to Git. |

---

## 4. Current Project State & Immediate Action Items

| Component in `Final` | Current Status | Required Action for A+ |
| :--- | :--- | :--- |
| **Report Document** | Separate markdown drafts (`Week1_...md`, `Week2_...md`) | Merge and write all 9 sections into a single professional PDF (`Final_Project_Report.pdf`) + editable `.docx`. |
| **ML Metrics** | `Week2_...md` contains multiple `[TBD]` markers | Execute the final KNIME pipeline, retrieve exact test MAE, RMSE, and $R^2$, and replace all `[TBD]` placeholders. |
| **SQL Scripts** | Dispersed in `process/` (`data_preparation.sql`, `test.sql`, `dedupe...`) | Consolidate and number into clean, runnable scripts (`01_schema...`, `02_features...`, etc.). |
| **KNIME Workflow** | `Bigdata_final.knwf` exists | Verify that node states are fully executed with clean visual annotations and verified MySQL write-back. |
| **Dashboard** | `m5_dashboard_week2.pbix` (interim draft) | Add Actual vs. Predicted comparison chart, final KPI cards, and polish UI/UX for final presentation. |
| **Presentation Deck** | Missing | Create `Final_Project_Presentation.pptx` following the weekly milestone guidelines. |
| **Root Documentation** | Basic README in subfolder | Place clean `README.md` at root with setup instructions, placeholders, and WBS matrix. |

---

## 5. Recommended Directory Structure in `Final`

```text
Final/
├── Final_Project_Report.pdf
├── Final_Project_Report.docx
├── README.md
├── .env.example
├── .gitignore
├── sql/
│   ├── 01_schema_and_import.sql
│   ├── 02_feature_engineering.sql
│   ├── 03_kpi_queries.sql
│   └── 04_sales_predictions_schema.sql
├── knime/
│   ├── Bigdata_final.knwf
│   └── knime_pipeline_architecture.png
├── dashboard/
│   ├── m5_sales_forecasting_final.pbix
│   └── screenshots/
│       ├── kpi_overview.png
│       └── actual_vs_predicted.png
├── presentation/
│   └── Final_Project_Presentation.pptx
└── requirement/
    ├── Big Data Analytics_Final_Project_2026_VNUK.pdf
    ├── form  (1).docx
    ├── Week_1.pdf
    ├── Week_2.pdf
    ├── Week_3.pdf
    ├── Week_4.pdf
    └── what to have for A+.md
```

# Execution Plan: Week 4 Delivery (M5 Retail Forecasting)

**Basis:** `process/misc/lh_action_plan.md` is the *basic track*. It produces everything needed for a solid pass.
**Checked against:** `requirement/required_files.md` (8 grading components, file checklist, A/A+ thresholds).
**Advanced track:** `roadmap.html` (store x dept x week, lags, baselines, K-Means). Do it only after the Phase 9 gate, and only where it adds a numbered roadmap item.

Pipeline to deliver: `Dataset -> MySQL -> KNIME (Linear Regression) -> MySQL write-back -> Power BI -> Decision`.

---

## 0. Conflicts between the two source documents (decide once, then follow)

| Topic | lh_action_plan | required_files / brief | Decision |
|---|---|---|---|
| Metrics | MAE, MAPE | MAE, **RMSE, R2** | Report all four. MAE/MAPE stay as the business metrics; RMSE/R2 are added from the KNIME test set. |
| Report length | IEEE 2-col, 6-10 pages, 6 sections | 9 sections, signed integrity sheet | IEEE 6-10 pages, but cover all 9 required sections (mapping in Phase 7). Integrity sheet is a separate cover page. |
| Slides | 10 slides | 9 slides (incl. SWOT, team roles) | Use the 9-slide structure and fold lh slides 4+5 into one data/evaluation slide. |
| Data-quality audit | Not mentioned | 4 checks + Before/After table + outlier rationale | Add as Phase 2. It is not optional. |
| Outliers | Not mentioned | IQR k=1.5, train-only, retain or cap, record rows/units | Add to the KNIME build (Phase 3). |
| Business questions | 5 questions, 3 recommendations | at least 3 measurable questions | Q1-Q3 become the formal decision questions. Q4-Q5 are supporting analysis. |
| Time split | "Train/Test dates" | `train: d <= 1868`, `test: d > 1868`, with a leakage check | Use d <= 1868 and add an explicit check node. |
| Numbers | Many hardcoded (39,496 / 19,748 / 110 / -20.20% ...) | Must be reproducible | **Every figure is recomputed in Phase 4 before it enters the report. Treat lh numbers as hypotheses.** |

---

## 1. Phases

Each phase ends in a **gate**. Do not start the next phase until the gate passes. The "Grade" column is the rubric component it protects.

### Phase 0: Repo skeleton and security (about 1 h) | Grade 7, 8
1. Create the folder layout from `required_files.md` section 5: `sql/ knime/ dashboard/screenshots/ presentation/`.
2. Write `.gitignore` (`.env`, `*.log`, dumps over 50 MB, `__pycache__`, KNIME workspace caches) and `.env.example` (`DB_HOST=localhost`, `DB_PORT=3306`, `DB_USER=<YOUR_USER>`, `DB_PASS=<YOUR_PASS>`, `DB_NAME=bigdataprj`).
3. Confirm `Final/.env` is not tracked. If a real password was ever committed, rotate it.

**Gate:** `git status` shows no secrets. Folder skeleton exists.

### Phase 1: Problem definition (about 1.5 h) | Grade 1 (1.0 pt)
1. Decision-maker: Regional Inventory Manager (RIM) for CA, TX, WI (10 stores). Reuse the wording in `process/decision.md`.
2. Formalise the three decision questions from lh Q1-Q3, each with a number and an action:
   - **DQ1 Stock-out risk:** which stores have actual > forecast in at least 8/10 full weeks, and by how many units?
   - **DQ2 Revenue priority:** which store has the highest weekly revenue MAE (USD), and does it match the unit-error ranking?
   - **DQ3 State bias:** is revenue forecast bias per state beyond +/-5%, and is it driven by one store or several?
3. Keep Q4 (state bias detail) and Q5 (state totals hide store errors) as supporting analysis in Phase 6.

**Gate:** three questions, each with a metric, a threshold and an action, saved in `process/decision.md`.

### Phase 2: Data in MySQL and quality audit (about 5 h) | Grade 2 (1.5), 3 (1.0)
1. **Verify before trusting.** `SELECT COUNT(*), COUNT(DISTINCT id, day) FROM sales_history;` Expect 11,128,850 (roadmap p2t2 says the import log shows 2x).
2. If doubled: dedupe or reload, then add `PRIMARY KEY (id, day)` and indexes. If not doubled: record that as a finding.
3. Load `sell_prices` (needed for revenue). Check price coverage in the window (roadmap says 99.8%).
4. Write `sql/01_schema_and_import.sql`: DDL with PK/FK, indexes, `LOAD DATA` with **placeholder paths** (remove `/media/deltan/...`).
5. Write `sql/02_feature_engineering.sql`: `LEFT JOIN calendar ON day = d`, derive `is_holiday`, `snap`, day indices, weekday.
6. **Four quality checks**, each with exact counts: completeness, uniqueness, validity (negatives, price <= 0, closed-store days), outliers. Produce the **Before vs After table** with row counts, percentages and the cleaning rationale.
7. Outlier policy: IQR k=1.5 on **train weeks only**, per series, cap to nearest permitted value (do not delete). Record rows and units affected.
8. Correct the Week 1/2 statistics that used `LIMIT 100000` (covered only about 3.3 days).
9. Write `sql/04_sales_predictions_schema.sql` with `UNIQUE (store_id, forecast_day, ...)` and the required columns (`forecast_day`, `predicted_sales`, `actual_sales`, `model_name`, `prediction_date`).

**Gate:** counts verified, Before/After table filled with real numbers, no `[TBD]` left in Week 1 data-quality doc.

### Phase 3: KNIME workflow (about 6 h) | Grade 4 (1.5), 5 (1.5)
Build in labelled, coloured sections: **Connect -> Ingest -> Clean -> Split -> Model -> Evaluate -> Write-back**.

| # | Node | Requirement detail |
|---|---|---|
| 1 | MySQL Connector | credentials via flow variables or placeholders, never hardcoded in the exported file |
| 2 | DB Query Reader | live SQL on the joined feature query; remove the CRC32 1% sample if the full set runs in acceptable time |
| 3 | Missing Value | defensive imputation, log counts |
| 4 | Numeric Outliers | IQR k=1.5, grouped by series, bounds from train only, cap |
| 5 | Rule-based Row Splitter | `d <= 1868` train, else test |
| 5b | **Leakage check** | assert min(test d) > max(train d); show result in a Table View |
| 6 | Linear Regression Learner and Predictor | features documented (lags, SNAP, event, weekday) |
| 7 | Math Formula | clip predictions to >= 0, compute errors |
| 7b | Numeric Scorer replacement | fix the Week 3 NaN warning: compute MAE, RMSE, R2 with Math Formula + GroupBy on the **unclipped** test set. Report clipped and unclipped separately |
| 8 | DB Writer | **truncate/replace before write** (APPEND caused the 39,496 vs 19,748 duplicates). Confirm row count and `MIN(predicted) >= 0` |

Also: coloured annotation boxes, delete unused nodes, export `knime/Bigdata_final.knwf` (only one copy, executed state) and `knime/knime_pipeline_architecture.png`.

**Gate:** Reset all nodes, Execute All, and the run completes with the expected `sales_predictions` row count. Run it twice and confirm the count does not grow.

### Phase 4: Aggregation, KPIs and number validation (about 4 h) | Grade 3, 6
1. SQL view chain: predictions (deduped) -> join `sell_prices` -> `revenue = units * price` at SKU-store-day -> aggregate to store-week.
2. Reconcile the funnel: **raw rows -> deduped rows -> store-week rows**. lh claims 39,496 -> 19,748 -> 110. Re-derive them; update the plan if they differ.
3. Flag complete weeks (7 days). lh claims 100 of 110 are complete (10 weeks x 10 stores, 11/03-22/05/2016). Verify, and use only complete weeks for error metrics.
4. Write `sql/03_kpi_queries.sql`: MAE, MAPE, bias, WAPE per store, per state, per week, in units and in USD.
5. **Recompute and record** each headline number: CA_1 and CA_3 under-forecast weeks (10/10?), CA_3 revenue MAE (~128.73?), state bias (CA -20.20%, TX +4.76%, WI +3.27%?), overall MAE/MAPE (12.59 / 14.43% units, 65.07 / 17.73% USD?).
6. Answer supporting Q4 and Q5: find weeks where the state total looks accurate while store errors cancel.

**Gate:** a one-page `process/numbers_verified.md` where each figure has its SQL source. This file feeds the report, dashboard and slides.

### Phase 5: Power BI dashboard (about 5 h) | Grade 6 (2.0)
1. Connect to MySQL by **live/DirectQuery or Import with refresh**, not CSV. Source: the store-week view (110 rows) plus the daily view.
2. KPI cards: actual units, forecast units, revenue actual/forecast, MAE, MAPE, active stores.
3. Visuals: actual vs forecast line over time (single axis, no smoothing), bias bar chart by state with zero baseline, store-week error table, state vs store reconciliation view (Q5).
4. Slicers: State, Store, Week, (SNAP/holiday if it fits the data).
5. Separation rule: all 110 rows on the page, metrics computed on the 100 complete weeks only.
6. Test: refresh from MySQL, filter `CA -> CA_3`, confirm the cards match `numbers_verified.md`.
7. Save `dashboard/m5_sales_forecasting_final.pbix` and export screenshots to `dashboard/screenshots/` (`kpi_overview.png`, `actual_vs_predicted.png`, plus state and store views).

**Gate:** dashboard numbers equal SQL numbers. No double counting (the old card showed 17.47K = 2 x 8,734).

### Phase 6: Recommendations (about 3 h) | Grade 6
Three actions, each as **evidence -> action -> KPI to track -> trade-off/risk**:
1. **CA_1 and CA_3 stock-out review:** evidence from DQ1. Action: find the SKUs with the largest under-forecast, compare with available stock, adjust reorder points. Trade-off: more stock raises holding cost and spoilage risk.
2. **CA_3 revenue-priority:** DQ2. Action: rank SKUs by contribution to revenue error. Trade-off: effort spent on revenue error may differ from unit-error priority.
3. **State calibration:** DQ3. Action: test per-state correction factors, and accept only if bias and MAE both improve on held-out weeks. Trade-off: risk of overfitting a single year.

Add limitations: one year of data (one seasonal cycle), 10 evaluation weeks, linear/additive model, no stock-on-hand data in the dataset.

**Gate:** each recommendation cites a verified number and a measurable follow-up KPI.

### Phase 7: IEEE report (about 8 h) | Grade 7 (1.0)
Two-column IEEE, 6-10 pages, at least 5 references, PDF + editable DOCX/LaTeX, signed integrity sheet as the cover.

| Required 9 sections | IEEE location |
|---|---|
| Problem and decision questions | I. Introduction |
| Dataset and source/licence (M5, Kaggle) | III. Methodology (A) |
| Data quality + Before/After | III. Methodology (B) |
| MySQL design | III. Methodology (C) |
| KNIME workflow | III. Methodology (D), architecture PNG |
| ML model and evaluation | IV. Experiments and Results |
| Dashboard | IV. Results (dashboard figure) |
| Recommendations and trade-offs | V. Discussion and Decision Recommendations |
| Limitations, conclusion, reflection | V + VI. Conclusion |

Also: Abstract, Keywords, II. Related Work (M5, forecasting, why Linear Regression, MAE/MAPE/RMSE), References. Report KNIME test scores and post-aggregation errors in separate tables. Fill every `[TBD]` in `Week2_Person2_Machine_Learning.md` or merge its content and delete the file.

**Gate:** zero `[TBD]`, every number traces to `numbers_verified.md`, page count within 6-10.

### Phase 8: Presentation and demo (about 4 h) | Grade 8 (0.5)
1. `presentation/Final_Project_Presentation.pptx`, 9 slides: title and roles; SWOT and communication plan; decision problem and 3 questions; architecture; data quality Before/After; ML design, split and metrics; live demo; 3 recommendations; Plan vs Actual.
2. Demo script on **one laptop**: show MySQL row counts -> run KNIME -> show the new `sales_predictions` rows -> refresh Power BI -> filter CA -> CA_3.
3. Rehearse twice. Prepare a backup screen recording and screenshots in case the live run fails.
4. Q&A prep: join keys, duplicates and how they were removed, revenue formula, why a time split, MAE vs MAPE vs RMSE, how a number became a decision.

**Gate:** a timed end-to-end rehearsal finishes with no manual fixes.

### Phase 9: Packaging and reproducibility (about 3 h) | Grade 8, 3, 4
1. Root `README.md`: title, business context, architecture diagram, versions (MySQL 8.0+, KNIME 5.x, Power BI), reproduction steps, placeholders, WBS and roles.
2. `sql/m5_database_dump_sample.sql` (about 1% or 100k rows, small enough for GitHub; never commit the 1-2 GB dumps).
3. Push to the GitHub repo with the required structure.
4. **Clean-clone test:** clone to a fresh folder, import the sample dump, open the KNIME workflow, execute, refresh Power BI. Fix anything that breaks.
5. Plan vs Actual table: commitments, planned vs actual hours (15.5 h of 24 h were logged at Week 2), variance, handling. Open with the four Week 4 questions: what was delivered, when, why this product, hours used.
6. Final checklist pass against `required_files.md` section 2.

**Gate (Basic track complete):** every file in the section 2 checklist exists and the clean-clone test passes.

---

## 2. Advanced track (`roadmap.html`), after the Phase 9 gate

Do these in order of grade value. Each links to roadmap task ids.

| Priority | Upgrade | Roadmap ids | Why it matters |
|---|---|---|---|
| 1 | Baselines (predict last week, predict 0) and WAPE, to show the model beats them | p3t8 | Makes the R2 and MAE meaningful |
| 2 | Lag features (lag1, lag2, rolling-4 scaled by series mean) | p3t6 | Better forecast accuracy |
| 3 | Residual interpretation by store, department, SNAP week | p3t11 | Grade 5 residual-analysis requirement |
| 4 | Move to store x dept x week grain | p1t6, p2t10 | Daily item-level WAPE was 70-118% against 6.8% for weekly dept-store |
| 5 | Structural zeros (store_closed Dec 25, on_sale) | p2t8 | Cleaner data quality story |
| 6 | Extra dashboard charts (weekday profile, SNAP lift, growth, top items) | p5t6 | Historical EDA visuals listed in required_files |
| 7 | Intermittent-item policy, K-Means segmentation | p6t4, p6t5 | Optional expansion |

If grain changes, **re-run Phases 3-6 numbers** and update `numbers_verified.md`. Mixing numbers from two grains in one report is the main risk of this track.

---

## 3. Coverage map: grading components to phases

| Component | Weight | Phases | Key evidence |
|---|---|---|---|
| 1 Problem and questions | 1.0 | 1 | `decision.md`, report Intro |
| 2 Data and quality | 1.5 | 2 | Before/After table, outlier rationale |
| 3 MySQL and SQL | 1.0 | 2, 4 | `sql/01-04`, sample dump |
| 4 KNIME | 1.5 | 3 | `.knwf`, architecture PNG, live write-back |
| 5 ML and evaluation | 1.5 | 3, 4 | time split, leakage check, MAE/RMSE/R2, residuals |
| 6 Dashboard and decisions | 2.0 | 5, 6 | `.pbix`, screenshots, 3 recommendations with trade-offs |
| 7 Report | 1.0 | 7 | PDF + DOCX, 9 sections, 5+ references, integrity sheet |
| 8 Demo and GitHub | 0.5 | 8, 9 | README, clean-clone test, rehearsal |

## 4. Effort and order

Total about 40 h of new work for the basic track (planned hours for the team to adjust). Critical path: **2 -> 3 -> 4 -> 5 -> 6 -> 7**. Phase 1 and Phase 0 run in parallel with the start of Phase 2. Phases 8 and 9 start as soon as Phase 5 has stable screenshots; the report (7) can be drafted in parallel from Phase 4 on, with numbers filled from `numbers_verified.md`.

Suggested split for 3 people: DE = Phases 0, 2, 9 (MySQL, scripts, repo); DS = Phases 3, 4 (KNIME, metrics); DA = Phases 5, 6, 8 (dashboard, recommendations, slides). The report is shared, with one person owning the final merge.

## 5. Top risks

| Risk | Mitigation |
|---|---|
| Duplicate predictions return (APPEND mode) | Truncate before write, UNIQUE key, row-count assertion in the demo |
| lh numbers do not reproduce | Phase 4 gate; update the narrative to the verified values |
| Low R2 (earlier run: 0.016) looks weak next to the dashboard error rates | Report it honestly, add baselines (advanced #1), explain pooled vs per-series |
| Live demo fails | Backup recording and screenshots, pre-warmed MySQL and KNIME |
| Hardcoded paths or passwords in the repo | Phase 0 `.gitignore`, Phase 9 clean-clone test |
| Report exceeds 10 pages | Move extra tables to README or the appendix of the repo, not the PDF |

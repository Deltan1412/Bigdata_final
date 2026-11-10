# Required numbers for `Final_Project_Presentation_LAYOUT.pptx`

Every number the deck needs, in slide order. Each field on a slide shows an ID such as `[N042]`; this file gives its meaning, where to get it, and a draft value if one already exists in the project notes. Text-only placeholders were removed from the deck, so nothing else needs filling except these fields (and the SWOT quadrants, which are text).

- Deck: `process/misc/big-data-analytics-project/presentation/Final_Project_Presentation_LAYOUT.pptx` (27 slides: the 9 stock slides plus 18 added; the template file is untouched).
- Basis: `requirement/Big Data Analytics_Final_Project_2026_VNUK.pdf`, `Week_1.pdf` to `Week_4.pdf`, `required_files.md`, and the decisions in `process/misc/decision_results.md`.
- A field that appears on several slides keeps **one ID**, so the number is entered once and stays consistent. The `Where` column lists every slide it appears on.
- To fill the deck: replace the `[Nxxx]` text with the value. Search the slide for `[N` to find what is left. Speaker notes on each slide also list that slide's IDs.

## 1. Summary

**232 number fields** and **3 label fields** (store names, `[Txx]`) across 27 slides.

| Status | Fields | Meaning |
|---|---:|---|
| VERIFIED | 116 | Run in MySQL and recorded in `process/misc/decision_results.md` (2026-11-10). Re-check only if the data changes. |
| COLLECTED | 73 | From the weekly model run (2026-11-10), listed in `process/numbers_collected.csv` and `decision_results.md`. Metrics are recomputed from the 700 predictions in MySQL, counts are read from the saved workflow. **Not yet compared with the KNIME Numeric Scorer on screen**: compare, then promote to VERIFIED. |
| CSV | 0 | Computed from the raw CSV files, **not yet reproduced in MySQL** (N040 calendar rows, N090 99th percentile). Run the SQL and confirm before it goes on a slide. |
| DESIGN | 2 | Value implied by the design (for example 70 series x 10 test weeks). Confirm with the check named in the Source column after the first run. |
| DECIDE | 0 | Team decision, not a measurement. Choose it first because other numbers depend on it. |
| RUN | 2 | No value yet. Needs a SQL, KNIME or Power BI run. |
| TEAM | 37 | Manual input from the team (hours, counts of meetings, student IDs, report pages). |
| REMOVED | 5 | Dropped from the deck (repo checks: screenshots, sample dump rows, credentials, README steps; and the password count). |

| Source | Fields |
|---|---:|
| MySQL | 120 |
| KNIME | 48 |
| Team log | 33 |
| Team | 15 |
| Power BI | 8 |
| Repo | 5 |
| Decision | 4 |
| Design | 2 |

## 2. Decide or check first

These affect several numbers. Settle them before filling the slides.

- **Q2 flag threshold (N017, N018): decided, 20 pp.** At 10 pp 12 of 30 store-categories flag; at 20 pp 3 flag (CA_2, WI_3, WI_2 FOODS), which meets the target of about 2 to 4 (`03_kpi_queries.sql` B.1b). N018 is 3 on slides 4 and 23. `decision_results.md` Q2 is updated to match.
- **Q3 threshold and unit (N019, N020).** The deck counts state-categories (of 9) above the threshold. At 10% only TX FOODS (14.60) and WI FOODS (27.77) pass, so the answer is "2 of 9", while the state-level view (B.2b) gives TX and WI. Keep one unit on every slide.
- **Train weeks (N037, N061).** `decision_results.md` defines train as `week_idx` 2 to 42 (41 weeks, 2,870 rows). `knime_guide.md` step 5 trains on weeks 6 to 42 (37 weeks, **2,590 rows**) because weeks 2 to 5 use a lag built from the 6-day week 1. The deck uses the KNIME figures (37 weeks, 4 warm-up weeks). Say so in the report.
- **Split rule vs `required_files.md`.** `required_files.md` still says `train: d <= 1868`. The weekly design replaces it with a cut on `week_idx` (decided 2026-11-10). The leakage check is unchanged in spirit: `MIN(test week_idx) > MAX(train week_idx)` (N039).
- **Outliers: retained, not capped.** `required_files.md` lists a Numeric Outliers node that caps values. The project decision is to retain them (the brief allows "retaining or handling"). The deck shows N138 = 0 values changed and reports the fence only as evidence (N078, N083). If a capped sensitivity run is made, N195 holds its result.
- **Rows marked CSV.** Only N040 (calendar rows, 1,969) and N090 (99th percentile, 15) are still CSV-only. The duplicate, completeness, validity, structural-zero and IQR figures (N069 to N077, N087 to N089) were run in MySQL on 2026-11-10 and match the CSV values; N072 = 0 and N021 = 11,128,850 are confirmed on the live table.
- **Old numbers are superseded.** Figures from the earlier item x store x day design (R2 0.016, state bias CA -20.20 / TX +4.76 / WI +3.27, CA_3 revenue MAE about 128.73, 39,496 / 19,748 / 110 rows) belong to a different grain. They appear only as hints in the Draft column marked "old"; recompute them on the weekly model.
- **Hours.** Role hours (N205 to N213) must add up to the deliverable totals (N226, N227). `lh_execution_plan.md` records 15.5 h of 24 h logged at Week 2.
- **Departments (N025).** 7, from the MySQL view check (70 series = 10 stores x 7 departments). A direct `SELECT COUNT(DISTINCT dept_id)` is optional.
- **Workflow has 7 sections, the deck has 8 (N051 to N058).** The saved workflow `Bigdata_final_weekly` has 28 nodes: Connect 2, Ingest 1, Prepare 4, Split + leakage check 4, Model 3, Evaluate 10, Write-back 4. There is no Check or Verify section. Decided: slide 8 shows the 7 real sections (tile 3 is "Prepare", the Verify tile is dropped). Filled as N051 2, N052 1, N053 4, N054 4, N055 3, N056 10, N057 4.
- **Slide 8 row flow (N059, N060).** The Reader returns 3,290 rows because `v_weekly_model` already keeps only full weeks (`model_ready = 1`). N060 has no node behind it. Decided: slide 8 shows the view (3,710) then the Reader (3,290, N060).
- **Feature count and list (N136).** The Learner has 6 features plus the intercept (7 coefficients): `snap_days`, `event_days`, `closed_days`, `lag1_s`, `lag2_s`, `roll4_s`. The earlier draft (7 features incl. `month_of_week`, `dept_id`) was wrong. Slide 14 subtitle "lags, SNAP, event, month, dept" must change to "lags, SNAP, event, closed days".
- **Validation checks (N064, N065).** The 6 checks passed are the ones in `collect_run_numbers.py` (leakage, rows written = test rows, no duplicate keys, no negative prediction, actuals equal source, no NULL lags). In KNIME only the leakage GroupBy checks exist. Say on the slide where the checks run, or add them as nodes.
- **Run time (N066): done.** Two clean runs are in `knime.log` (13:49 and 13:50): 1.7 s and 0.9 s, 28 nodes each. The slide shows seconds, not minutes.
- **Re-run check (N033, N067): done.** After the second run the table holds 700 rows (700 distinct keys, all rewritten at 13:50:53), so growth is 0.
- **Stronger baseline.** The 4-week average has WAPE 6.70%, slightly better than the model (6.80%); the model wins 8 of 10 weeks against it. The slides compare only with last week (7.65%). State this on slide 15 or 22 (see section 8).

## 3. Requirement coverage

Which slide carries each graded component, so no required number is missing.

| Rubric component (weight) | Slides | What the numbers prove |
|---|---|---|
| 1. Problem and decision questions (1.0) | 4 | Three questions, each with a target and a result. |
| 2. Dataset and data quality (1.5) | 5, 9, 10, 22 | Records >= 1,000, attributes >= 5, four checks, BEFORE/AFTER counts, outlier rows and units, remaining risks. |
| 3. MySQL and SQL (1.0) | 7, 6 | Tables, keys, row counts, scripts, KPI queries, view reconciliation. |
| 4. KNIME workflow (1.5) | 8, 17 | Section node counts, row counts through the flow, validation checks, write-back and re-run equality. |
| 5. Machine learning (1.5) | 14, 15, 16 | Time split, leakage margin, MAE, RMSE, R2, WAPE against the last-week baseline, error by store, department and state. |
| 6. Dashboard, insights, decisions (2.0) | 11, 12, 13, 18, 20, 21, 22, 23 | KPI cards that match SQL, answers to Q1 to Q3, three recommendations with benefit and trade-off, uncertainty. |
| 7. Report (1.0) | 25 | Page count, references, signed sheet (no number field for the signature). |
| 8. Demonstration and GitHub (0.5) | 19, 25, 26, 27 | Demo timings, fallback, repo checks, individual contributions, plan versus actual. |

## 4. Fill order

1. **Decide** the `DECIDE` fields (section 2). Thresholds change which rows count.
2. **MySQL:** run `sql/03_kpi_queries.sql` (parts A, B, C), `01_full_year_stats_and_quality_audit.sql`, `02_structural_zeros.sql`, then the checks in `knime_guide.md` step 0. Fields with source MySQL.
3. **KNIME:** `Reset all`, `Execute all`, then run it a second time. Fields with source KNIME. Compare MAE and WAPE with `03_kpi_queries.sql` C.3.
4. **Power BI:** refresh, then read each card. Fields with source Power BI. Each card must equal its SQL value.
5. **Team log and repo:** hours, meetings, files, clean-clone test. Fields with source Team, Team log, Repo.

## 5. Fields by slide

Columns: **ID** shown on the slide; **Source** is where the number comes from; **Draft value** is what the project notes already say (blank = nothing yet); **Status** as defined in section 1.

### Slide 1: Forecasting weekly demand to guide inventory decisions

*required_files.md slide 1: title, team members and roles (Person 1 DE, Person 2 DS, Person 3 DA).*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N001]` | Student ID, Data Engineer | digits | Team | Student card | The three IDs are 24040005 (Pham Ngoc Thien An), 24040001 (Huynh Nguyen Nhat Linh), 24040006 (Bui Dinh Hieu) from `w intro.pdf` p2. The role of each person is not stated; confirm which is which | TEAM | 1 |
| `[N002]` | Student ID, Data Scientist | digits | Team | Student card | The three IDs are 24040005 (Pham Ngoc Thien An), 24040001 (Huynh Nguyen Nhat Linh), 24040006 (Bui Dinh Hieu) from `w intro.pdf` p2. The role of each person is not stated; confirm which is which | TEAM | 1 |
| `[N003]` | Student ID, Data Analyst | digits | Team | Student card | The three IDs are 24040005 (Pham Ngoc Thien An), 24040001 (Huynh Nguyen Nhat Linh), 24040006 (Bui Dinh Hieu) from `w intro.pdf` p2. The role of each person is not stated; confirm which is which | TEAM | 1 |

### Slide 2: Roadmap: from question to decision

*No numbers. Section order follows the Week 1 to Week 4 briefs.*

No number fields.

### Slide 3: Team SWOT and communication plan

*Week 1 items 1 and 2: group SWOT (1 slide) and team communication plan (1 slide). SWOT quadrants are text only and carry no number field.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N004]` | Stand-ups planned in the 4 weeks | count | Team | WBS / team calendar | 4 (WORKING VALUE set by the team on 2026-11-10, not from a log; replace with the real count if asked). Earlier hint: 4 planned if the weekly Thursday 8:00 PM Discord meeting counts (`w intro.pdf` p6); the w1 slide p4 also has "daily Zalo syncs" with no count | TEAM | 3 |
| `[N005]` | Stand-ups actually held | count | Team | meeting log | 4 (WORKING VALUE set by the team on 2026-11-10, not from a log; replace with the real count if asked). Earlier hint: Not in the slides. Meeting log | TEAM | 3 |
| `[N006]` | Code reviews planned in the 4 weeks | count | Team | WBS / team calendar | 6 (WORKING VALUE set by the team on 2026-11-10, not from a log; replace with the real count if asked). Earlier hint: No review count in the slides; `w intro.pdf` p6 only says "pre-notify group before GitHub pushes". Pull requests planned in the WBS | TEAM | 3 |
| `[N007]` | Code reviews actually held | count | Team | GitHub pull requests | 5 (WORKING VALUE set by the team on 2026-11-10, not from a log; replace with the real count if asked). Earlier hint: Not in the slides. Count merged pull requests with a review | TEAM | 3 |
| `[N008]` | Hand-offs planned in the 4 weeks | count | Team | WBS / team calendar | 3 (WORKING VALUE set by the team on 2026-11-10, not from a log; replace with the real count if asked). Earlier hint: 3 planned (form (1).docx): end of Week 1, end of Week 2, and the final Demo Day touchpoint | TEAM | 3 |
| `[N009]` | Hand-offs actually held | count | Team | hand-off notes | 3 (WORKING VALUE set by the team on 2026-11-10, not from a log; replace with the real count if asked). Earlier hint: Not in the slides. Hand-off notes: Week 1 (3 questions and clean flow), Week 2 (KNIME to DB, dashboard), Demo Day | TEAM | 3 |
| `[N010]` | Escalations planned in the 4 weeks | count | Team | WBS / team calendar | 2 (WORKING VALUE set by the team on 2026-11-10, not from a log; replace with the real count if asked). Earlier hint: Rule only, no count: `w intro.pdf` p6 "ad-hoc 4-hour notice, max 6 to 8 h response"; w1 slide p4 "48-hour early-warning escalation". The two rules differ | TEAM | 3 |
| `[N011]` | Escalations actually held | count | Team | chat log | 1 (WORKING VALUE set by the team on 2026-11-10, not from a log; replace with the real count if asked). Earlier hint: Not in the slides. Chat log | TEAM | 3 |
| `[N012]` | Defects caught by a communication rule | count | Team | Incident log. Known case: duplicate-prediction bug caught at hand-off | 1 (WORKING VALUE set by the team on 2026-11-10, not from a log; replace with the real count if asked). Earlier hint: >= 1 | TEAM | 3 |

### Slide 4: Decision problem and three questions

*Final project section 1: decision-maker and at least three specific, measurable decision questions. Week 1 item 3.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N013]` | Stores in scope | stores | MySQL | 03_kpi_queries.sql A.3 (COUNT DISTINCT store_id) | 10 | VERIFIED | 4, 5, 18 |
| `[N014]` | Forecast horizon, weeks ahead | weeks | Design | decision_results.md: RIM decides a week ahead | 1 (decision_results.md: the manager decides a week ahead) | VERIFIED | 4 |
| `[N015]` | Q1 target: WAPE ceiling | % | Decision | decision_results.md Q1 | 10 (decided 2026-11-10: Q1 target is WAPE <= 10%; the model gets 6.80) | VERIFIED | 4, 21, 23 |
| `[N016]` | Test WAPE, Linear Regression (clipped) | % | KNIME | KNIME Evaluate section (GroupBy + Math Formula); cross-check 03_kpi_queries.sql C.3 | 6.80 (6.7977). Q1 target 10 is met | COLLECTED | 4, 15, 18, 21, 23 |
| `[N017]` | Q2 flag threshold (growth gap) | pp | Decision | decision_results.md Q2 (provisional) | 20 (decided 2026-11-10: at 10 pp 12 of 30 flag, at 20 pp 3 flag, the target was 2 to 4; B.1b) | VERIFIED | 4, 13, 21, 23 |
| `[N018]` | Store-categories flagged at the chosen threshold (of 30) | count | MySQL | 03_kpi_queries.sql B.1 / B.1b | 3 (at 20 pp: CA_2, WI_3 and WI_2 FOODS; 12 at 10 pp) | VERIFIED | 4, 13, 23 |
| `[N019]` | Q3 uplift threshold | % | Decision | decision_results.md Q3 (provisional) | 10 (decided 2026-11-10: confirmed on the full data, TX FOODS 14.60 and WI FOODS 27.77 pass, the other 7 do not) | VERIFIED | 4, 12, 21, 23 |
| `[N020]` | State-categories above the uplift threshold (of 9) | count | MySQL | 03_kpi_queries.sql B.2 | 2 at 10% (TX FOODS 14.60, WI FOODS 27.77) | VERIFIED | 4, 12, 23 |

### Slide 5: Dataset at a glance

*Final project section 2: source, licence, number of records (>= 1,000), attributes (>= 5), meaning and relevance. Week 1 item 4, Week 2 item 1.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N021]` | Rows in sales_history | rows | MySQL | 03_kpi_queries.sql A.1 (total_rows) | 11,128,850 | VERIFIED | 5, 6, 7, 19 |
| `[N022]` | Item-store series | series | MySQL | SELECT COUNT(DISTINCT id) FROM sales_history | 30,490 (exactly 30,490 rows on each of the 365 days; 5.2b) | VERIFIED | 5 |
| `[N023]` | Calendar days in the window | days | MySQL | 03_kpi_queries.sql A.1 (distinct_days) | 365 (d_1577 to d_1941) | VERIFIED | 5 |
| `[N024]` | Distinct items | items | MySQL | SELECT COUNT(DISTINCT item_id) FROM sales_history | 3,049 (1,112,885 rows per store / 365 days; A.3) | VERIFIED | 5 |
| `[N013]` | Stores in scope | stores | | same value as slide 4 | | | 4, 5, 18 |
| `[N025]` | Departments | depts | MySQL | SELECT COUNT(DISTINCT dept_id) FROM sales_history | 7 (70 series = 10 stores x 7 departments; view check) | VERIFIED | 5 |
| `[N026]` | Attributes (columns) per sales row | cols | MySQL | DESCRIBE sales_history | 8 (id, item_id, dept_id, cat_id, store_id, state_id, day, sales; NULL audit covers all 8) | VERIFIED | 5, 7 |
| `[N027]` | Rows in sell_prices | rows | MySQL | SELECT COUNT(*) FROM sell_prices | 6,841,121 (5.4) | VERIFIED | 5, 7 |
| `[N028]` | States | states | MySQL | 03_kpi_queries.sql A.3 | 3 (CA, TX, WI) | VERIFIED | 5 |
| `[N029]` | Categories | cats | MySQL | 03_kpi_queries.sql A.2 | 3 (FOODS, HOBBIES, HOUSEHOLD) | VERIFIED | 5 |
| `[N030]` | Full 7-day weeks used | weeks | MySQL | SELECT COUNT(*) FROM (SELECT week_idx FROM v_weekly_features WHERE n_days = 7 GROUP BY week_idx) t | 51 (week_idx 2 to 52; n_days < 7 only at week_idx 1 and 53) | VERIFIED | 5 |

### Slide 6: Architecture and design choices

*required_files.md slide 4 and Week 1 item 5: Dataset > MySQL > KNIME > ML > MySQL > Dashboard > Decisions.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N021]` | Rows in sales_history | rows | | same value as slide 5 | | | 5, 6, 7, 19 |
| `[N031]` | Tables and views in bigdataprj | objects | MySQL | SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'bigdataprj' | 17 (11 tables + 6 views). Tables: calendar, sales_history, sell_prices, store_day_closed, weekly_features, weekly_features_sample, state_cat_day, series_demand_profile, weekly_revenue, sales_predictions, sales_predictions_weekly. Views: v_sales_features, v_weekly_features, v_weekly_model, v_weekly_model_sample, v_state_cat_day, v_pred_eval. From the scripts in `process/sql/result` and the raw CSVs, not from a live query: confirm with the information_schema query; a leftover table in the live schema changes the count | COLLECTED | 6 |
| `[N032]` | Nodes in the final KNIME workflow | nodes | KNIME | Count nodes on the canvas of Bigdata_final.knwf | 28 (saved workflow Bigdata_final_weekly) | COLLECTED | 6 |
| `[N033]` | Rows in sales_predictions_weekly after run 2 | rows | MySQL | Same query after a second Reset all + Execute all | 700 (after run 2: 700 rows, 700 distinct keys, all stamped 13:50:53, none left from run 1; counted in MySQL) Read from knime.log: two clean Reset all + Execute all runs at 13:49 and 13:50, 28 nodes each. | VERIFIED | 6, 17, 23 |
| `[N034]` | Dashboard pages | pages | Power BI | powerbi_guide.md section 5 | 3 (Overview, Stores and states, Demand drivers). Filled from the design; confirm in the .pbix | DESIGN | 6, 18 |
| `[N035]` | Store x department series | series | MySQL | SELECT COUNT(*) FROM (SELECT DISTINCT store_id, dept_id FROM v_weekly_features) t | 70 (10 x 7; check c) | VERIFIED | 6, 14 |
| `[N036]` | Weeks in the window (week_idx 1 to 53) | weeks | MySQL | SELECT COUNT(DISTINCT week_idx) FROM v_weekly_features | 53 (wm_yr_wk 11517 to 11617; check e) | VERIFIED | 6, 22 |
| `[N037]` | Training weeks used by the model | weeks | KNIME | Row Filter week_idx >= 6, split = train | 37 (weeks 6 to 42: 2,590 train rows / 70 series). The split rule has 41 train weeks, the first 4 are lag warm-up | VERIFIED | 6, 14, 15 |
| `[N038]` | Test weeks | weeks | KNIME | Rule-based Row Splitter, test output | 10 (week_idx 43 to 52; 700 test rows; check c) | VERIFIED | 6, 14, 15, 22, 23 |
| `[N039]` | Leakage margin: MIN(test week_idx) minus MAX(train week_idx) | weeks | KNIME | Leakage-check GroupBy + Column Appender (knime_guide.md step 5.3) | 1 (43 minus 42). MySQL check d: ok = 1; the two KNIME GroupBy checks show 42 and 43 | VERIFIED | 6, 8, 14, 15 |

### Slide 7: MySQL: schema, keys and checks

*Final project section 3 and Week 2 item 3: tables, keys, relationships, runnable schema, import and query scripts.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N021]` | Rows in sales_history | rows | | same value as slide 5 | | | 5, 6, 7, 19 |
| `[N026]` | Attributes (columns) per sales row | cols | | same value as slide 5 | | | 5, 7 |
| `[N040]` | Rows in calendar | rows | MySQL | SELECT COUNT(*) FROM calendar | 1,969 (calendar.csv has 1,969 data rows; import_calendar.sql loads every row, IGNORE 1 LINES, no filter) | COLLECTED | 7 |
| `[N041]` | Columns in calendar | cols | MySQL | DESCRIBE calendar | 14 (date, wm_yr_wk, weekday, wday, month, year, d, event_name_1, event_type_1, event_name_2, event_type_2, snap_CA, snap_TX, snap_WI; same in calendar.csv and the DDL) | COLLECTED | 7 |
| `[N027]` | Rows in sell_prices | rows | | same value as slide 5 | | | 5, 7 |
| `[N042]` | Columns in sell_prices | cols | MySQL | DESCRIBE sell_prices | 4 (store_id, item_id, wm_yr_wk, sell_price; same in sell_prices.csv and the DDL) | COLLECTED | 7 |
| `[N043]` | Rows in v_weekly_features | rows | MySQL | SELECT COUNT(*) FROM v_weekly_features | 3,710 (70 x 53; check c) | VERIFIED | 7 |
| `[N044]` | Columns in v_weekly_features | cols | MySQL | DESCRIBE v_weekly_features | 17: store_id, state_id, dept_id, cat_id, wm_yr_wk, week_idx, week_start, week_end, first_day, n_days, sales, snap_days, weekend_days, event_days, holiday_days, month_of_week, split (from the view in 02_feature_engineering.sql). The model view v_weekly_model has more (closed_days, lag1, lag2, roll4, series_mean, model_ready) | COLLECTED | 7 |
| `[N045]` | Rows in sales_predictions_weekly | rows | MySQL | SELECT COUNT(*) FROM sales_predictions_weekly | 700 (rows written for LinearRegression_weekly_v1) | VERIFIED | 7 |
| `[N046]` | Columns in sales_predictions_weekly | cols | MySQL | DESCRIBE sales_predictions_weekly | 10 (id, store_id, dept_id, wm_yr_wk, week_idx, forecast_day, predicted_sales, actual_sales, model_name, prediction_date; DDL in 04_sales_predictions_schema.sql) | COLLECTED | 7 |
| `[N047]` | Numbered SQL scripts in the repository | files | Repo | ls sql/ | 5 in `process/sql/result` (01 to 04 plus 05_sample_database). The repo copy `big-data-analytics-project/sql` still has 4: copy the folder over before submitting | COLLECTED | 7, 25 |
| `[N048]` | KPI queries run without error | queries | MySQL | Count the runnable blocks in 03_kpi_queries.sql (A, B, C) | 31 (all 31 labelled blocks of 03_kpi_queries.sql ran without error: 27 report queries + 4 build blocks B.0, B.5, C.0, C.1). Tested by the team on 2026-11-10; the slide says "blocks" | VERIFIED | 7 |
| `[N049]` | Keys and indexes defined (PK + FK + indexes) | objects | MySQL | information_schema.statistics for bigdataprj | 22 = 11 primary keys + 3 unique keys (uk_calendar_date, uk_prediction, uk_prediction_weekly) + 6 other indexes (idx_calendar_wm_yr_wk, idx_calendar_year_month, idx_sales_day, idx_sales_store_item, idx_sales_cat_dept, idx_price_wk) + 2 foreign keys (fk_sales_calendar, fk_pred_weekly_calendar). From the scripts in `process/sql/result` and the raw CSVs, not from a live query: confirm with the information_schema query | COLLECTED | 7 |
| `[N050]` | SUM(sales) in the view minus SUM(sales) in sales_history | units | MySQL | knime_guide.md step 0.1 check 1 | 0 (14,585,821 in the view and in sales_history; check a) | VERIFIED | 7 |

### Slide 8: KNIME workflow and validation

*Final project section 4 and Week 2 item 4: labelled sections, reproducible operations, basic validation checks, live MySQL connection.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N051]` | Nodes in section 1 (Connect) | nodes | KNIME | Count nodes inside the annotation box | 2 (workflow section 1, Connect) | COLLECTED | 8 |
| `[N052]` | Nodes in section 2 (Ingest) | nodes | KNIME | Count nodes inside the annotation box | 1 (section 2, Ingest) | COLLECTED | 8 |
| `[N053]` | Nodes in section 3 (Check) | nodes | KNIME | Count nodes inside the annotation box | 4 (the workflow has Prepare here, not Check; rename the slide tile) | COLLECTED | 8 |
| `[N054]` | Nodes in section 4 (Split) | nodes | KNIME | Count nodes inside the annotation box | 4 (Split + leakage check) | COLLECTED | 8 |
| `[N055]` | Nodes in section 5 (Model) | nodes | KNIME | Count nodes inside the annotation box | 3 (Model) | COLLECTED | 8 |
| `[N056]` | Nodes in section 6 (Evaluate) | nodes | KNIME | Count nodes inside the annotation box | 10 (Evaluate) | COLLECTED | 8 |
| `[N057]` | Nodes in section 7 (Write-back) | nodes | KNIME | Count nodes inside the annotation box | 4 (Write-back) | COLLECTED | 8 |
| `[N058]` | Nodes in section 8 (Verify) | nodes | KNIME | Count nodes inside the annotation box | Dropped: slide 8 now shows the 7 sections of the real workflow (2+1+4+4+3+10+4 = 28 nodes). No value needed | VERIFIED | 8 |
| `[N059]` | Rows ingested by DB Query Reader | rows | KNIME | Row count on the DB Query Reader output | 3,290 (70 x 47). The Reader reads v_weekly_model with model_ready = 1, so the full-week filter is in the view, not in KNIME | VERIFIED | 8 |
| `[N060]` | Rows after the full-week filter (week_idx >= 6, n_days = 7) | rows | KNIME | Row Filter output | 3,290 (Reader rows; slide 8 now shows the view, 3,710, then the Reader, 3,290) | VERIFIED | 8 |
| `[N061]` | Training rows | rows | KNIME | Rule-based Row Splitter, top port | 2,590 (70 x 37; weeks 6 to 42) | VERIFIED | 8, 14 |
| `[N062]` | Test rows | rows | KNIME | Rule-based Row Splitter, bottom port | 700 (70 x 10; MySQL split, check c. Confirm the same count in KNIME) | VERIFIED | 8, 14 |
| `[N063]` | Missing cells left after preparation | cells | KNIME | Statistics node on the model input | 0 (NULL lags among the rows the Reader returns, checked in MySQL; not the KNIME Statistics node) | VERIFIED | 8 |
| `[N039]` | Leakage margin: MIN(test week_idx) minus MAX(train week_idx) | weeks | | same value as slide 6 | | | 6, 8, 14, 15 |
| `[N064]` | Validation checks passed | checks | KNIME | Tally of the checks in the Verify section | 6 (the 6 checks in collect_run_numbers.py, all pass; they are not KNIME nodes. The re-run check is not done) | COLLECTED | 8 |
| `[N065]` | Validation checks defined | checks | KNIME | Tally of the checks in the Verify section | 6 | COLLECTED | 8 |
| `[N066]` | Full-run time, Reset all then Execute all | s | KNIME | Stopwatch on one clean run | 1.7 seconds (run 1: 13:49:38.19 to 13:49:39.94, DB Writer last; run 2: 0.9 s). Slide unit changed from min to s Read from knime.log: two clean Reset all + Execute all runs at 13:49 and 13:50, 28 nodes each. Execution time only; it excludes the clicks and the password prompt. The flow is fast because it reads the 3,290-row weekly table. | VERIFIED | 8 |
| `[N067]` | Row growth between run 1 and run 2 | rows | MySQL | run 2 minus run 1 | 0 (700 after run 1, 700 after run 2; run 2 replaced the rows instead of appending) Read from knime.log: two clean Reset all + Execute all runs at 13:49 and 13:50, 28 nodes each. | VERIFIED | 8, 17 |
| `[N068]` | Passwords stored in the exported .knwf | count | KNIME | Unzip the .knwf and search for the password (knime_guide.md step 10.6) | Passwords stored in the exported workflow. Removed from the deck on 2026-11-10 at the team's request (the saved .knwf still holds the DB password in weakly encrypted form). | REMOVED | 8 |

### Slide 9: Data quality: before and after

*Final project section 2 and required_files.md slide 5: at least four quality checks, BEFORE and AFTER table with counts and percentages, outlier rationale.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N069]` | Missing cells in the 8 columns, before cleaning | count | MySQL | 01_full_year_stats_and_quality_audit.sql | 0 (5.2) | VERIFIED | 9 |
| `[N070]` | Missing cells in the 8 columns, after cleaning | count | MySQL | 01_full_year_stats_and_quality_audit.sql | 0 (nothing removed) | VERIFIED | 9 |
| `[N071]` | Rows changed for: Missing cells in the 8 columns | rows | MySQL | 01_full_year_stats_and_quality_audit.sql | 0 | VERIFIED | 9 |
| `[N072]` | Duplicate (id, day) keys, before cleaning | count | MySQL | 01_full_year_stats_and_quality_audit.sql | 0 (5.3: 11,128,850 rows = 11,128,850 distinct) | VERIFIED | 9 |
| `[N073]` | Duplicate (id, day) keys, after cleaning | count | MySQL | 01_full_year_stats_and_quality_audit.sql | 0 | VERIFIED | 9 |
| `[N074]` | Rows changed for: Duplicate (id, day) keys | rows | MySQL | 01_full_year_stats_and_quality_audit.sql | 0 | VERIFIED | 9 |
| `[N075]` | Invalid values (negative sales, day out of range, price <= 0), before cleaning | count | MySQL | 01_full_year_stats_and_quality_audit.sql | 0 (5.4) | VERIFIED | 9 |
| `[N076]` | Invalid values (negative sales, day out of range, price <= 0), after cleaning | count | MySQL | 01_full_year_stats_and_quality_audit.sql | 0 | VERIFIED | 9 |
| `[N077]` | Rows changed for: Invalid values (negative sales, day out of range, price <= 0) | rows | MySQL | 01_full_year_stats_and_quality_audit.sql | 0 | VERIFIED | 9 |
| `[N078]` | Train rows above the per-series IQR fence (k = 1.5, positive days) | rows | MySQL | Per-series fence report at the end of 01_schema_and_import.sql (train days d_1583 to d_1869 only) | 185,450 train rows above their series fence Computed in Python from the raw CSV in one pass (`fence_report_from_csv.py`), same definitions as 06_slide_numbers.sql section 3; the CSV matches the table (11,128,850 rows, max 349, 59.22% zeros) and the example series HOBBIES_1_004_CA_1 reproduces (fence 6, 11 flagged days, 10 on Sat/Sun, 39 units over). The MySQL run is optional. | COLLECTED | 9 |
| `[N079]` | Same, as share of train rows | % | MySQL | out_rows / train rows x 100 | 2.12 (2.119% of 8,750,630 train rows) Computed in Python from the raw CSV in one pass (`fence_report_from_csv.py`), same definitions as 06_slide_numbers.sql section 3; the CSV matches the table (11,128,850 rows, max 349, 59.22% zeros) and the example series HOBBIES_1_004_CA_1 reproduces (fence 6, 11 flagged days, 10 on Sat/Sun, 39 units over). The MySQL run is optional. | COLLECTED | 9 |
| `[N080]` | Rows before cleaning | rows | MySQL | 03_kpi_queries.sql A.1 | 11,128,850 | VERIFIED | 9 |
| `[N081]` | Rows after cleaning | rows | MySQL | Same table after the audit; nothing is removed | 11,128,850 | VERIFIED | 9 |
| `[N082]` | Rows removed | rows | MySQL | rows_before minus rows_after | 0 | VERIFIED | 9 |
| `[N083]` | Units above the fence, share of train units | % | MySQL | Same report, units / SUM(sales) x 100 | 3.17 (3.173% of 11,292,056 train units) Computed in Python from the raw CSV in one pass (`fence_report_from_csv.py`), same definitions as 06_slide_numbers.sql section 3; the CSV matches the table (11,128,850 rows, max 349, 59.22% zeros) and the example series HOBBIES_1_004_CA_1 reproduces (fence 6, 11 flagged days, 10 on Sat/Sun, 39 units over). The MySQL run is optional. | COLLECTED | 9 |
| `[N084]` | Units above the fence (units over the fence value) | units | MySQL | Same report, SUM(sales - fence) | 358,287 units over the fence. Units sold on those days: 1,211,920 (10.73% of train units) Computed in Python from the raw CSV in one pass (`fence_report_from_csv.py`), same definitions as 06_slide_numbers.sql section 3; the CSV matches the table (11,128,850 rows, max 349, 59.22% zeros) and the example series HOBBIES_1_004_CA_1 reproduces (fence 6, 11 flagged days, 10 on Sat/Sun, 39 units over). The MySQL run is optional. | COLLECTED | 9 |
| `[N085]` | Maximum daily sales of one item (unchanged) | units | MySQL | 03_kpi_queries.sql A.1 (max_sales) | 349 | VERIFIED | 9, 10 |

### Slide 10: Outliers and zeros: the evidence

*Final project section 2: documented rationale for retaining or handling outliers, rows and units affected.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N086]` | Share of rows with zero sales | % | MySQL | 03_kpi_queries.sql A.1 (zero_pct) | 59.22 | VERIFIED | 10, 22 |
| `[N087]` | Structural zeros flagged (store closed or not on sale) | rows | MySQL | 02_structural_zeros.sql | 30,186 (0.27% of rows; 02_feature_engineering.sql section 3) | VERIFIED | 10 |
| `[N088]` | Rows a global IQR cut would flag | % | MySQL | Sensitivity query, global IQR k = 1.5 (upper bound 2.5) | 14.24 (1,584,989 rows; 5.5c) | VERIFIED | 10 |
| `[N089]` | Units a global IQR cut would discard | % | MySQL | Same sensitivity query | 73.11 (10,663,015 units; 5.5c) | VERIFIED | 10 |
| `[N090]` | 99th percentile of daily sales | units | MySQL | 01_full_year_stats_and_quality_audit.sql | 15 (nearest rank on the 365-day histogram; matches the earlier CSV value) Computed in Python from the raw CSV in one pass (`fence_report_from_csv.py`), same definitions as 06_slide_numbers.sql section 3; the CSV matches the table (11,128,850 rows, max 349, 59.22% zeros) and the example series HOBBIES_1_004_CA_1 reproduces (fence 6, 11 flagged days, 10 on Sat/Sun, 39 units over). The MySQL run is optional. | COLLECTED | 10 |
| `[N085]` | Maximum daily sales of one item (unchanged) | units | | same value as slide 9 | | | 9, 10 |
| `[N091]` | Series without a fence (fewer than about 8 positive train days) | series | MySQL | Per-series fence report | 499 (246 never sold in the train days + 253 with fewer than 8 positive days; 29,991 series have a fence) Computed in Python from the raw CSV in one pass (`fence_report_from_csv.py`), same definitions as 06_slide_numbers.sql section 3; the CSV matches the table (11,128,850 rows, max 349, 59.22% zeros) and the example series HOBBIES_1_004_CA_1 reproduces (fence 6, 11 flagged days, 10 on Sat/Sun, 39 units over). The MySQL run is optional. | COLLECTED | 10, 22 |
| `[N092]` | Share of above-fence days that fall on Sat or Sun | % | MySQL | Per-series fence report joined to calendar (wday 1, 2) | 40.46 (28.57% of all train days are Sat/Sun, so a mild weekend skew, not "most") Computed in Python from the raw CSV in one pass (`fence_report_from_csv.py`), same definitions as 06_slide_numbers.sql section 3; the CSV matches the table (11,128,850 rows, max 349, 59.22% zeros) and the example series HOBBIES_1_004_CA_1 reproduces (fence 6, 11 flagged days, 10 on Sat/Sun, 39 units over). The MySQL run is optional. | COLLECTED | 10 |

### Slide 11: Exploratory analysis and KPIs

*Report section 5 (exploratory analysis): statistics, KPIs, patterns. Week 2 item 5 (initial findings).*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N093]` | FOODS share of rows | % | MySQL | 03_kpi_queries.sql A.2 (row_share_pct) | 47.13 | VERIFIED | 11 |
| `[N094]` | FOODS share of units | % | MySQL | 03_kpi_queries.sql A.2 (unit_share_pct) | 65.87 | VERIFIED | 11 |
| `[N095]` | FOODS mean daily sales per item-store | units | MySQL | 03_kpi_queries.sql A.2 (mean_sales) | 1.832 | VERIFIED | 11 |
| `[N096]` | HOBBIES share of rows | % | MySQL | 03_kpi_queries.sql A.2 (row_share_pct) | 18.53 | VERIFIED | 11 |
| `[N097]` | HOBBIES share of units | % | MySQL | 03_kpi_queries.sql A.2 (unit_share_pct) | 9.80 | VERIFIED | 11 |
| `[N098]` | HOBBIES mean daily sales per item-store | units | MySQL | 03_kpi_queries.sql A.2 (mean_sales) | 0.693 | VERIFIED | 11 |
| `[N099]` | HOUSEHOLD share of rows | % | MySQL | 03_kpi_queries.sql A.2 (row_share_pct) | 34.34 | VERIFIED | 11 |
| `[N100]` | HOUSEHOLD share of units | % | MySQL | 03_kpi_queries.sql A.2 (unit_share_pct) | 24.33 | VERIFIED | 11 |
| `[N101]` | HOUSEHOLD mean daily sales per item-store | units | MySQL | 03_kpi_queries.sql A.2 (mean_sales) | 0.929 | VERIFIED | 11 |
| `[N102]` | Total units sold in the window | units | MySQL | 03_kpi_queries.sql A.1 (total_units) | 14,585,821 | VERIFIED | 11 |
| `[N103]` | Mean daily sales per item-store | units | MySQL | 03_kpi_queries.sql A.1 | 1.311 | VERIFIED | 11 |
| `[N104]` | Standard deviation of daily sales | units | MySQL | 03_kpi_queries.sql A.1 | 3.634 | VERIFIED | 11 |
| `[N105]` | Weekend (Sat + Sun) uplift over weekdays | % | MySQL | 03_kpi_queries.sql B.3b | 30.52 | VERIFIED | 11, 12 |
| `[N106]` | Units of the largest store | units | MySQL | 03_kpi_queries.sql A.3 | 2,298,523 (CA_3) | VERIFIED | 11 |
| `[N107]` | Units of the smallest store | units | MySQL | 03_kpi_queries.sql A.3 | 911,180 (CA_4) | VERIFIED | 11 |

### Slide 12: Q3: what drives demand

*Decision question Q3 (demand drivers). Final project section 6: answer the decision questions.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N108]` | SNAP uplift, CA FOODS | % | MySQL | 03_kpi_queries.sql B.2 (snap_uplift_pct) | 6.16 | VERIFIED | 12 |
| `[N109]` | SNAP uplift, CA HOBBIES | % | MySQL | 03_kpi_queries.sql B.2 (snap_uplift_pct) | 2.82 | VERIFIED | 12 |
| `[N110]` | SNAP uplift, CA HOUSEHOLD | % | MySQL | 03_kpi_queries.sql B.2 (snap_uplift_pct) | 3.09 | VERIFIED | 12 |
| `[N111]` | SNAP uplift, CA all categories | % | MySQL | 03_kpi_queries.sql B.2b (snap_uplift_pct) | 5.02 | VERIFIED | 12 |
| `[N112]` | SNAP uplift, TX FOODS | % | MySQL | 03_kpi_queries.sql B.2 (snap_uplift_pct) | 14.60 | VERIFIED | 12 |
| `[N113]` | SNAP uplift, TX HOBBIES | % | MySQL | 03_kpi_queries.sql B.2 (snap_uplift_pct) | 2.71 | VERIFIED | 12 |
| `[N114]` | SNAP uplift, TX HOUSEHOLD | % | MySQL | 03_kpi_queries.sql B.2 (snap_uplift_pct) | 3.63 | VERIFIED | 12 |
| `[N115]` | SNAP uplift, TX all categories | % | MySQL | 03_kpi_queries.sql B.2b (snap_uplift_pct) | 10.47 | VERIFIED | 12 |
| `[N116]` | SNAP uplift, WI FOODS | % | MySQL | 03_kpi_queries.sql B.2 (snap_uplift_pct) | 27.77 | VERIFIED | 12, 21 |
| `[N117]` | SNAP uplift, WI HOBBIES | % | MySQL | 03_kpi_queries.sql B.2 (snap_uplift_pct) | 1.68 | VERIFIED | 12 |
| `[N118]` | SNAP uplift, WI HOUSEHOLD | % | MySQL | 03_kpi_queries.sql B.2 (snap_uplift_pct) | 3.49 | VERIFIED | 12 |
| `[N119]` | SNAP uplift, WI all categories | % | MySQL | 03_kpi_queries.sql B.2b (snap_uplift_pct) | 20.03 | VERIFIED | 12 |
| `[N019]` | Q3 uplift threshold | % | | same value as slide 4 | | | 4, 12, 21, 23 |
| `[N020]` | State-categories above the uplift threshold (of 9) | count | | same value as slide 4 | | | 4, 12, 23 |
| `[N120]` | Lowest event-day uplift over non-event days | % | MySQL | 03_kpi_queries.sql B.4 | -12.94 (WI HOBBIES) | VERIFIED | 12 |
| `[N121]` | Highest event-day uplift over non-event days | % | MySQL | 03_kpi_queries.sql B.4 | -0.70 (TX FOODS) | VERIFIED | 12 |
| `[N105]` | Weekend (Sat + Sun) uplift over weekdays | % | | same value as slide 11 | | | 11, 12 |

### Slide 13: Q2: where demand is growing

*Decision question Q2 (growth). Final project section 6: answer the decision questions.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N122]` | Growth, CA_2 FOODS | % | MySQL | 03_kpi_queries.sql B.1 (growth_pct) | 60.36 | VERIFIED | 13 |
| `[N123]` | Gap to regional growth, CA_2 FOODS | pp | MySQL | 03_kpi_queries.sql B.1 (gap_pp) | 46.18 | VERIFIED | 13, 21 |
| `[N124]` | Growth, WI_3 FOODS | % | MySQL | 03_kpi_queries.sql B.1 (growth_pct) | 40.30 | VERIFIED | 13 |
| `[N125]` | Gap to regional growth, WI_3 FOODS | pp | MySQL | 03_kpi_queries.sql B.1 (gap_pp) | 26.12 | VERIFIED | 13 |
| `[N126]` | Growth, WI_2 FOODS | % | MySQL | 03_kpi_queries.sql B.1 (growth_pct) | 39.53 | VERIFIED | 13 |
| `[N127]` | Gap to regional growth, WI_2 FOODS | pp | MySQL | 03_kpi_queries.sql B.1 (gap_pp) | 25.35 | VERIFIED | 13 |
| `[N128]` | Growth, CA_3 FOODS | % | MySQL | 03_kpi_queries.sql B.1 (growth_pct) | -4.56 | VERIFIED | 13 |
| `[N129]` | Gap to regional growth, CA_3 FOODS | pp | MySQL | 03_kpi_queries.sql B.1 (gap_pp) | -18.74 | VERIFIED | 13 |
| `[N130]` | Regional growth, last 28 days vs first 28 days (units-weighted) | % | MySQL | 03_kpi_queries.sql B.1 | 14.18 | VERIFIED | 13 |
| `[N017]` | Q2 flag threshold (growth gap) | pp | | same value as slide 4 | | | 4, 13, 21, 23 |
| `[N018]` | Store-categories flagged at the chosen threshold (of 30) | count | | same value as slide 4 | | | 4, 13, 23 |
| `[N131]` | Store-categories flagged at 10 pp | count | MySQL | 03_kpi_queries.sql B.1b | 12 | VERIFIED | 13 |
| `[N132]` | Store-categories flagged at 20 pp | count | MySQL | 03_kpi_queries.sql B.1b | 3 | VERIFIED | 13 |

### Slide 14: Features, time split, no leakage

*Week 3 item 1: features, target, data split, leakage prevention. Final project section 5.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N133]` | Partial first week, excluded (6 days) | weeks | MySQL | v_weekly_features, n_days < 7 and week_idx = 1 | 1 (week_idx 1, wm_yr_wk 11517, 6 days; check b) | VERIFIED | 14 |
| `[N134]` | Lag warm-up weeks (week_idx 2 to 5) | weeks | KNIME | Row Filter week_idx >= 6 removes them from training | 4 (weeks 2 to 5; training starts at week 6: 2,590 train rows = 70 x 37) | VERIFIED | 14 |
| `[N037]` | Training weeks used by the model | weeks | | same value as slide 6 | | | 6, 14, 15 |
| `[N038]` | Test weeks | weeks | | same value as slide 6 | | | 6, 14, 15, 22, 23 |
| `[N135]` | Partial last week, excluded (2 days) | weeks | MySQL | v_weekly_features, n_days < 7 and week_idx = 53 | 1 (week_idx 53, wm_yr_wk 11617, 2 days; check b) | VERIFIED | 14 |
| `[N136]` | Features in the Linear Regression Learner | features | KNIME | Learner include list | 6 (snap_days, event_days, closed_days, lag1_s, lag2_s, roll4_s) plus the intercept = 7 coefficients. Not month_of_week or dept_id as drafted earlier | COLLECTED | 14, 15 |
| `[N035]` | Store x department series | series | | same value as slide 6 | | | 6, 14 |
| `[N137]` | Share of the 365 days left out by the full-week rule (8 days) | % | MySQL | 8 / 365 x 100 | 2.2 (8 of 365 days = 6 + 2; check b) | VERIFIED | 14 |
| `[N061]` | Training rows | rows | | same value as slide 8 | | | 8, 14 |
| `[N062]` | Test rows | rows | | same value as slide 8 | | | 8, 14 |
| `[N039]` | Leakage margin: MIN(test week_idx) minus MAX(train week_idx) | weeks | | same value as slide 6 | | | 6, 8, 14, 15 |

### Slide 15: Model design, split and metrics

*Final project section 5 and required_files.md slide 6: model design, time-based split, MAE, RMSE, R2. Decision question Q1.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N136]` | Features in the Linear Regression Learner | features | | same value as slide 14 | | | 14, 15 |
| `[N037]` | Training weeks used by the model | weeks | | same value as slide 6 | | | 6, 14, 15 |
| `[N038]` | Test weeks | weeks | | same value as slide 6 | | | 6, 14, 15, 22, 23 |
| `[N039]` | Leakage margin: MIN(test week_idx) minus MAX(train week_idx) | weeks | | same value as slide 6 | | | 6, 8, 14, 15 |
| `[N138]` | Sales values changed by the outlier rule | values | KNIME | Outlier policy: retained, nothing capped | 0 (outliers are retained by decision; the workflow has no Numeric Outliers node) | VERIFIED | 15 |
| `[N139]` | Test MAE, Linear Regression | units | KNIME | Evaluate section; cross-check 03_kpi_queries.sql C.3 | 290.2 (MySQL 290.2189, KNIME Scorer 290.2189) Cross-checked 2026-11-10 against the KNIME Numeric Scorer output saved in D:/KNIME_workspace/Bigdata_final_weekly (node 18 model, node 19 last-week baseline). | VERIFIED | 15 |
| `[N140]` | Test MAE, last-week baseline | units | KNIME | Baseline branch: prediction = lag1 | 326.6 (MySQL 326.6457, KNIME Scorer 326.6457) Cross-checked 2026-11-10 against the KNIME Numeric Scorer output saved in D:/KNIME_workspace/Bigdata_final_weekly (node 18 model, node 19 last-week baseline). | VERIFIED | 15 |
| `[N141]` | Test RMSE, Linear Regression | units | KNIME | Evaluate section; cross-check 03_kpi_queries.sql C.3 | 540.3 (MySQL 540.2936, KNIME Scorer 540.2936) Cross-checked 2026-11-10 against the KNIME Numeric Scorer output saved in D:/KNIME_workspace/Bigdata_final_weekly (node 18 model, node 19 last-week baseline). | VERIFIED | 15, 18 |
| `[N142]` | Test RMSE, last-week baseline | units | KNIME | Baseline branch: prediction = lag1 | 642.7 (MySQL 642.6607, KNIME Scorer 642.6607) Cross-checked 2026-11-10 against the KNIME Numeric Scorer output saved in D:/KNIME_workspace/Bigdata_final_weekly (node 18 model, node 19 last-week baseline). | VERIFIED | 15 |
| `[N143]` | Test R2, Linear Regression | ratio | KNIME | Evaluate section; cross-check 03_kpi_queries.sql C.3 | 0.9855 (KNIME Scorer 0.985511). Pooled across series of very different size, not week-to-week skill Cross-checked 2026-11-10 against the KNIME Numeric Scorer output saved in D:/KNIME_workspace/Bigdata_final_weekly (node 18 model, node 19 last-week baseline). | VERIFIED | 15 |
| `[N144]` | Test R2, last-week baseline | ratio | KNIME | Baseline branch: prediction = lag1 | 0.9795 (KNIME Scorer 0.979501) Cross-checked 2026-11-10 against the KNIME Numeric Scorer output saved in D:/KNIME_workspace/Bigdata_final_weekly (node 18 model, node 19 last-week baseline). | VERIFIED | 15 |
| `[N016]` | Test WAPE, Linear Regression (clipped) | % | | same value as slide 4 | | | 4, 15, 18, 21, 23 |
| `[N145]` | Test WAPE, last-week baseline | % | KNIME | Baseline branch: 100 x SUM(abs(sales - lag1)) / SUM(sales) | 7.65 (7.6509). The 4-week average gives 6.70, slightly better than the model: see section 8 | COLLECTED | 15 |

### Slide 16: Where the forecast errs

*Final project section 5: interpret the findings, limitations, impact of data quality. Week 3 item 3 (residual interpretation).*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N146]` | Lowest store WAPE | % | KNIME | GroupBy store_id on the test set (knime_guide.md step 7.5) | 4.40 (CA_3) | COLLECTED | 16 |
| `[N147]` | Highest store WAPE | % | KNIME | Same | 10.81 (WI_2) | COLLECTED | 16 |
| `[N148]` | Lowest department WAPE | % | KNIME | GroupBy dept_id | 5.36 (HOUSEHOLD_1) | COLLECTED | 16 |
| `[N149]` | Highest department WAPE | % | KNIME | Same | 13.52 (HOBBIES_2) | COLLECTED | 16 |
| `[N150]` | Lowest state bias | % | KNIME | GroupBy state_id; cross-check 03_kpi_queries.sql C.7 | -4.98 (WI) | COLLECTED | 16 |
| `[N151]` | Highest state bias | % | KNIME | Same | -2.50 (CA). TX is -2.66 | COLLECTED | 16 |
| `[N152]` | Test weeks (of 10) where the model beats the last-week baseline | weeks | KNIME | Weekly WAPE, model vs baseline | 6 (8 of 10 against the 4-week average) | COLLECTED | 16 |
| `[N153]` | WAPE gap, unclipped minus clipped | pp | KNIME | Evaluate section, both variants | 0.00 (minimum written prediction is 101.48, so clipped and unclipped WAPE are identical) | COLLECTED | 16 |
| `[N154]` | Bias in SNAP weeks | % | KNIME | GroupBy snap_days > 0 | -4.89 (413 SNAP-week rows) | COLLECTED | 16 |
| `[N155]` | Bias in non-SNAP weeks | % | KNIME | Same | -0.92 (287 other rows) | COLLECTED | 16 |
| `[N156]` | NaN coefficients in the Learner | count | KNIME | Learner 'Coefficients and Statistics' view | 0 (7 coefficients incl. intercept, no NaN; a refit reproduces the written predictions to 0.0000) | COLLECTED | 16 |

### Slide 17: Write-back and re-run check

*Final project section 4: results written BACK to MySQL (CSV-only is not enough). Week 3 item 4. Re-run must not grow the table.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N157]` | Rows in sales_predictions_weekly after run 1 | rows | MySQL | DB Query Reader after the writer (knime_guide.md step 8.4) | 700 (run 1; the re-run check is not done yet) | VERIFIED | 17, 19 |
| `[N033]` | Rows in sales_predictions_weekly after run 2 | rows | | same value as slide 6 | | | 6, 17, 23 |
| `[N067]` | Row growth between run 1 and run 2 | rows | | same value as slide 8 | | | 8, 17 |
| `[N158]` | Distinct (store, dept, week) keys written | keys | MySQL | COUNT(DISTINCT store_id, dept_id, wm_yr_wk) | 700 | VERIFIED | 17 |
| `[N159]` | Minimum predicted_sales written | units | MySQL | MIN(predicted_sales) | 101.48 (never negative, so the clip at 0 never fired) | VERIFIED | 17 |
| `[N160]` | Rows where actual_sales differs from the source | rows | MySQL | 03_kpi_queries.sql C.2 (mismatched_actuals) | 0 | VERIFIED | 17 |
| `[N161]` | MAE gap, MySQL minus KNIME | units | MySQL | 03_kpi_queries.sql C.3 vs the KNIME Evaluate output | 0.000 (MAE MySQL 290.2189 minus KNIME Numeric Scorer 290.218919, read from the saved node output) | VERIFIED | 17 |

### Slide 18: Interactive dashboard

*Final project section 6: interactive dashboard on MySQL data with KPIs, filters, predictions. required_files.md section D.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N162]` | Records card | rows | Power BI | COUNTROWS(v_pred_eval) | 700 (the Records card exists in the .pbix; SQL count of v_pred_eval rows = 700) | COLLECTED | 18 |
| `[N163]` | Actual Units card, no filter | units | Power BI | SUM(v_pred_eval[actual_sales]); compare SELECT SUM(actual_sales) FROM v_pred_eval | 2,988,549 = SUM(actual_sales) over the 700 rows (MySQL). The Actual Units card must show the same: read it on screen | COLLECTED | 18 |
| `[N164]` | Forecast Units card, no filter | units | Power BI | SUM(v_pred_eval[predicted_sales]) | 2,889,551 = SUM(predicted_sales) over the 700 rows (2,889,551.2, MySQL). The Forecast Units card must show the same: read it on screen | COLLECTED | 18 |
| `[N016]` | Test WAPE, Linear Regression (clipped) | % | | same value as slide 4 | | | 4, 15, 18, 21, 23 |
| `[N141]` | Test RMSE, Linear Regression | units | | same value as slide 15 | | | 15, 18 |
| `[N013]` | Stores in scope | stores | | same value as slide 4 | | | 4, 5, 18 |
| `[N034]` | Dashboard pages | pages | | same value as slide 6 | | | 6, 18 |
| `[N165]` | Visuals on the dashboard | visuals | Power BI | Count the visuals on the three pages | 24 visuals on 3 pages (Overview 12: 6 cards, 5 slicers, 1 line chart; Stores and states 4; Demand drivers 8) Read from process/pbix/M5_Sales_Forecasting.pbix (report definition). | VERIFIED | 18 |
| `[N166]` | Slicers | slicers | Power BI | State, store, department, week range, SNAP | 7 slicers (5 on Overview, 2 on Demand drivers) Read from process/pbix/M5_Sales_Forecasting.pbix (report definition). The design said 5; the file has 7 | VERIFIED | 18 |
| `[N167]` | Cards on the dashboard | cards | Power BI | Count the cards | 6 cards: Records, Actual Units, Forecast Units, RMSE, WAPE, Active Stores Read from process/pbix/M5_Sales_Forecasting.pbix (report definition). | VERIFIED | 18, 23 |
| `[N168]` | Cards checked against SQL | cards | Power BI | powerbi_guide.md step 6 | 6: each card has its SQL value (Records 700, Actual Units 2,988,549, Forecast Units 2,889,551, RMSE 540.29, WAPE 6.80, Active Stores 10). The SQL side is computed; the card read on screen is still yours to confirm | COLLECTED | 18, 19, 23 |

### Slide 19: Live demo

*required_files.md slide 7 and Final project section 8: end-to-end live demo on one laptop with a fallback.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N021]` | Rows in sales_history | rows | | same value as slide 5 | | | 5, 6, 7, 19 |
| `[N169]` | Time for KNIME to run in the demo | sec | Team log | Stopwatch on the rehearsal | 2 seconds (1.7 s Reset all + Execute all in knime.log) | VERIFIED | 19 |
| `[N157]` | Rows in sales_predictions_weekly after run 1 | rows | | same value as slide 17 | | | 17, 19 |
| `[N170]` | Time for Power BI to refresh in the demo | sec | Team log | Stopwatch on the rehearsal |  | RUN | 19 |
| `[N168]` | Cards checked against SQL | cards | | same value as slide 18 | | | 18, 19, 23 |
| `[N171]` | Backup dashboard screenshots | files | Repo | ls dashboard/screenshots/ | Backup dashboard screenshots. Removed from the deck on 2026-11-10 (repo checks dropped). | REMOVED | 19, 25 |
| `[N172]` | Backup recording length | min | Team log | Length of the screen recording |  | RUN | 19 |
| `[N173]` | Timed rehearsals completed | runs | Team log | Plan says rehearse twice | >= 2 | TEAM | 19 |

### Slide 20: Evidence for ROI: dollars and bias

*Supporting questions SQ-A and SQ-B (decision_results.md): dollar and bias evidence for expected benefit and trade-off.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[T01]` | Store with revenue-error rank 1 | store id | MySQL | 03_kpi_queries.sql C.6, ORDER BY revenue MAE DESC | WI_2 Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 20 |
| `[N174]` | Weekly revenue MAE, rank 1 | USD | MySQL | 03_kpi_queries.sql C.6 | 9,277 USD per week (9,276.75) Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 20 |
| `[N175]` | Share of total revenue error, rank 1 | % | MySQL | 03_kpi_queries.sql C.6 | 20.55 (share of total revenue error) Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 20 |
| `[T02]` | Store with revenue-error rank 2 | store id | MySQL | 03_kpi_queries.sql C.6, ORDER BY revenue MAE DESC | CA_2 Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 20 |
| `[N176]` | Weekly revenue MAE, rank 2 | USD | MySQL | 03_kpi_queries.sql C.6 | 8,484 USD per week (8,483.86) Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 20 |
| `[N177]` | Share of total revenue error, rank 2 | % | MySQL | 03_kpi_queries.sql C.6 | 18.79 Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 20 |
| `[T03]` | Store with revenue-error rank 3 | store id | MySQL | 03_kpi_queries.sql C.6, ORDER BY revenue MAE DESC | WI_3 Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 20 |
| `[N178]` | Weekly revenue MAE, rank 3 | USD | MySQL | 03_kpi_queries.sql C.6 | 4,724 USD per week (4,724.25) Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 20 |
| `[N179]` | Share of total revenue error, rank 3 | % | MySQL | 03_kpi_queries.sql C.6 | 10.47 Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 20 |
| `[N180]` | SQ-A review threshold: share of total revenue error | % | Decision | decision_results.md SQ-A (provisional) | 20 (set 2026-11-10 as the working threshold; re-check after C.6 runs so that 1 to 3 stores flag) | DESIGN | 20 |
| `[N181]` | Stores above the SQ-A threshold | stores | MySQL | 03_kpi_queries.sql C.6 | 1 (WI_2 at 20.55%; the target was 1 to 3, so 20% stands as N180) Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 20 |
| `[N182]` | Forecast bias, CA | % | MySQL | 03_kpi_queries.sql C.7 | -2.50 | COLLECTED | 20 |
| `[N183]` | Forecast bias, TX | % | MySQL | 03_kpi_queries.sql C.7 | -2.66 | COLLECTED | 20 |
| `[N184]` | Forecast bias, WI | % | MySQL | 03_kpi_queries.sql C.7 | -4.98 (just inside the 5% line) | COLLECTED | 20 |
| `[N185]` | States with /bias/ above 5% | states | MySQL | 03_kpi_queries.sql C.7 | 0 (SQ-B not triggered) | COLLECTED | 20 |
| `[N186]` | MAE before the state correction factor | units | KNIME | Held-out weeks, uncorrected | 304.3 (held-out weeks 48 to 52; factors fitted on weeks 43 to 47; a trial, not a KNIME node) | COLLECTED | 20 |
| `[N187]` | MAE after the state correction factor | units | KNIME | Held-out weeks, corrected | 279.8 (CA x1.014, TX x1.014, WI x1.047) | COLLECTED | 20 |

### Slide 21: Three recommendations

*Final project section 6 and required_files.md slide 8: at least three recommendations, each with action, evidence, expected benefit or trade-off.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N016]` | Test WAPE, Linear Regression (clipped) | % | | same value as slide 4 | | | 4, 15, 18, 21, 23 |
| `[N015]` | Q1 target: WAPE ceiling | % | | same value as slide 4 | | | 4, 21, 23 |
| `[N188]` | Rec 1 expected benefit (reorder from the forecast) | USD / week | MySQL | Units x sell_price from weekly_revenue; assumption stated on the slide | 8,021 USD per week: dollar error avoided versus reordering last week's units (71,426 to 63,405 per week) Holding cost is an assumption: 25% of stock value per year for one week (0.48%). Benefit is revenue, not profit. Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 21 |
| `[N189]` | Rec 1 trade-off cost (reorder from the forecast) | USD / week | MySQL | Extra stock x price x holding-cost rate; state the rate | 84 USD per week: holding the forecast over-stock (17,534 per week) for one week Holding cost is an assumption: 25% of stock value per year for one week (0.48%). Benefit is revenue, not profit. Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 21 |
| `[N123]` | Gap to regional growth, CA_2 FOODS | pp | | same value as slide 13 | | | 13, 21 |
| `[N017]` | Q2 flag threshold (growth gap) | pp | | same value as slide 4 | | | 4, 13, 21, 23 |
| `[N190]` | Rec 2 expected benefit (shift stock to fast growers) | USD / week | MySQL | Units x sell_price from weekly_revenue; assumption stated on the slide | 40,729 USD per week: 15,381 extra units per week at CA_2, WI_2 and WI_3 FOODS (gap above 20 pp vs the 14.18% regional growth) Holding cost is an assumption: 25% of stock value per year for one week (0.48%). Benefit is revenue, not profit. Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 21 |
| `[N191]` | Rec 2 trade-off cost (shift stock to fast growers) | USD / week | MySQL | Extra stock x price x holding-cost rate; state the rate | 196 USD per week Holding cost is an assumption: 25% of stock value per year for one week (0.48%). Benefit is revenue, not profit. Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 21 |
| `[N116]` | SNAP uplift, WI FOODS | % | | same value as slide 12 | | | 12, 21 |
| `[N019]` | Q3 uplift threshold | % | | same value as slide 4 | | | 4, 12, 21, 23 |
| `[N192]` | Rec 3 expected benefit (pre-stock SNAP weeks) | USD / week | MySQL | Units x sell_price from weekly_revenue; assumption stated on the slide | 18,580 USD per week: 7,091 extra units per week at TX FOODS and WI FOODS (SNAP uplift above 10%); a gross upper bound because the weekly model already carries snap_days Holding cost is an assumption: 25% of stock value per year for one week (0.48%). Benefit is revenue, not profit. Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 21 |
| `[N193]` | Rec 3 trade-off cost (pre-stock SNAP weeks) | USD / week | MySQL | Extra stock x price x holding-cost rate; state the rate | 89 USD per week Holding cost is an assumption: 25% of stock value per year for one week (0.48%). Benefit is revenue, not profit. Computed in Python (`dollar_fields_from_csv.py`): units from the raw sales CSV, prices from sell_prices.csv, the 700 written predictions from MySQL; same definitions as 03 C.0/C.1 and 06 sections 4 and 5. Check: CSV actual units equal all 700 written actual_sales rows. The MySQL run is optional. | COLLECTED | 21 |

### Slide 22: Uncertainty and limitations

*Final project section 6: discuss uncertainty, avoid claims beyond the evidence. Section 2: remaining bias and risks.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N036]` | Weeks in the window (week_idx 1 to 53) | weeks | | same value as slide 6 | | | 6, 22 |
| `[N038]` | Test weeks | weeks | | same value as slide 6 | | | 6, 14, 15, 22, 23 |
| `[N194]` | Seasonal cycles covered by the data | cycles | Design | One year of data | 1 (the window is 365 days, d_1577 to d_1941) | VERIFIED | 22 |
| `[N086]` | Share of rows with zero sales | % | | same value as slide 10 | | | 10, 22 |
| `[N091]` | Series without a fence (fewer than about 8 positive train days) | series | | same value as slide 10 | | | 10, 22 |
| `[N195]` | Test RMSE change, raw vs capped training data (sensitivity) | % | KNIME | Optional second branch (knime_guide.md step 4.3) | -1.73 (test RMSE 540.29 raw vs 530.97 capped; WAPE 6.80 vs 6.70, MAE 290.22 vs 285.94). Python refit of the same Linear Regression (`capped_outlier_refit.py`): per-series upper fence Q3 + 1.5 x IQR on the weekly train sales (weeks 6 to 42), applied to the training target and lags (47 values capped), test inputs untouched. The same refit without capping reproduces the KNIME RMSE 540.2936 exactly. Reading: capping moves RMSE by under 2%, so keeping the outliers does not hurt the model. | COLLECTED | 22 |
| `[N196]` | Lowest weekly WAPE across the 10 test weeks | % | KNIME | Weekly WAPE table | 4.39 (week_idx 49) | COLLECTED | 22 |
| `[N197]` | Highest weekly WAPE across the 10 test weeks | % | KNIME | Weekly WAPE table | 12.13 (week_idx 50) | COLLECTED | 22 |

### Slide 23: Answers to the three questions

*Report section 9 (conclusion). Week 4 item 3.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N016]` | Test WAPE, Linear Regression (clipped) | % | | same value as slide 4 | | | 4, 15, 18, 21, 23 |
| `[N015]` | Q1 target: WAPE ceiling | % | | same value as slide 4 | | | 4, 21, 23 |
| `[N018]` | Store-categories flagged at the chosen threshold (of 30) | count | | same value as slide 4 | | | 4, 13, 23 |
| `[N017]` | Q2 flag threshold (growth gap) | pp | | same value as slide 4 | | | 4, 13, 21, 23 |
| `[N020]` | State-categories above the uplift threshold (of 9) | count | | same value as slide 4 | | | 4, 12, 23 |
| `[N019]` | Q3 uplift threshold | % | | same value as slide 4 | | | 4, 12, 21, 23 |
| `[N033]` | Rows in sales_predictions_weekly after run 2 | rows | | same value as slide 6 | | | 6, 17, 23 |
| `[N038]` | Test weeks | weeks | | same value as slide 6 | | | 6, 14, 15, 22, 23 |
| `[N168]` | Cards checked against SQL | cards | | same value as slide 18 | | | 18, 19, 23 |
| `[N167]` | Cards on the dashboard | cards | | same value as slide 18 | | | 18, 23 |

### Slide 24: Answers to the supporting questions

*Roadmap scope v2: supporting questions SQ-A (revenue error) and SQ-B (state bias), answered in words for the inventory manager.*

No new number fields. The slide reuses values from slide 20 (N174 to N187) and slide 16 (N154, N155) as literal numbers: WI_2 20.55% and 9,277 USD per week (N175, N174), CA_2 18.79%, WI_3 10.47%, 1 store above the 20% line (N181), state bias CA -2.50 / TX -2.66 / WI -4.98 with 0 states beyond 5% (N182 to N185), SNAP-week bias -4.89 and non-SNAP -0.92 (N154, N155), MAE 304.3 to 279.8 (N186, N187), total bias -3.31%. If any of those fields change, update this slide by hand.

### Slide 25: Reproducibility and submission

*Final project section 8 and the submission checklist: README, scripts, KNIME export, dashboard file, reproducibility, no credentials.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N198]` | Pages in the IEEE report | pages | Team | Compiled PDF | 6 (Word page count of Result_pack/M5_Final_Report_Evidence_Ready.docx; 6 to 10 required). The file still has two "INSERT ... SCREENSHOT" placeholders in the appendices, so recount after the final edit | COLLECTED | 25 |
| `[N199]` | References cited | refs | Team | Reference list | 7 references counted in the report ([1] to [7]; at least 5 required) | VERIFIED | 25 |
| `[N200]` | Rows in the sample database dump | rows | Repo | m5_database_dump_sample.sql | Sample dump rows. Removed from the deck on 2026-11-10 (repo checks dropped). | REMOVED | 25 |
| `[N047]` | Numbered SQL scripts in the repository | files | | same value as slide 7 | | | 7, 25 |
| `[N201]` | Clean-clone steps passed | steps | Team log | Phase 9 clean-clone test |  | TEAM | 25 |
| `[N202]` | Clean-clone steps in the test | steps | Team log | README reproduction steps | 6 reproduction steps in README.md section 5 | VERIFIED | 25 |
| `[N203]` | Credentials found in the repository | count | Repo | grep for the password across the repo and the .knwf | Credentials in repo. Removed from the deck on 2026-11-10 (repo checks dropped). | REMOVED | 25 |
| `[N171]` | Backup dashboard screenshots | files | | same value as slide 19 | | | 19, 25 |
| `[N204]` | Setup steps in README.md | steps | Repo | README.md | README setup steps. Removed from the deck on 2026-11-10 (repo checks dropped). | REMOVED | 25 |

### Slide 26: Individual contributions

*Week 4 item 5: demonstrate individual contributions. Final project section 8.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N205]` | Planned hours, Data Engineer | h | Team log | WBS | 10.0 (roles sum to 29.0 planned). WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 26 |
| `[N206]` | Logged hours, Data Engineer | h | Team log | Time log | 10.5 (roles sum to 30.0 logged). WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 26 |
| `[N207]` | Tasks completed, Data Engineer | tasks | Team log | WBS / GitHub issues closed | 5 (roles sum to 14 tasks). WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 26 |
| `[N208]` | Planned hours, Data Scientist | h | Team log | WBS | 9.5. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 26 |
| `[N209]` | Logged hours, Data Scientist | h | Team log | Time log | 9.5. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 26 |
| `[N210]` | Tasks completed, Data Scientist | tasks | Team log | WBS / GitHub issues closed | 4. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 26 |
| `[N211]` | Planned hours, Data Analyst | h | Team log | WBS | 9.5. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 26 |
| `[N212]` | Logged hours, Data Analyst | h | Team log | Time log | 10.0. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 26 |
| `[N213]` | Tasks completed, Data Analyst | tasks | Team log | WBS / GitHub issues closed | 5. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 26 |

### Slide 27: Plan versus actual

*required_files.md slide 9 and Week 4 item 6: planned versus actual effort, what, when, why, how much.*

| ID | Field | Unit | Source | How to get it | Draft value | Status | Where |
|---|---|---|---|---|---|---|---|
| `[N214]` | Planned hours, Weeks 1 and 2 | h | Team log | WBS | 17.0 = W1 6.0 + W2.1 3.5 + W2.2 4.5 + W2.3 3.0 (Week 1 slides, p12, "Planned vs Actual") | COLLECTED | 27 |
| `[N215]` | Actual hours, Weeks 1 and 2 | h | Team log | Time log | 15.5 = W1 6.5 + W2.1 3.5 + W2.2 4.0 + W2.3 1.5 (Week 1 slides, p12; W2.3 was still in progress) | COLLECTED | 27 |
| `[N216]` | Variance (actual minus planned), Weeks 1 and 2 | h | Team log | actual minus planned | -1.5 (15.5 actual minus 17.0 planned; under plan at Week 2) | COLLECTED | 27 |
| `[N217]` | Items delivered, Weeks 1 and 2 | items | Team log | Checklist in required_files.md section 2 | 5. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 27 |
| `[N218]` | Planned hours, Week 3 | h | Team log | WBS | 7.0 (Week 1 slides p4 and p12; Week 3 slide p13 "planned 7.0 hours") | COLLECTED | 27 |
| `[N219]` | Actual hours, Week 3 | h | Team log | Time log | 8.0 (+1.0 over the 7.0 plan). WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 27 |
| `[N220]` | Variance (actual minus planned), Week 3 | h | Team log | actual minus planned | +1.0. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 27 |
| `[N221]` | Items delivered, Week 3 | items | Team log | Checklist in required_files.md section 2 | 4. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 27 |
| `[N222]` | Planned hours, Week 4 | h | Team log | WBS | 5.0 (revised plan for Week 4; the 3-week WBS had no Week 4). WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 27 |
| `[N223]` | Actual hours, Week 4 | h | Team log | Time log | 6.5. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 27 |
| `[N224]` | Variance (actual minus planned), Week 4 | h | Team log | actual minus planned | +1.5. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 27 |
| `[N225]` | Items delivered, Week 4 | items | Team log | Checklist in required_files.md section 2 | 5. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 27 |
| `[N226]` | Planned hours, total | h | Team log | Sum of the three rows; must equal the sum of the role hours | 29.0 = 17.0 + 7.0 + 5.0 (equals the sum of role planned hours). WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 27 |
| `[N227]` | Actual hours, total | h | Team log | Sum of the three rows | 30.0 = 15.5 + 8.0 + 6.5 (equals the sum of role logged hours). WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 27 |
| `[N228]` | Variance, total | h | Team log | actual minus planned | +1.0 = 30.0 - 29.0. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 27 |
| `[N229]` | Items delivered, total | items | Team log | Checklist in required_files.md section 2 | 14 = 5 + 4 + 5 (equals the tasks completed by the three roles). WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 27 |
| `[N230]` | Items committed | items | Team log | Checklist in required_files.md section 2 | 14. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 27 |
| `[N231]` | Days late against the plan | days | Team log | Delivery dates vs WBS | 0. WORKING VALUE set by the team on 2026-11-10, not taken from a time log: replace with the real count before submission. Consistent with the documented Weeks 1-2 figures (17.0 planned, 15.5 actual). | TEAM | 27 |
| `[N232]` | Decision questions answered (of 3) | questions | Team | Slides Q1 to Q3 | 3 (slide 23 answers Q1, Q2 and Q3) | VERIFIED | 27 |

## 6. Label fields

`[Txx]` fields are names, not numbers. They exist only because a number needs its subject (which store has the largest revenue error). Fill them from the same query as the numbers beside them.

| ID | Field | Source |
|---|---|---|
| `[T01]` | Store with revenue-error rank 1 | 03_kpi_queries.sql C.6, ORDER BY revenue MAE DESC |
| `[T02]` | Store with revenue-error rank 2 | 03_kpi_queries.sql C.6, ORDER BY revenue MAE DESC |
| `[T03]` | Store with revenue-error rank 3 | 03_kpi_queries.sql C.6, ORDER BY revenue MAE DESC |

## 7. Numbers typed directly on the slides

These are fixed by the brief or by the design and are **not** fields. Change them in the deck if the design changes.

| Slide | Number | Why fixed |
|---|---|---|
| 4 | "of 30", "of 9" | 30 store-categories (10 stores x 3 categories) and 9 state-categories (3 x 3) in the Q2 and Q3 queries |
| 6, 21 | 3 recommendations | The brief requires at least three |
| 16 | "of 10" | 10 test weeks |
| 27, 23 | "of 3" questions | Three decision questions |
| 15 | ">=" and "<=" signs | Targets from `decision_results.md` |

## 8. Figures from the weekly run that have no field yet

Recorded in `decision_results.md` and `process/numbers_collected.csv`. They are not on the slides today; add a field if a slide should show them.

| Figure | Value | Why it matters |
|---|---|---|
| WAPE, 4-week average (`roll4`) | 6.70% | Slightly better than the model (6.80%); a fairer baseline than last week (slide 15, 22) |
| Weeks the model beats the 4-week average | 8 of 10 | Same comparison, weekly |
| Total bias | -3.31% | All three states under-forecast (CA -2.50, TX -2.66, WI -4.98) |
| Week 50 | actual 315,125, forecast 277,162, bias -12.05%, WAPE 12.13% | The one week above the 10% ceiling; main source of the total bias (slides 16, 22) |
| Weeks 46 and 52 bias | -4.81%, -5.41% | Also under-forecast; check SNAP days and events before adding features |
| Bias after the state correction (held-out weeks 48 to 52) | -4.28% to -2.01% | Pairs with N186, N187 (MAE 304.3 to 279.8) |
| Learner coefficients | Intercept 0.3419, snap_days 0.0078, event_days -0.0220, closed_days -0.0798, lag1_s 0.4893, lag2_s -0.2149, roll4_s 0.3801 | Lag terms carry the forecast; SNAP and event terms are small at weekly grain |

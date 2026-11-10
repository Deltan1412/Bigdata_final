# Section 6: Machine Learning (Linear Regression Sales Forecasting)

**Course:** Big Data Analytics (Final Project 2026), VNUK
**Role:** Person 2 (B, Data Scientist) | Week 2 Deliverable
**Pipeline stage:** MySQL → KNIME (cleaning, model) → MySQL (`sales_predictions`) → Dashboard

> Items marked **[TBD]** are values from the KNIME run that must be filled in before submission. None are invented here.

---

## 1. Task and Decision Link

- **Task:** supervised regression. Predict daily unit `sales` of an item in a store.
- **Decision supported:** inventory planning. Forecast demand per day so stock can be ordered ahead of high-demand days (holidays, SNAP days).
- **Why Linear Regression:** it is one of the models covered in class, it is fast, and its coefficients are easy to read for a business audience.

## 2. Data Used

| Item | Value |
| :--- | :--- |
| Source tables | `sales_history` JOIN `calendar` (MySQL, database `bigdataprj`) |
| Day range in table | `d_1577` to `d_1941` (365 days) |
| Sample | 1% of item-store series (`WHERE CRC32(s.id) % 100 = 0`), all days kept per series |
| Rows read / after cleaning | **[TBD]** / **[TBD]** |
| Cleaning | KNIME `Missing Value` and `Numeric Outliers` (IQR, k = 1.5, upper bound only), as in Week 1 |
| Event days | 30 of 365 calendar days have an event (holiday) |

The 1% sample was used to keep KNIME memory use and MySQL write time low. The sampling is by series, so each series keeps its complete time range. The pipeline is unchanged on the full table except for removing the `WHERE` line.

## 3. Features and Target

- **Target:** `sales`.
- **Features:**
  - `day_num`: numeric day index, from `d_N` (trend term).
  - `wday`, `month`: calendar position.
  - `is_holiday`: 1 if `event_name_1` or `event_name_2` is non-empty, else 0.
  - `snap`: 1 if SNAP benefits are active that day for the row's state.
  - `cat_id`: product category, dummy-coded by the Learner.
- **Excluded:** `id`, `item_id` (about 3,000 values would create thousands of dummy columns), `dept_id`, `store_id`, `state_id`, `day` and `date` (duplicate `day_num`), `year` (nearly constant over one year).

Model form:

```
sales_hat = b0 + b1*day_num + b2*wday + b3*month + b4*is_holiday + b5*snap + sum_k g_k*cat_k
```

Ordinary Least Squares fits the coefficients by minimising the sum of squared residuals, `sum (y_i - y_hat_i)^2`.

## 4. Train/Test Design (Leakage Control)

A **time-based split** is used, not a random one, because the model is meant to forecast the future. A random split would place neighbouring days in both sets.

- **Train:** `day_num <= 1868` (days 1577–1868, 292 days).
- **Test:** `day_num > 1868` (days 1869–1941, 73 days).
- The cutoff is `min + 0.8 * (max - min) = 1577 + 0.8 * 364 = 1868.2`, rounded to 1868.
- Implemented with the KNIME `Rule-based Row Splitter` (rule `$day_num$ <= 1868 => TRUE`).
- Train / test rows: **[TBD]** / **[TBD]** (share of train: **[TBD]** %).
- Check: minimum `day_num` in test is greater than maximum in train.

## 5. KNIME Workflow

```
MySQL Connector → DB Query Reader → Missing Value → Numeric Outliers
   → Rule-based Row Splitter
        ├─ train → Linear Regression Learner ─┐
        └─ test  → Regression Predictor ◄─────┘
   → Math Formula (clip predictions at 0 → predicted_sales)
        ├─ Math Formula (abs_err, sq_err) → GroupBy → Math Formula (RMSE, R²)
        └─ Column Rename → Constant Value Column Appender → Column Filter → DB Writer
```

Write-back to `sales_predictions` (append mode):

| KNIME column | MySQL column |
| :--- | :--- |
| `item_id` | `item_id` |
| `store_id` | `store_id` |
| `day` (renamed) | `forecast_day` |
| `predicted_sales` | `predicted_sales` |
| `sales` (renamed) | `actual_sales` |
| constant `LinearRegression_v1` | `model_name` |

`id` and `prediction_date` are filled by MySQL.

Verification after write-back: row count equals the test-set size (**[TBD]**), and `MIN(predicted_sales) >= 0`.

## 6. Evaluation Metrics

Negative predictions are clipped to 0 because sales cannot be negative. Metrics are computed on the **test set**.

- **MAE** = mean(|y − ŷ|): average absolute error in units per day.
- **RMSE** = sqrt(mean((y − ŷ)²)): like MAE but penalises large errors more.
- **R²** = 1 − MSE / Var(y): share of variance explained. R² uses the sample variance of `sales`, a negligible difference at this row count.
- **MAPE is not reported.** It divides by the true value, which is 0 for most rows, so it is undefined (KNIME returns NaN).

| Metric | Test value |
| :--- | :---: |
| MAE | **[TBD]** |
| RMSE | **[TBD]** |
| R² | **[TBD]** |

## 7. Coefficients and Interpretation

| Feature | Coefficient | Reading |
| :--- | :---: | :--- |
| Intercept | **[TBD]** | |
| `day_num` | **[TBD]** | change in daily sales per day (trend) |
| `wday` | **[TBD]** | |
| `month` | **[TBD]** | |
| `is_holiday` | **[TBD]** | effect of an event day |
| `snap` | **[TBD]** | effect of a SNAP day |
| `cat_id` dummies | **[TBD]** | category differences |

**[TBD]** After the run, add 2 to 3 sentences on the sign and size of the holiday and SNAP effects, and what they mean for stock planning. Do not claim causality, because the model shows association only.

## 8. Limitations and Risks

1. **Zero-inflated demand.** Most rows have sales 0 or 1. Linear Regression can return negative or fractional values, so predictions are clipped at 0. R² is expected to be low for this kind of data and should be read together with MAE.
2. **Optimistic scores from cleaning.** Week 1 removed rows with `sales` above the IQR upper bound (2 units). The test set was also cleaned, so scores do not describe the removed high-demand days (for example promotions).
3. **Mild leakage in cleaning.** The IQR cutoff was computed on all rows, including the test period. A stricter design would compute it on training rows only.
4. **Sample.** Only 1% of series and one year of data. Seasonality across years cannot be learned, and the results may not hold for every item.
5. **Model simplicity.** There are no lag, price or item-level features, and the effects are linear and additive.
6. **Holiday accuracy.** There are only 30 event days in the year, so the `is_holiday` estimate rests on few distinct days.

## 9. Issues Encountered During the Run

- The first sample used `LIMIT 100000`, which covered only 4 days (`d_1577`–`d_1580`). Day-level features were then collinear and KNIME dropped `is_holiday` as redundant. The query was changed to the series sample above, which covers the full year.
- The `Numeric Scorer` returned NaN for MAPE and no MAE. MAE, RMSE and R² were computed with Math Formula and GroupBy nodes instead.

## 10. Deliverable Status (Week 2, Person 2)

- [ ] Linear Regression Learner and Regression Predictor run on the cleaned data
- [ ] Predictions written to MySQL `sales_predictions` (**[TBD]** rows)
- [ ] `predictions.sql` dump sent to Person 3 (C)
- [ ] KNIME workflow exported as `.knwf` and sent to Person 1 (A)
- [ ] Metrics and coefficients filled in above

# Titanic Data ELT Pipeline (Python + MySQL)

An end-to-end ELT (Extract, Load, Transform) data engineering pipeline built according to production database-first design principles.

---

## 💡 Scenario & Architectural Philosophy: ELT vs. ETL

> **Scenario**: *"You are a data engineer. Your manager says: Don't clean the data in Python. Load the raw data into MySQL first, then do all the cleaning and analysis inside the database using SQL."*

### Why ELT?
In traditional **ETL (Extract, Transform, Load)**:
1. Data is transformed in Python before being saved.
2. If cleaning logic changes or bugs occur, the original raw state is lost unless re-extracted from source systems.
3. Compute is offloaded to application memory rather than leveraging powerful database query engines.

In **ELT (Extract, Load, Transform)**:
1. **Raw Preservation**: Raw data is stored untouched in `raw_titanic` with audit metadata (`load_timestamp`, `batch_id`).
2. **Replayability**: If transformation rules change, you can re-run SQL transformations without re-extracting from the source.
3. **Database Native**: High-performance window functions (`AVG() OVER ()`, `ROW_NUMBER()`, `NTILE()`) and set-based operations perform cleaning directly inside the database engine.
4. **Separation of Concerns**: Python is strictly restricted to extraction, loading raw data, and orchestrating SQL file execution.

---

## 📁 Project Structure

```
titanic_elt_pipeline/
├── config.py                 # MySQL database connection settings & helpers
├── extract_load.py           # Part 1: Extract from seaborn & Load raw to MySQL
├── run_elt.py                # Part 6: Full pipeline orchestrator & DQ reporter
├── sql/
│   ├── 01_staging.sql        # Part 2: Rename, type-cast, lowercase, surrogate key
│   ├── 02_transformation.sql # Part 3: Impute missing values, feature engineering
│   ├── 03_analytics.sql      # Part 4: 3 Analytical Views (survival rates, top fares)
│   └── 04_data_quality.sql   # Part 5: 5 Data quality checks into `dq_results`
└── README.md                 # Full documentation
```

---

## 🛠️ Pipeline Layers & Implementation Details

### Part 1: Extract & Load (`extract_load.py`)
- Extracts raw Titanic dataset using `seaborn.load_dataset('titanic')` (891 rows, 15 columns).
- Appends two audit columns:
  - `load_timestamp`: Timestamp when extraction occurred.
  - `batch_id`: Unique batch identifier (`batch_<timestamp>_<uuid>`).
- Loads into `raw_titanic` table untouched, retaining all NULLs and original data types.
- **Idempotency**: Configured with `if_exists='replace'` ensuring repeated runs never create duplicate rows.

### Part 2: Staging Layer (`sql/01_staging.sql`)
Creates `stg_titanic` from `raw_titanic`:
1. **Renames columns**: `pclass` → `passenger_class`, `class` → `ticket_class`, `who` → `passenger_type`, etc.
2. **Text Normalization**: Standardizes all textual columns to lowercase (`LOWER(TRIM(...))`).
3. **Type Casting**: Explicitly casts integers (`SIGNED`), decimals (`DECIMAL(5,2)`, `DECIMAL(10,4)`).
4. **Surrogate Key**: Generates `passenger_id` using `ROW_NUMBER() OVER ()`.

### Part 3: Transformation Layer (`sql/02_transformation.sql`)
Creates `clean_passengers` from `stg_titanic`:
1. **Age Imputation**: Fills missing ages using window function average of passengers with the same class and sex:
   ```sql
   COALESCE(s.age, ROUND(AVG(s.age) OVER (PARTITION BY s.passenger_class, s.sex), 2))
   ```
2. **Embarked Imputation**: Fills missing port with the mode (most common value, `'s'`):
   ```sql
   WITH mode_embarked AS (
       SELECT embarked FROM stg_titanic WHERE embarked IS NOT NULL GROUP BY embarked ORDER BY COUNT(*) DESC LIMIT 1
   ) ... COALESCE(s.embarked, m.embarked)
   ```
3. **Column Pruning**: Completely removes `deck` and `embark_town`.
4. **Sex Encoding**: Encodes `sex` as `0` (`male`) and `1` (`female`).
5. **Age Grouping**: Categorizes continuous age without boundary gaps:
   - `Child`: 0–12
   - `Teen`: 13–19
   - `Adult`: 20–59
   - `Senior`: 60+
6. **Family Metrics**:
   - `family_size = sibsp + parch + 1`
   - `is_alone = 1` if `family_size = 1`, else `0`.
7. **Fare Category**: Uses `NTILE(4) OVER (ORDER BY s.fare ASC)` to partition into quartiles:
   - `Low` (Q1), `Medium` (Q2), `High` (Q3), `Premium` (Q4).

### Part 4: Analytics Layer (`sql/03_analytics.sql`)
Generates 3 views:
1. `vw_survival_by_class_sex`: Total passengers, survivors, and survival rate % by passenger class and gender.
2. `vw_survival_by_age_group`: Total passengers, survivors, and survival rate % across age groups.
3. `vw_top_3_fares_by_class`: Top 3 highest fare-paying passengers per class using `ROW_NUMBER() OVER (PARTITION BY passenger_class ORDER BY fare DESC)`.

### Part 5: Data Quality Checks (`sql/04_data_quality.sql`)
Records results into table `dq_results` (`check_name`, `status`, `checked_at`):
| # | Check Name | Logic | Status |
|---|---|---|---|
| 1 | Row count of raw_titanic = row count of clean_passengers | `(SELECT COUNT(*) FROM raw_titanic) = (SELECT COUNT(*) FROM clean_passengers)` | **PASS** |
| 2 | No nulls in age, embarked | `COUNT(*) = 0 WHERE age IS NULL OR embarked IS NULL` | **PASS** |
| 3 | No duplicate passengers | `COUNT(*) = COUNT(DISTINCT passenger_id)` | **PASS** |
| 4 | Age is between 0 and 100 | `COUNT(*) = 0 WHERE age < 0 OR age > 100` | **PASS** |
| 5 | sex has only 0 or 1 | `COUNT(*) = 0 WHERE sex NOT IN (0, 1) OR sex IS NULL` | **PASS** |

### Part 6: Automation (`run_elt.py`)
- Orchestrates the full extract, load, and SQL transformations.
- Executes SQL scripts in sequence: `01_staging.sql` → `02_transformation.sql` → `03_analytics.sql` → `04_data_quality.sql`.
- Queries `dq_results` and prints formatted `[PASS]` or `[FAIL]` status for each test.
- Displays an analytics summary preview.

---

## 🚀 Running the Pipeline

### Prerequisites
Make sure MySQL / MariaDB service is running:
- Database: `titanic_db`
- Host: `localhost`
- User: `root`
- Password: Configured in `config.py` (or set via `MYSQL_PASSWORD` environment variable)

### Execute
```bash
python run_elt.py
```

### Idempotency Verification
Run `python run_elt.py` multiple times in succession. Notice that the row count remains strictly 891 and all data quality checks continue to pass without duplicate rows.


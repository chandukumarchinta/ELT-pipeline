-- =====================================================================
-- Part 5: Data Quality Checks (SQL)
-- File: sql/04_data_quality.sql
-- Description: Executes automated data quality tests and records results
-- into the `dq_results` table with columns (check_name, status, checked_at).
-- =====================================================================

CREATE TABLE IF NOT EXISTS dq_results (
    id INT AUTO_INCREMENT PRIMARY KEY,
    check_name VARCHAR(255) NOT NULL,
    status VARCHAR(10) NOT NULL,
    checked_at DATETIME NOT NULL
);

-- Truncate to keep the latest run results fresh
TRUNCATE TABLE dq_results;

-- ---------------------------------------------------------------------
-- Check 1: Row count of raw_titanic = row count of clean_passengers
-- ---------------------------------------------------------------------
INSERT INTO dq_results (check_name, status, checked_at)
SELECT 
    'Row count of raw_titanic = row count of clean_passengers' AS check_name,
    CASE 
        WHEN (SELECT COUNT(*) FROM raw_titanic) = (SELECT COUNT(*) FROM clean_passengers) 
        THEN 'PASS' 
        ELSE 'FAIL' 
    END AS status,
    NOW() AS checked_at;

-- ---------------------------------------------------------------------
-- Check 2: No nulls in age, embarked
-- ---------------------------------------------------------------------
INSERT INTO dq_results (check_name, status, checked_at)
SELECT 
    'No nulls in age, embarked' AS check_name,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS' 
        ELSE 'FAIL' 
    END AS status,
    NOW() AS checked_at
FROM clean_passengers
WHERE age IS NULL OR embarked IS NULL OR TRIM(embarked) = '';

-- ---------------------------------------------------------------------
-- Check 3: No duplicate passengers
-- ---------------------------------------------------------------------
INSERT INTO dq_results (check_name, status, checked_at)
SELECT 
    'No duplicate passengers' AS check_name,
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT passenger_id) THEN 'PASS' 
        ELSE 'FAIL' 
    END AS status,
    NOW() AS checked_at
FROM clean_passengers;

-- ---------------------------------------------------------------------
-- Check 4: Age is between 0 and 100
-- ---------------------------------------------------------------------
INSERT INTO dq_results (check_name, status, checked_at)
SELECT 
    'Age is between 0 and 100' AS check_name,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS' 
        ELSE 'FAIL' 
    END AS status,
    NOW() AS checked_at
FROM clean_passengers
WHERE age < 0 OR age > 100;

-- ---------------------------------------------------------------------
-- Check 5: sex has only 0 or 1
-- ---------------------------------------------------------------------
INSERT INTO dq_results (check_name, status, checked_at)
SELECT 
    'sex has only 0 or 1' AS check_name,
    CASE 
        WHEN COUNT(*) = 0 THEN 'PASS' 
        ELSE 'FAIL' 
    END AS status,
    NOW() AS checked_at
FROM clean_passengers
WHERE sex NOT IN (0, 1) OR sex IS NULL;


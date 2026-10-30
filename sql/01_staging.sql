-- =====================================================================
-- Part 2: Staging Layer (SQL)
-- File: sql/01_staging.sql
-- Description: Creates `stg_titanic` from `raw_titanic`.
-- 1. Renames columns to clear, standardized names (e.g., pclass -> passenger_class).
-- 2. Normalizes all text columns to consistent lowercase.
-- 3. Explicitly casts columns to correct data types.
-- 4. Assigns passenger_id surrogate key using ROW_NUMBER() window function.
-- =====================================================================

DROP TABLE IF EXISTS stg_titanic;

CREATE TABLE stg_titanic AS
SELECT 
    ROW_NUMBER() OVER () AS passenger_id,
    CAST(survived AS SIGNED) AS survived,
    CAST(pclass AS SIGNED) AS passenger_class,
    LOWER(TRIM(sex)) AS sex,
    CAST(age AS DECIMAL(5, 2)) AS age,
    CAST(sibsp AS SIGNED) AS sibsp,
    CAST(parch AS SIGNED) AS parch,
    CAST(fare AS DECIMAL(10, 4)) AS fare,
    NULLIF(LOWER(TRIM(embarked)), '') AS embarked,
    LOWER(TRIM(`class`)) AS ticket_class,
    LOWER(TRIM(who)) AS passenger_type,
    CAST(adult_male AS SIGNED) AS is_adult_male,
    NULLIF(LOWER(TRIM(deck)), '') AS deck,
    NULLIF(LOWER(TRIM(embark_town)), '') AS embark_town,
    LOWER(TRIM(alive)) AS is_alive,
    CAST(alone AS SIGNED) AS is_alone,
    load_timestamp,
    batch_id
FROM raw_titanic;


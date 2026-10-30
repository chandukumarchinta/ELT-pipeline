-- =====================================================================
-- Part 3: Transformation Layer (SQL)
-- File: sql/02_transformation.sql
-- Description: Creates `clean_passengers` from `stg_titanic`.
-- 1. Fills missing age using the average age of the same class and same sex.
-- 2. Fills missing embarked with the most common value (mode).
-- 3. Removes deck and embark_town.
-- 4. Encodes sex as 0 (male) and 1 (female).
-- 5. Creates age_group: Child (0–12), Teen (13–19), Adult (20–59), Senior (60+).
-- 6. Creates family_size = sibsp + parch + 1, and is_alone (1 or 0).
-- 7. Creates fare_category (Low, Medium, High, Premium) using NTILE(4).
-- =====================================================================

DROP TABLE IF EXISTS clean_passengers;

CREATE TABLE clean_passengers AS
WITH mode_embarked AS (
    -- Identify the most common embarked value
    SELECT embarked 
    FROM stg_titanic 
    WHERE embarked IS NOT NULL AND TRIM(embarked) != ''
    GROUP BY embarked 
    ORDER BY COUNT(*) DESC 
    LIMIT 1
),
imputed_and_engineered AS (
    SELECT 
        s.passenger_id,
        s.survived,
        s.passenger_class,
        -- Rule 4: Encode sex as 0 (male) and 1 (female)
        CASE 
            WHEN s.sex = 'female' THEN 1 
            WHEN s.sex = 'male' THEN 0 
            ELSE NULL 
        END AS sex,
        -- Rule 1: Impute missing age with the average of same passenger class and sex
        COALESCE(
            s.age, 
            ROUND(AVG(s.age) OVER (PARTITION BY s.passenger_class, s.sex), 2)
        ) AS age,
        s.sibsp,
        s.parch,
        -- Rule 6: family_size = sibsp + parch + 1, and is_alone (1 or 0)
        s.sibsp + s.parch + 1 AS family_size,
        CASE 
            WHEN (s.sibsp + s.parch + 1) = 1 THEN 1 
            ELSE 0 
        END AS is_alone,
        s.fare,
        -- Rule 7: fare_category using NTILE(4)
        NTILE(4) OVER (ORDER BY s.fare ASC) AS fare_ntile,
        -- Rule 2: Impute missing embarked with most common value
        COALESCE(s.embarked, m.embarked) AS embarked
        -- Rule 3: deck and embark_town are excluded here
    FROM stg_titanic s
    CROSS JOIN mode_embarked m
)
SELECT 
    passenger_id,
    survived,
    passenger_class,
    sex,
    age,
    -- Rule 5: age_group: Child (0–12), Teen (13–19), Adult (20–59), Senior (60+)
    CASE 
        WHEN age < 13 THEN 'Child'
        WHEN age < 20 THEN 'Teen'
        WHEN age < 60 THEN 'Adult'
        ELSE 'Senior'
    END AS age_group,
    sibsp,
    parch,
    family_size,
    is_alone,
    fare,
    CASE fare_ntile
        WHEN 1 THEN 'Low'
        WHEN 2 THEN 'Medium'
        WHEN 3 THEN 'High'
        WHEN 4 THEN 'Premium'
    END AS fare_category,
    embarked
FROM imputed_and_engineered;


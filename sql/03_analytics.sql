-- =====================================================================
-- Part 4: Analytics Layer (SQL)
-- File: sql/03_analytics.sql
-- Description: Creates 3 analytical views on clean_passengers.
-- 1. vw_survival_by_class_sex: Survival rate by class and sex.
-- 2. vw_survival_by_age_group: Survival rate by age group.
-- 3. vw_top_3_fares_by_class: Top 3 highest fares in each class (using ROW_NUMBER() / RANK()).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Survival Rate by Class and Sex
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_survival_by_class_sex AS
SELECT 
    passenger_class,
    sex,
    CASE sex 
        WHEN 0 THEN 'male' 
        WHEN 1 THEN 'female' 
        ELSE 'unknown' 
    END AS sex_label,
    COUNT(*) AS total_passengers,
    SUM(survived) AS survived_passengers,
    ROUND(AVG(survived) * 100, 2) AS survival_rate_pct
FROM clean_passengers
GROUP BY passenger_class, sex
ORDER BY passenger_class, sex;

-- ---------------------------------------------------------------------
-- 2. Survival Rate by Age Group
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_survival_by_age_group AS
SELECT 
    age_group,
    COUNT(*) AS total_passengers,
    SUM(survived) AS survived_passengers,
    ROUND(AVG(survived) * 100, 2) AS survival_rate_pct
FROM clean_passengers
GROUP BY age_group
ORDER BY 
    CASE age_group 
        WHEN 'Child' THEN 1 
        WHEN 'Teen' THEN 2 
        WHEN 'Adult' THEN 3 
        WHEN 'Senior' THEN 4 
        ELSE 5 
    END;

-- ---------------------------------------------------------------------
-- 3. Top 3 Highest Fares in Each Class
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_top_3_fares_by_class AS
WITH ranked_passengers AS (
    SELECT 
        passenger_id,
        passenger_class,
        sex,
        CASE sex WHEN 0 THEN 'male' ELSE 'female' END AS sex_label,
        age,
        age_group,
        fare,
        fare_category,
        ROW_NUMBER() OVER (
            PARTITION BY passenger_class 
            ORDER BY fare DESC, passenger_id ASC
        ) AS fare_rank
    FROM clean_passengers
)
SELECT 
    passenger_class,
    fare_rank,
    passenger_id,
    sex_label,
    age,
    age_group,
    fare,
    fare_category
FROM ranked_passengers
WHERE fare_rank <= 3
ORDER BY passenger_class ASC, fare_rank ASC;


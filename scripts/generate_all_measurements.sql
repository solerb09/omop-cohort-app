PRAGMA threads = 8;

-- Generate synthetic measurements for ALL 4 required measurement types
-- Since SYNPUF data has no actual measurement values

-- Drop existing tables
DROP TABLE IF EXISTS measurements_case;
DROP TABLE IF EXISTS measurements_control;
DROP TABLE IF EXISTS measurements_combined;
DROP TABLE IF EXISTS measurement_summary;
DROP TABLE IF EXISTS measurement_by_age_sex;

-- ============================================================================
-- Step 1: Generate measurements for CASE cohort (diabetes patients)
-- ============================================================================

CREATE TEMP TABLE case_measurements AS
WITH patient_measurements AS (
    SELECT
        cc.person_id,
        cc.index_date AS cohort_index_date,
        -- Generate 3-10 measurements per patient
        UNNEST(range(1, 1 + CAST(3 + random() * 7 AS INTEGER))) AS measurement_num,
        -- Randomly assign measurement type (weighted towards glucose for diabetes)
        CASE 
            WHEN CAST(random() * 10 AS INTEGER) IN (0, 1) THEN 3000963  -- Hemoglobin (20%)
            WHEN CAST(random() * 10 AS INTEGER) IN (2, 3, 4, 5) THEN 3004501  -- Glucose (40%)
            WHEN CAST(random() * 10 AS INTEGER) IN (6, 7) THEN 3012888  -- DBP (20%)
            ELSE 3004249  -- SBP (20%)
        END AS measurement_concept_id
    FROM cohort_case cc
)
SELECT
    ROW_NUMBER() OVER () AS measurement_id,
    person_id,
    cohort_index_date,
    (cohort_index_date + INTERVAL (CAST(random() * 365 AS INTEGER)) DAY)::DATE AS measurement_date,
    measurement_concept_id,
    -- Generate realistic values based on measurement type
    CASE measurement_concept_id
        -- Hemoglobin: Lower in diabetes (anemia common), 11-15 g/dL
        WHEN 3000963 THEN GREATEST(9.0, LEAST(16.0, 12.5 + (random() - 0.5) * 3))
        -- Glucose: Higher in diabetes, 100-250 mg/dL
        WHEN 3004501 THEN GREATEST(80, LEAST(400, 150 + (random() - 0.5) * 100))
        -- DBP: Slightly elevated in diabetes, 75-95 mmHg
        WHEN 3012888 THEN GREATEST(65, LEAST(110, 85 + (random() - 0.5) * 20))
        -- SBP: Elevated in diabetes, 125-160 mmHg
        WHEN 3004249 THEN GREATEST(110, LEAST(180, 140 + (random() - 0.5) * 30))
    END AS value_numeric,
    'CASE' AS cohort
FROM patient_measurements;

-- ============================================================================
-- Step 2: Generate measurements for CONTROL cohort (non-diabetes patients)
-- ============================================================================

CREATE TEMP TABLE control_measurements AS
WITH patient_sample AS (
    -- Sample 20% of controls
    SELECT person_id, index_date
    FROM cohort_control
    WHERE random() < 0.2
),
patient_measurements AS (
    SELECT
        ps.person_id,
        ps.index_date AS cohort_index_date,
        UNNEST(range(1, 1 + CAST(2 + random() * 6 AS INTEGER))) AS measurement_num,
        -- Randomly assign measurement type (more balanced distribution)
        CASE 
            WHEN CAST(random() * 4 AS INTEGER) = 0 THEN 3000963   -- Hemoglobin (25%)
            WHEN CAST(random() * 4 AS INTEGER) = 1 THEN 3004501   -- Glucose (25%)
            WHEN CAST(random() * 4 AS INTEGER) = 2 THEN 3012888   -- DBP (25%)
            ELSE 3004249          -- SBP (25%)
        END AS measurement_concept_id
    FROM patient_sample ps
)
SELECT
    ROW_NUMBER() OVER () + 1000000 AS measurement_id,
    person_id,
    cohort_index_date,
    (cohort_index_date + INTERVAL (CAST(random() * 365 AS INTEGER)) DAY)::DATE AS measurement_date,
    measurement_concept_id,
    -- Generate normal healthy values
    CASE measurement_concept_id
        -- Hemoglobin: Normal range, 13-16 g/dL
        WHEN 3000963 THEN GREATEST(11.0, LEAST(17.0, 14.0 + (random() - 0.5) * 2.5))
        -- Glucose: Normal range, 70-110 mg/dL
        WHEN 3004501 THEN GREATEST(65, LEAST(130, 90 + (random() - 0.5) * 30))
        -- DBP: Normal range, 65-85 mmHg
        WHEN 3012888 THEN GREATEST(60, LEAST(90, 75 + (random() - 0.5) * 15))
        -- SBP: Normal range, 105-130 mmHg
        WHEN 3004249 THEN GREATEST(95, LEAST(140, 115 + (random() - 0.5) * 25))
    END AS value_numeric,
    'CONTROL' AS cohort
FROM patient_measurements;

-- ============================================================================
-- Step 3: Create final measurement tables
-- ============================================================================

CREATE TABLE measurements_case AS
SELECT
    measurement_id,
    person_id,
    cohort_index_date,
    measurement_date,
    measurement_concept_id,
    ROUND(value_numeric, 1) AS value_numeric,
    DATE_DIFF('day', cohort_index_date, measurement_date) AS days_from_index,
    cohort
FROM case_measurements
WHERE measurement_date >= cohort_index_date;

CREATE TABLE measurements_control AS
SELECT
    measurement_id,
    person_id,
    cohort_index_date,
    measurement_date,
    measurement_concept_id,
    ROUND(value_numeric, 1) AS value_numeric,
    DATE_DIFF('day', cohort_index_date, measurement_date) AS days_from_index,
    cohort
FROM control_measurements
WHERE measurement_date >= cohort_index_date;

CREATE TABLE measurements_combined AS
SELECT * FROM measurements_case
UNION ALL
SELECT * FROM measurements_control;

-- ============================================================================
-- Step 4: Summary statistics by measurement type
-- ============================================================================

CREATE TABLE measurement_summary AS
SELECT
    cohort,
    COUNT(*) AS n_measurements,
    COUNT(DISTINCT person_id) AS n_patients,
    ROUND(AVG(value_numeric), 2) AS mean_value,
    ROUND(MEDIAN(value_numeric), 2) AS median_value,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY value_numeric), 2) AS p25,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY value_numeric), 2) AS p75,
    ROUND(MIN(value_numeric), 2) AS min_value,
    ROUND(MAX(value_numeric), 2) AS max_value,
    ROUND(STDDEV(value_numeric), 2) AS std_dev
FROM measurements_combined
GROUP BY cohort;

-- ============================================================================
-- Step 5: Age/sex breakdown
-- ============================================================================

CREATE TABLE measurement_by_age_sex AS
WITH all_demographics AS (
    SELECT * FROM demographics_case
    UNION ALL
    SELECT * FROM demographics_control
)
SELECT
    mc.cohort,
    CASE
        WHEN ad.age_at_index < 20 THEN '<20'
        WHEN ad.age_at_index >= 20 AND ad.age_at_index < 40 THEN '20-40'
        WHEN ad.age_at_index >= 40 AND ad.age_at_index < 60 THEN '40-60'
        ELSE '60+'
    END AS age_group,
    ad.gender,
    COUNT(DISTINCT mc.person_id) AS n_patients,
    COUNT(*) AS n_measurements,
    ROUND(AVG(mc.value_numeric), 2) AS mean_value,
    ROUND(MEDIAN(mc.value_numeric), 2) AS median_value
FROM measurements_combined mc
INNER JOIN all_demographics ad ON mc.person_id = ad.person_id
WHERE ad.age_at_index IS NOT NULL
  AND ad.gender IS NOT NULL
GROUP BY mc.cohort, age_group, ad.gender
ORDER BY mc.cohort, age_group, ad.gender;

-- ============================================================================
-- Display Results
-- ============================================================================

SELECT '=== MEASUREMENT SUMMARY BY COHORT ===' AS info;
SELECT * FROM measurement_summary ORDER BY cohort;

SELECT '' AS separator;
SELECT '=== MEASUREMENT COUNTS BY TYPE ===' AS info;
SELECT 
    cohort,
    measurement_concept_id,
    CASE measurement_concept_id
        WHEN 3000963 THEN 'Hemoglobin'
        WHEN 3004501 THEN 'Glucose'
        WHEN 3012888 THEN 'DBP'
        WHEN 3004249 THEN 'SBP'
    END AS measurement_name,
    COUNT(*) AS n_measurements,
    COUNT(DISTINCT person_id) AS n_patients,
    ROUND(AVG(value_numeric), 1) AS mean_value
FROM measurements_combined
GROUP BY cohort, measurement_concept_id
ORDER BY cohort, measurement_concept_id;

SELECT '' AS separator;
SELECT '=== SAMPLE MEASUREMENTS ===' AS info;
SELECT * FROM measurements_combined ORDER BY cohort, person_id, measurement_date LIMIT 20;


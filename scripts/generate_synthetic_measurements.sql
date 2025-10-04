PRAGMA threads = 8;

-- Generate synthetic glucose measurements for demo purposes
-- SYNPUF data has no actual measurement values (VALUE_AS_NUMBER is empty)
-- We'll create realistic glucose values based on cohort status

-- Step 1: Create synthetic glucose measurements for CASE cohort (diabetes patients)
-- Diabetes patients typically have higher glucose: mean ~150 mg/dL, range 100-250
DROP TABLE IF EXISTS measurements_case;
CREATE TABLE measurements_case AS
WITH patient_measurements AS (
    SELECT
        cc.person_id,
        cc.index_date AS cohort_index_date,
        -- Generate 3-10 random measurements per patient after their index date
        UNNEST(range(1, 1 + CAST(3 + random() * 7 AS INTEGER))) AS measurement_num
    FROM cohort_case cc
),
synthetic_values AS (
    SELECT
        ROW_NUMBER() OVER () AS measurement_id,
        person_id,
        cohort_index_date,
        -- Random date between index date and 1 year after
        (cohort_index_date + INTERVAL (CAST(random() * 365 AS INTEGER)) DAY)::DATE AS measurement_date,
        3034639 AS measurement_concept_id,  -- Glucose [Mass/volume] in Serum or Plasma
        -- Realistic diabetic glucose values: normal distribution around 150 mg/dL, std dev 30
        GREATEST(80, LEAST(400, 150 + (random() - 0.5) * 60 + (random() - 0.5) * 60))::DOUBLE AS value_numeric,
        'CASE' AS cohort
    FROM patient_measurements
)
SELECT
    measurement_id,
    person_id,
    cohort_index_date,
    measurement_date,
    measurement_concept_id,
    ROUND(value_numeric, 1) AS value_numeric,
    DATE_DIFF('day', cohort_index_date, measurement_date) AS days_from_index,
    cohort
FROM synthetic_values
WHERE measurement_date >= cohort_index_date;

-- Step 2: Create synthetic glucose measurements for CONTROL cohort (non-diabetes)
-- Normal patients have lower glucose: mean ~95 mg/dL, range 70-140
DROP TABLE IF EXISTS measurements_control;
CREATE TABLE measurements_control AS
WITH patient_sample AS (
    -- Sample 20% of control patients to keep table size manageable
    SELECT person_id, index_date
    FROM cohort_control
    WHERE random() < 0.2  -- 20% sample
),
patient_measurements AS (
    SELECT
        ps.person_id,
        ps.index_date AS cohort_index_date,
        UNNEST(range(1, 1 + CAST(2 + random() * 6 AS INTEGER))) AS measurement_num
    FROM patient_sample ps
),
synthetic_values AS (
    SELECT
        ROW_NUMBER() OVER () + 1000000 AS measurement_id,  -- Offset to avoid ID collision
        person_id,
        cohort_index_date,
        (cohort_index_date + INTERVAL (CAST(random() * 365 AS INTEGER)) DAY)::DATE AS measurement_date,
        3034639 AS measurement_concept_id,
        -- Normal glucose values: normal distribution around 95 mg/dL, std dev 15
        GREATEST(65, LEAST(140, 95 + (random() - 0.5) * 30 + (random() - 0.5) * 30))::DOUBLE AS value_numeric,
        'CONTROL' AS cohort
    FROM patient_measurements
)
SELECT
    measurement_id,
    person_id,
    cohort_index_date,
    measurement_date,
    measurement_concept_id,
    ROUND(value_numeric, 1) AS value_numeric,
    DATE_DIFF('day', cohort_index_date, measurement_date) AS days_from_index,
    cohort
FROM synthetic_values
WHERE measurement_date >= cohort_index_date;

-- Step 3: Combined measurements table
DROP TABLE IF EXISTS measurements_combined;
CREATE TABLE measurements_combined AS
SELECT * FROM measurements_case
UNION ALL
SELECT * FROM measurements_control;

-- Step 4: Summary statistics (for box plots & API)
DROP TABLE IF EXISTS measurement_summary;
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

-- Step 5: Age group breakdown (for demographics charts)
DROP TABLE IF EXISTS measurement_by_age_sex;
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

-- Display results
SELECT '=== MEASUREMENT SUMMARY BY COHORT ===' AS info;
SELECT * FROM measurement_summary ORDER BY cohort;

SELECT '' AS separator;
SELECT '=== MEASUREMENT BREAKDOWN BY AGE GROUP & SEX ===' AS info;
SELECT * FROM measurement_by_age_sex;

SELECT '' AS separator;
SELECT '=== SAMPLE MEASUREMENTS (First 10 from each cohort) ===' AS info;
SELECT * FROM measurements_combined ORDER BY cohort, person_id, measurement_date LIMIT 20;

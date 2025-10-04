PRAGMA threads = 8;

-- OMOP column mappings:
-- measurement: column00=measurement_id, column01=person_id, column02=measurement_concept_id, 
--              column03=measurement_date, column07=value_as_number

-- Common glucose/HbA1c concept IDs (update based on your actual data):
-- 3004410: Hemoglobin A1c/Hemoglobin.total in Blood
-- 3005673: Glucose [Mass/volume] in Blood
-- 3034639: Glucose [Mass/volume] in Serum or Plasma

-- Step 1: Extract all glucose/HbA1c measurements for CASE cohort (Diabetes)
DROP TABLE IF EXISTS measurements_case;
CREATE TABLE measurements_case AS
SELECT
    m.column01 AS person_id,
    dc.index_date AS cohort_index_date,
    m.column03 AS measurement_date,
    m.column02 AS measurement_concept_id,
    m.column07 AS value_as_number,
    CAST(m.column07 AS DOUBLE) AS value_numeric,
    -- Time relative to cohort entry (days after index)
    DATE_DIFF('day', dc.index_date, m.column03) AS days_from_index,
    'CASE' AS cohort
FROM measurement m
INNER JOIN cohort_case dc ON m.column01 = dc.person_id
WHERE m.column07 IS NOT NULL  -- Only measurements with numeric values
  AND CAST(m.column07 AS DOUBLE) > 0  -- Exclude zero/negative values
  AND m.column03 >= dc.index_date;  -- Only measurements AFTER diabetes diagnosis

-- Step 2: Extract all glucose/HbA1c measurements for CONTROL cohort (Non-diabetes)
DROP TABLE IF EXISTS measurements_control;
CREATE TABLE measurements_control AS
SELECT
    m.column01 AS person_id,
    ctrl.index_date AS cohort_index_date,
    m.column03 AS measurement_date,
    m.column02 AS measurement_concept_id,
    m.column07 AS value_as_number,
    CAST(m.column07 AS DOUBLE) AS value_numeric,
    DATE_DIFF('day', ctrl.index_date, m.column03) AS days_from_index,
    'CONTROL' AS cohort
FROM measurement m
INNER JOIN cohort_control ctrl ON m.column01 = ctrl.person_id
WHERE m.column07 IS NOT NULL
  AND CAST(m.column07 AS DOUBLE) > 0
  AND m.column03 >= ctrl.index_date;

-- Step 3: Combined measurements table for easier querying
DROP TABLE IF EXISTS measurements_combined;
CREATE TABLE measurements_combined AS
SELECT * FROM measurements_case
UNION ALL
SELECT * FROM measurements_control;

-- Step 4: Summary statistics by cohort (for API endpoints / React charts)
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

-- Step 5: Age group breakdown for demographics charts
DROP TABLE IF EXISTS measurement_by_age_sex;
CREATE TABLE measurement_by_age_sex AS
SELECT
    mc.cohort,
    CASE
        WHEN dc.age_at_index < 20 THEN '<20'
        WHEN dc.age_at_index >= 20 AND dc.age_at_index < 40 THEN '20-40'
        WHEN dc.age_at_index >= 40 AND dc.age_at_index < 60 THEN '40-60'
        ELSE '60+'
    END AS age_group,
    dc.gender,
    COUNT(DISTINCT mc.person_id) AS n_patients,
    COUNT(*) AS n_measurements,
    ROUND(AVG(mc.value_numeric), 2) AS mean_value,
    ROUND(MEDIAN(mc.value_numeric), 2) AS median_value
FROM measurements_combined mc
LEFT JOIN (
    SELECT * FROM demographics_case
    UNION ALL
    SELECT * FROM demographics_control
) dc ON mc.person_id = dc.person_id
WHERE dc.age_at_index IS NOT NULL
  AND dc.gender IS NOT NULL
GROUP BY mc.cohort, age_group, dc.gender
ORDER BY mc.cohort, age_group, dc.gender;

-- Display results
SELECT '=== MEASUREMENT SUMMARY BY COHORT ===' AS info;
SELECT * FROM measurement_summary;

SELECT '=== MEASUREMENT BREAKDOWN BY AGE GROUP & SEX ===' AS info;
SELECT * FROM measurement_by_age_sex;

-- Export tables for API (optional - shows sample of raw data)
SELECT '=== SAMPLE MEASUREMENTS (First 10 from each cohort) ===' AS info;
SELECT * FROM measurements_combined ORDER BY cohort, person_id, measurement_date LIMIT 20;


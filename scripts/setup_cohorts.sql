PRAGMA threads = 8;

--   Target diseases (from 1K SYNPUF dataset):
--   'Diabetes' (201826) - Type 2 diabetes mellitus
--   'Hypertension' (320128)
--   'Atrial fibrillation' (312648)
--   'Essential hypertension' (201826)

-- CASE cohort: patients with Diabetes diagnosis (concept_id = 201826)
DROP TABLE IF EXISTS cohort_case;
CREATE TABLE cohort_case AS
SELECT
    PERSON_ID AS person_id,
    STRPTIME(CAST(MIN(CONDITION_START_DATE) AS VARCHAR), '%Y%m%d')::DATE AS index_date
FROM condition_occurrence
WHERE CONDITION_CONCEPT_ID = 201826
GROUP BY PERSON_ID;

-- CONTROL cohort: patients without Diabetes, index date from first measurement or 1970-01-01
DROP TABLE IF EXISTS cohort_control;
CREATE TABLE cohort_control AS
WITH first_measurement AS (
    SELECT 
        PERSON_ID AS person_id, 
        STRPTIME(CAST(MIN(MEASUREMENT_DATE) AS VARCHAR), '%Y%m%d')::DATE AS index_date
    FROM measurement
    GROUP BY PERSON_ID
)
SELECT 
    p.PERSON_ID AS person_id, 
    COALESCE(fm.index_date, DATE '1970-01-01') AS index_date
FROM person p
LEFT JOIN cohort_case cc ON p.PERSON_ID = cc.person_id
LEFT JOIN first_measurement fm ON p.PERSON_ID = fm.person_id
WHERE cc.person_id IS NULL;

-- Cohort counts
SELECT 'case' AS cohort, COUNT(*) AS n FROM cohort_case
UNION ALL
SELECT 'control', COUNT(*) AS n FROM cohort_control;
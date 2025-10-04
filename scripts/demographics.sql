PRAGMA threads = 8;

-- Demographics for CASE cohort (Diabetes patients)
DROP TABLE IF EXISTS demographics_case;
CREATE TABLE demographics_case AS
SELECT
    cc.person_id,
    cc.index_date,
    p.GENDER_CONCEPT_ID AS gender_concept_id,
    c.concept_name AS gender,
    p.YEAR_OF_BIRTH AS year_of_birth,
    YEAR(cc.index_date) - p.YEAR_OF_BIRTH AS age_at_index
FROM cohort_case cc
INNER JOIN person p ON cc.person_id = p.PERSON_ID
LEFT JOIN concept c ON p.GENDER_CONCEPT_ID = c.concept_id;

-- Demographics for CONTROL cohort (Non-diabetes patients)
DROP TABLE IF EXISTS demographics_control;
CREATE TABLE demographics_control AS
SELECT
    ctrl.person_id,
    ctrl.index_date,
    p.GENDER_CONCEPT_ID AS gender_concept_id,
    c.concept_name AS gender,
    p.YEAR_OF_BIRTH AS year_of_birth,
    YEAR(ctrl.index_date) - p.YEAR_OF_BIRTH AS age_at_index
FROM cohort_control ctrl
INNER JOIN person p ON ctrl.person_id = p.PERSON_ID
LEFT JOIN concept c ON p.GENDER_CONCEPT_ID = c.concept_id;

-- Summary statistics: CASE cohort
SELECT
    'CASE (Diabetes)' AS cohort,
    COUNT(*) AS n_patients,
    ROUND(AVG(age_at_index), 1) AS mean_age,
    MIN(age_at_index) AS min_age,
    MAX(age_at_index) AS max_age,
    COUNT(CASE WHEN gender = 'Male' THEN 1 END) AS n_male,
    COUNT(CASE WHEN gender = 'Female' THEN 1 END) AS n_female,
    ROUND(100.0 * COUNT(CASE WHEN gender = 'Male' THEN 1 END) / COUNT(*), 1) AS pct_male
FROM demographics_case

UNION ALL

-- Summary statistics: CONTROL cohort
SELECT
    'CONTROL (No Diabetes)' AS cohort,
    COUNT(*) AS n_patients,
    ROUND(AVG(age_at_index), 1) AS mean_age,
    MIN(age_at_index) AS min_age,
    MAX(age_at_index) AS max_age,
    COUNT(CASE WHEN gender = 'Male' THEN 1 END) AS n_male,
    COUNT(CASE WHEN gender = 'Female' THEN 1 END) AS n_female,
    ROUND(100.0 * COUNT(CASE WHEN gender = 'Male' THEN 1 END) / COUNT(*), 1) AS pct_male
FROM demographics_control;


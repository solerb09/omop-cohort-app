CREATE OR REPLACE TABLE concept AS
SELECT * FROM (
  VALUES
    (201826,  'Type 2 diabetes mellitus'),
    (320128,  'Essential hypertension'),
    (312648,  'Atrial fibrillation'),
    (432867,  'Nausea'),
    (8507,    'Male'),
    (8532,    'Female')
) AS t(concept_id, concept_name);

-- Load 1K patient SYNPUF dataset

DROP TABLE IF EXISTS person;
CREATE TABLE person AS
SELECT *
FROM read_csv_auto('data/synpuf_1k/CDM_PERSON.csv', SAMPLE_SIZE=-1, header=true);

-- Condition Occurrence Table
DROP TABLE IF EXISTS condition_occurrence;
CREATE TABLE condition_occurrence AS
SELECT *
FROM read_csv_auto('data/synpuf_1k/CDM_CONDITION_OCCURRENCE.csv', SAMPLE_SIZE=-1, header=true);

--  Measurement Table
DROP TABLE IF EXISTS measurement;
CREATE TABLE measurement AS
SELECT *
FROM read_csv_auto('data/synpuf_1k/CDM_MEASUREMENT.csv', SAMPLE_SIZE=-1, header=true);

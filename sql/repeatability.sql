-- Run after a clean dbt build.

DROP TABLE IF EXISTS repeat_run1;

CREATE TABLE repeat_run1 AS
SELECT *
FROM dbt_mart.mart_daily_road;

-- Run the same clean dbt build again.

DROP TABLE IF EXISTS repeat_run2;

CREATE TABLE repeat_run2 AS
SELECT *
FROM dbt_mart.mart_daily_road;

-- Aggregate comparison.
SELECT
'run1' AS run_name,
COUNT(*) AS rows_count,
SUM(collisions_count) AS collisions,
SUM(casualties_count) AS casualties,
SUM(serious_collisions_count) AS serious_collisions,
SUM(vehicles_count) AS vehicles
FROM repeat_run1

UNION ALL

SELECT
'run2',
COUNT(*),
SUM(collisions_count),
SUM(casualties_count),
SUM(serious_collisions_count),
SUM(vehicles_count)
FROM repeat_run2;

-- Rows present only in run 1.
SELECT COUNT(*) AS rows_only_in_run1
FROM (
SELECT *
FROM repeat_run1
EXCEPT
SELECT *
FROM repeat_run2
) x;

-- Rows present only in run 2.
SELECT COUNT(*) AS rows_only_in_run2
FROM (
SELECT *
FROM repeat_run2
EXCEPT
SELECT *
FROM repeat_run1
) x;

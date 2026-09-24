-- Independent control queries for the final submission.

-- Raw population.
SELECT COUNT(*) AS raw_rows
FROM raw.raw_collisions;

-- DWH populations.
SELECT
(SELECT COUNT(*) FROM dbt_dwh.dim_date) AS dim_date_rows,
(SELECT COUNT(*) FROM dbt_dwh.dim_road) AS dim_road_rows,
(SELECT COUNT(*) FROM dbt_dwh.fct_collisions) AS fact_rows,
(SELECT COUNT(*) FROM dbt_mart.mart_daily_road) AS mart_rows;

-- Published mart.
SELECT
COUNT(*) AS published_rows,
SUM(collisions_count) AS collisions,
SUM(casualties_count) AS casualties,
SUM(serious_collisions_count) AS serious_collisions,
SUM(vehicles_count) AS vehicles
FROM published.mart_daily_road;

-- Main analytical result by day of week.
SELECT
day_name,
SUM(collisions_count) AS collisions,
SUM(casualties_count) AS casualties,
SUM(serious_collisions_count) AS serious_collisions
FROM published.mart_daily_road
GROUP BY day_name
ORDER BY day_name;

-- Secondary result by road type.
SELECT
road_type,
road_type_label,
SUM(collisions_count) AS collisions,
SUM(casualties_count) AS casualties,
SUM(serious_collisions_count) AS serious_collisions
FROM published.mart_daily_road
GROUP BY road_type, road_type_label
ORDER BY collisions DESC;

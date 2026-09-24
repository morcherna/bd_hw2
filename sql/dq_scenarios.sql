-- Run each case independently from a clean input.
-- Restore the clean state after every case:
-- docker compose run --rm loader

-- CASE 1: duplicate key
INSERT INTO raw.raw_collisions
SELECT *
FROM raw.raw_collisions
LIMIT 1;

-- Expected:
-- unique_stg_collisions_collision_index FAILED.

-- CASE 2: NULL required value
UPDATE raw.raw_collisions
SET road_type_label = NULL
WHERE collision_index = (
SELECT collision_index
FROM raw.raw_collisions
LIMIT 1
);

-- Expected:
-- not_null_stg_collisions_road_type_label FAILED.

-- CASE 3: invalid accepted value
UPDATE raw.raw_collisions
SET collision_severity_label = 'Unknown'
WHERE collision_index = (
SELECT collision_index
FROM raw.raw_collisions
LIMIT 1
);

-- Expected:
-- accepted_values test FAILED.

-- CASE 4: business rule violation
UPDATE raw.raw_collisions
SET number_of_casualties = -1
WHERE collision_index = (
SELECT collision_index
FROM raw.raw_collisions
LIMIT 1
);

-- Expected:
-- business_rule_casualties FAILED.

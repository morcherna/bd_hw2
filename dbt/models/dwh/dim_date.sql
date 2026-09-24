select distinct
    to_char(collision_date, 'YYYYMMDD')::integer as date_key,
    collision_date as full_date,
    day_of_week,
    day_of_week_label as day_name,
    extract(month from collision_date)::integer as month,
    extract(year from collision_date)::integer as year
from {{ ref('stg_collisions') }}
select
    collision_index,
    collision_year,
    collision_ref_no,
    longitude,
    latitude,
    collision_severity,
    number_of_vehicles,
    number_of_casualties,
    date as collision_date,
    day_of_week,
    time as collision_time,
    first_road_class,
    first_road_number,
    road_type,
    speed_limit,
    urban_or_rural_area,
    collision_severity_label,
    day_of_week_label,
    road_type_label,
    urban_or_rural_area_label
from raw.raw_collisions
where date >= date '2025-01-01'
  and date < date '2025-02-01'
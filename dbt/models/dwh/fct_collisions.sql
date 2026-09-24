select
    s.collision_index,
    to_char(s.collision_date, 'YYYYMMDD')::integer as date_key,
    r.road_key,
    s.collision_severity,
    s.collision_severity_label,
    s.number_of_vehicles,
    s.number_of_casualties
from {{ ref('stg_collisions') }} s
join {{ ref('dim_road') }} r
    on s.first_road_class = r.first_road_class
    and s.road_type = r.road_type
    and s.road_type_label = r.road_type_label
    and s.speed_limit = r.speed_limit
    and s.urban_or_rural_area = r.urban_or_rural_area
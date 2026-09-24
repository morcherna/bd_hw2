select
    row_number() over (
        order by
            first_road_class,
            road_type,
            speed_limit,
            urban_or_rural_area
    ) as road_key,
    first_road_class,
    road_type,
    road_type_label,
    speed_limit,
    urban_or_rural_area,
    urban_or_rural_area_label
from (
    select distinct
        first_road_class,
        road_type,
        road_type_label,
        speed_limit,
        urban_or_rural_area,
        urban_or_rural_area_label
    from {{ ref('stg_collisions') }}
) roads
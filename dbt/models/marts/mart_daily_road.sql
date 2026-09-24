select
    d.full_date,
    d.day_of_week,
    d.day_name,
    r.road_type,
    r.road_type_label,
    count(*) as collisions_count,
    sum(f.number_of_casualties) as casualties_count,
    sum(
        case
            when f.collision_severity_label = 'Serious' then 1
            else 0
        end
    ) as serious_collisions_count,
    sum(f.number_of_vehicles) as vehicles_count
from {{ ref('fct_collisions') }} f
join {{ ref('dim_date') }} d
    on f.date_key = d.date_key
join {{ ref('dim_road') }} r
    on f.road_key = r.road_key
group by
    d.full_date,
    d.day_of_week,
    d.day_name,
    r.road_type,
    r.road_type_label
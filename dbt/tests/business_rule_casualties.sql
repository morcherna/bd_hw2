select
    collision_index,
    number_of_casualties
from {{ ref('fct_collisions') }}
where number_of_casualties < 0
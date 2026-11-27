
with route_base as (

    select distinct
        route_key,
        origin_airport_code,
        dest_airport_code,
        origin_state_code,
        dest_state_code,
        route_distance_category,

        max(avg_distance_miles) over (
            partition by route_key
        ) as route_distance_miles

    from {{ ref('int_route_stats') }}

),

enriched as (

    select

        {{ dbt_utils.generate_surrogate_key(['route_key']) }}
            as route_id,

        route_key,

        origin_airport_code,
        dest_airport_code,

        origin_state_code,
        dest_state_code,

        case
            when origin_state_code is null
              or dest_state_code is null
                then null
            when origin_state_code = dest_state_code
                then false
            else true
        end as is_interstate_route,

        route_distance_category,
        route_distance_miles,

        current_timestamp() as dw_last_refreshed_at

    from route_base

)

select *
from enriched
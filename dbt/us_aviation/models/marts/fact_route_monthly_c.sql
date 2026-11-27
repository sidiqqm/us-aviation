-- grain = maskapai x route x year_month

with route_stats as (
    select * from {{ref("int_route_stats")}}
),

fact as (
    select
        cast(format_date('%Y%m%d', rs.flight_date) as INT64) as flight_date_key,
        dc.carrier_id,
        rs.origin_airport_id,
        rs.dest_airport_id,
        rs.route_key,

        rs.is_chronic_delay_route,
        rs.total_operated_flights,
        rs.delayed_flights,
        rs.on_time_flights,

        rs.total_carrier_delay_min,
        rs.total_weather_delay_min,
        rs.total_nas_delay_min,
        rs.total_security_delay_min,
        rs.total_late_aircraft_delay_min,
        rs.total_delay_minutes,

        current_timestamp() as dw_last_refreshed_at

    from route_stats rs
    left join dim_carrier on rs.carrier_code = dc.carrier_code
)

select * from fact
-- grain = maskapai x route x year_month

with route_stats as (
    select * from {{ref("int_route_stats")}}
),

fact as (
    select
        flight_date_key,
        month_start as flight_month_date,
        carrier_id,
        carrier_code,
        origin_airport_id,
        dest_airport_id,
        route_key,

        is_chronic_delay_route,
        total_operated_flights,
        on_time_flights,
        delayed_flights,
        flights_with_valid_arr_delay,

        total_carrier_delay_min,
        total_weather_delay_min,
        total_nas_delay_min,
        total_security_delay_min,
        total_late_aircraft_delay_min,
        total_delay_minutes,

        current_timestamp() as dw_last_refreshed_at

    from route_stats
)

select * from fact
with flights as (
    select * from {{ ref("int_flights_enriched") }}
),

dim_carrier as (
    select * from {{ ref("dim_carrier") }}
)

fact as (
    select
        f.flight_id,
        cast(format_date('%Y%m%d', f.flight_date) as INT64) as flight_date_key,
        dc.carrier_id,
        f.origin_airport_id,
        f.dest_airport_id,
        f.route_key,

        f.scheduled_dep_time_hhmm,
        f.actual_dep_time_hhmm,
        f.scheduled_arr_time_hhmm,
        f.actual_arr_time_hhmm,
        f.taxi_out_minutes,
        f.taxi_in_minutes,
        f.wheels_off_time_hhmm,
        f.wheels_on_time_hhmm,

        f.dep_time_of_day,
        f.is_cancelled,
        f.is_diverted,
        f.is_on_time,
        f.is_dep_delayed,
        f.is_arr_delayed,
        f.cancellation_code,
        f.cancellation_reason,

        f.dep_delay_minutes,
        f.arr_delay_minutes,
        f.arr_delay_minutes_pos,
        f.delay_severity,
        f.delay_severity_order,

        f.carrier_delay_minutes,
        f.weather_delay_minutes,
        f.nas_delay_minutes,
        f.security_delay_minutes,
        f.late_aircraft_delay_minutes,
        f.total_cause_minutes,
        f.primary_delay_cause,

        f.scheduled_elapsed_minutes,
        f.actual_elapsed_minutes,
        f.air_time_minutes,
        f.distance_miles,
        f.distance_group
    from flights f
    left join dim_carrier dc on f.carrier_code = dc.carrier_code
)

select * from fact
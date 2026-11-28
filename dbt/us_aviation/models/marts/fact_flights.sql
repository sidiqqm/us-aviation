with facts as (
    select
        flight_id,
        flight_date,
        date_key,
        carrier_id,
        origin_airport_id,
        dest_airport_id,
        route_key,

        scheduled_dep_time_hhmm,
        actual_dep_time_hhmm,
        scheduled_arr_time_hhmm,
        actual_arr_time_hhmm,
        taxi_out_minutes,
        taxi_in_minutes,
        wheels_off_time_hhmm,
        wheels_on_time_hhmm,

        dep_time_of_day,
        is_cancelled,
        is_diverted,
        is_on_time,
        is_dep_delayed,
        is_arr_delayed,
        cancellation_code,
        cancellation_reason,

        dep_delay_minutes,
        arr_delay_minutes,
        arr_delay_minutes_pos,
        delay_severity,
        delay_severity_order,

        carrier_delay_minutes,
        weather_delay_minutes,
        nas_delay_minutes,
        security_delay_minutes,
        late_aircraft_delay_minutes,
        total_cause_minutes,
        primary_delay_cause,

        scheduled_elapsed_minutes,
        actual_elapsed_minutes,
        air_time_minutes,
        distance_miles,
        distance_group
    from {{ ref("int_flights_enriched") }}
)

select * from facts
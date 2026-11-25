
with delayed_flights as (

    select
        *
    from {{ ref('int_flights_enriched') }}
    where is_arr_delayed = true

),

classified as (

    select
        flight_id,
        flight_date,
        flight_year,
        flight_quarter,
        flight_month,
        flight_month_name,
        flight_day_of_week,
        day_of_week_name,
        flight_season,
        covid_period,
        is_covid_period,

        carrier_code,
        carrier_type,
        origin_airport_code,
        dest_airport_code,
        route_key,
        origin_state_code,
        dest_state_code,
        dep_time_of_day,
        is_weekend,
        route_distance_category,

        arr_delay_minutes,
        arr_delay_minutes_pos,
        total_cause_minutes,
        delay_severity,
        delay_severity_order,
        primary_delay_cause,

        -- Delay cause
        coalesce(carrier_delay_minutes, 0)
            as carrier_delay_minutes,

        coalesce(weather_delay_minutes, 0)
            as weather_delay_minutes,

        coalesce(nas_delay_minutes, 0)
            as nas_delay_minutes,

        coalesce(security_delay_minutes, 0)
            as security_delay_minutes,

        coalesce(late_aircraft_delay_minutes, 0)
            as late_aircraft_delay_minutes,

        -- Delay cause percentage
        round(
            {{ safe_divide(
                'coalesce(carrier_delay_minutes, 0)',
                'total_cause_minutes'
            ) }} * 100, 2
        ) as carrier_delay_pct,

        round(
            {{ safe_divide(
                'coalesce(weather_delay_minutes, 0)',
                'total_cause_minutes'
            ) }} * 100, 2
        ) as weather_delay_pct,

        round(
            {{ safe_divide(
                'coalesce(nas_delay_minutes, 0)',
                'total_cause_minutes'
            ) }} * 100, 2
        ) as nas_delay_pct,

        round(
            {{ safe_divide(
                'coalesce(security_delay_minutes, 0)',
                'total_cause_minutes'
            ) }} * 100, 2
        ) as security_delay_pct,

        round(
            {{ safe_divide(
                'coalesce(late_aircraft_delay_minutes, 0)',
                'total_cause_minutes'
            ) }} * 100, 2
        ) as late_aircraft_delay_pct,

        -- Majority cause (>50% of total cause minutes)
        coalesce(carrier_delay_minutes, 0)
            > total_cause_minutes * 0.5
            as carrier_is_majority,

        coalesce(weather_delay_minutes, 0)
            > total_cause_minutes * 0.5
            as weather_is_majority,

        coalesce(nas_delay_minutes, 0)
            > total_cause_minutes * 0.5
            as nas_is_majority,

        coalesce(security_delay_minutes, 0)
            > total_cause_minutes * 0.5
            as security_is_majority,

        coalesce(late_aircraft_delay_minutes, 0)
            > total_cause_minutes * 0.5
            as late_aircraft_is_majority,

        -- Delay duration flags
        arr_delay_minutes_pos > 60 as is_over_1_hour,
        arr_delay_minutes_pos > 120 as is_over_2_hours,
        arr_delay_minutes_pos > 240 as is_over_4_hours,

        case
            when arr_delay_minutes_pos is null then 'unknown'
            when arr_delay_minutes_pos <= 60 then 'under_1_hour'
            when arr_delay_minutes_pos <= 120 then '1_to_2_hours'
            when arr_delay_minutes_pos <= 240 then '2_to_4_hours'
            else 'over_4_hours'
        end as delay_duration_category,

        -- Cascade delay
        coalesce(late_aircraft_delay_minutes, 0) > 15
            as is_cascade_delay,

        loaded_at,
        source_file

    from delayed_flights

)

select *
from classified

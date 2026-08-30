with delayed_flights as (
    select *
    from {{ ref('int_flights_enriched') }}
    where is_arr_delayed = true
        and coalesce(
            carrier_delay_minutes,
            late_aircraft_delay_minutes,
            nas_delay_minutes,
            weather_delay_minutes,
            security_delay_minutes
        ) is not null
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
        airline_name_short,
        carrier_type,
        origin_airport_code,
        dest_airport_code,
        route_key,
        origin_state_code,
        dest_state_code,
        dep_time_of_day,
        is_weekend,
        route_distance_category,
        origin_is_major_hub,
        dest_is_major_hub,

        arr_delay_minutes,
        arr_delay_minutes_pos,
        total_cause_minutes,
        delay_severity,
        delay_severity_order,
        primary_delay_cause,

        -- Delay cause (minutes absolute)
        coalesce(carrier_delay_minutes, 0) as carrier_delay_minutes,
        coalesce(weather_delay_minutes, 0) as weather_delay_minutes,
        coalesce(nas_delay_minutes, 0) as nas_delay_minutes,
        coalesce(security_delay_minutes, 0) as security_delay_minutes,
        coalesce(late_aircraft_delay_minutes, 0) as late_aircraft_delay_minutes,

        -- Delay Cause percentage
        round(
            {{safe_divide(
                'coalesce(carrier_delay_minutes, 0),',
                'total_cause_minutes'
            )}} * 100, 2
        ) as carrier_delay_pct,

        round(
            {{
                safe_divide(
                    'coalesce(weather_delay_minutes, 0)',
                    'total_cause_minutes'
                )
            }} * 100, 2
        ) as weather_delay_pct,

        round(
            {{
                safe_divide(
                    'coalesce(nas_delay_minutes, 0)',
                    'total_cause_minutes'
                )
            }} * 100, 2
        ) as nas_delay_pct,

        round(
            {{
                safe_divide(
                    'coalesce(security_delay_minutes, 0)',
                    'total_cause_minutes'
                )
            }} * 100, 2
        ) as security_delay_pct,

        round(
            {{
                safe_divide(
                    'coalesce(late_aircraft_delay_minutes, 0)',
                    'total_cause_minutes'
                )
            }} * 100, 2
        ) as late_aircraft_delay_pct,

        -- Delay Cause Flags
        case
            when arr_delay_minutes_pos is null or arr_delay_minutes_pos = 0 then null
            when coalesce(carrier_delay_minutes, 0) > (arr_delay_minutes_pos * 0.5) then true
            else false
        end as carrier_is_dominant,

        case
            when arr_delay_minutes_pos is null or arr_delay_minutes_pos = 0 then null
            when coalesce(weather_delay_minutes, 0) > (arr_delay_minutes_pos * 0.5) then true
            else false
        end as weather_is_dominant,

        case
            when arr_delay_minutes_pos is null or arr_delay_minutes_pos = 0 then null
            when coalesce(nas_delay_minutes, 0) > (arr_delay_minutes_pos * 0.5) then true
            else false
        end as nas_is_dominant,

        case
            when arr_delay_minutes_pos is null or arr_delay_minutes_pos = 0 then null
            when coalesce(security_delay_minutes, 0) > (arr_delay_minutes_pos * 0.5) then true
            else false
        end as security_is_dominant,

        case
            when arr_delay_minutes_pos is null or arr_delay_minutes_pos = 0 then null
            when coalesce(late_aircraft_delay_minutes, 0) > (arr_delay_minutes_pos * 0.5) then true
            else false
        end as late_aircraft_is_dominant,

        -- Delay Magnitude Flags
        arr_delay_minutes_pos > 60 as is_over_1_hour,
        arr_delay_minutes_pos > 120 as is_over_2_hours,
        arr_delay_minutes_pos > 240 as is_over_4_hours,

        coalesce(late_aircraft_delay_minutes, 0) > 15 as is_cascade_delay

        loaded_at,
        source_file

    from delayed_flights

)

select * from classified
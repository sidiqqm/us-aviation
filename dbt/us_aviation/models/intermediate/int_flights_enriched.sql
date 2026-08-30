
-- MODEL INI:
--   1. Enrich flight data dengan nama maskapai dan bandara
--   2. Tambahkan business context flags (COVID period, season, dst)
--   3. Tambahkan delay severity categorization
--   4. Tambahkan time-of-day dan schedule attributes


with

flights as (
    select * from {{ ref('stg_on_time_performance') }}
),

-- Lookup maskapai
airlines as (
    select * from {{ ref('stg_airline_lookup') }}
),

-- Lookup bandara asal
origin_airports as (
    select
        airport_code,
        airport_name,
        city_name    as origin_city_name_clean,
        state_code   as origin_state_code_clean,
        is_major_hub as origin_is_major_hub
    from {{ ref('stg_airport_lookup') }}
),

-- Lookup bandara tujuan
dest_airports as (
    select
        airport_code,
        airport_name,
        city_name    as dest_city_name_clean,
        state_code   as dest_state_code_clean,
        is_major_hub as dest_is_major_hub
    from {{ ref('stg_airport_lookup') }}
),

delay_calc as (
    select
        flight_id,

        greatest(
            coalesce(carrier_delay_minutes,      0),
            coalesce(late_aircraft_delay_minutes, 0),
            coalesce(nas_delay_minutes,           0),
            coalesce(weather_delay_minutes,       0),
            coalesce(security_delay_minutes,      0)
        )                                        as max_delay_minutes,

        coalesce(
            carrier_delay_minutes,
            late_aircraft_delay_minutes,
            nas_delay_minutes,
            weather_delay_minutes,
            security_delay_minutes
        )                                        as any_cause_not_null

    from flights
),

-- menghilangkan duplikasi coalesce(is_major_hub, false) yang sebelumnya muncul 2x per bandara
hub_flags as (
    select
        f.flight_id,
        coalesce(oa.origin_is_major_hub, false) as origin_is_major_hub,
        coalesce(da.dest_is_major_hub,   false) as dest_is_major_hub
    from flights f
    left join origin_airports oa
        on f.origin_airport_code = oa.airport_code
    left join dest_airports da
        on f.dest_airport_code = da.airport_code
),

-- Core JOIN
enriched as (

    select

        f.flight_id,

        -- Dimensi Waktu
        f.flight_date,
        f.flight_year,
        f.flight_quarter,
        f.flight_month,
        f.flight_day_of_month,
        f.flight_day_of_week,
        f.day_of_week_name,

        case f.flight_month
            when 1  then 'January'
            when 2  then 'February'
            when 3  then 'March'
            when 4  then 'April'
            when 5  then 'May'
            when 6  then 'June'
            when 7  then 'July'
            when 8  then 'August'
            when 9  then 'September'
            when 10 then 'October'
            when 11 then 'November'
            when 12 then 'December'
        end as flight_month_name,

        case
            when f.flight_month in (12, 1, 2)   then 'Winter'
            when f.flight_month in (3, 4, 5)    then 'Spring'
            when f.flight_month in (6, 7, 8)    then 'Summer'
            when f.flight_month in (9, 10, 11)  then 'Fall'
        end as flight_season,

        case
            when f.flight_date < '2020-03-01'   then 'Pre-COVID'
            when f.flight_date < '2022-01-01'   then 'COVID-Impact'
            else 'Recovery'
        end as covid_period,

        f.flight_date >= '2020-03-01'
            and f.flight_date < '2022-01-01'    as is_covid_period,

        -- Maskapai
        f.carrier_code,
        coalesce(
            al.airline_name_full,
            f.carrier_code                       -- fallback jika tidak ada di lookup
        )                                        as airline_name_full,
        coalesce(
            al.airline_name_short,
            f.carrier_code
        )                                        as airline_name_short,
        coalesce(
            al.carrier_type,
            'Other'
        )                                        as carrier_type,

        f.tail_number,
        f.flight_number,

        -- Bandara Asal
        f.origin_airport_id,
        f.origin_airport_code,
        f.origin_city_name,
        coalesce(
            oa.origin_city_name_clean,
            f.origin_city_name
        ) as origin_city_name_clean,
        coalesce(
            oa.origin_state_code_clean,
            f.origin_state_code
        ) as origin_state_code,
        coalesce(
            oa.airport_name,
            f.origin_airport_code
        ) as origin_airport_name,
        hf.origin_is_major_hub,                 

        -- Bandara Tujuan
        f.dest_airport_id,
        f.dest_airport_code,
        f.dest_city_name,
        coalesce(
            da.dest_city_name_clean,
            f.dest_city_name
        ) as dest_city_name_clean,
        coalesce(
            da.dest_state_code_clean,
            f.dest_state_code
        ) as dest_state_code,
        coalesce(
            da.airport_name,
            f.dest_airport_code
        ) as dest_airport_name,
        hf.dest_is_major_hub,                   

        concat(f.origin_airport_code, '-', f.dest_airport_code) as route_key,

        hf.origin_is_major_hub and hf.dest_is_major_hub as is_hub_to_hub_route,

        -- Keberangkatan & Kedatangan
        f.scheduled_dep_time_hhmm,
        f.actual_dep_time_hhmm,
        f.scheduled_arr_time_hhmm,
        f.actual_arr_time_hhmm,
        f.taxi_out_minutes,
        f.taxi_in_minutes,
        f.wheels_off_time_hhmm,
        f.wheels_on_time_hhmm,

        case
            when f.scheduled_dep_time_hhmm between 500  and 859  then 'Early Morning (5-9am)'
            when f.scheduled_dep_time_hhmm between 900  and 1159 then 'Morning (9am-12pm)'
            when f.scheduled_dep_time_hhmm between 1200 and 1459 then 'Afternoon (12-3pm)'
            when f.scheduled_dep_time_hhmm between 1500 and 1759 then 'Late Afternoon (3-6pm)'
            when f.scheduled_dep_time_hhmm between 1800 and 2059 then 'Evening (6-9pm)'
            when f.scheduled_dep_time_hhmm between 2100 and 2359 then 'Night (9pm-12am)'
            when f.scheduled_dep_time_hhmm between 0    and 459  then 'Red-Eye (12-5am)'
            else 'Unknown'
        end as dep_time_of_day,

        f.flight_day_of_week in (6, 7) as is_weekend,

        -- Status
        f.is_cancelled,
        f.is_diverted,
        f.is_on_time,
        f.is_dep_delayed,
        f.is_arr_delayed,
        f.cancellation_code,
        f.cancellation_reason,

        -- Delay Metrics
        f.dep_delay_minutes,
        f.arr_delay_minutes,
        f.arr_delay_minutes_pos,

        case
            when f.is_cancelled              then null
            when f.arr_delay_minutes < 0     then 'Early'
            when f.arr_delay_minutes <= 15   then 'On Time'
            when f.arr_delay_minutes <= 45   then 'Minor Delay'
            when f.arr_delay_minutes <= 120  then 'Moderate Delay'
            when f.arr_delay_minutes <= 240  then 'Severe Delay'
            when f.arr_delay_minutes > 240   then 'Extreme Delay'
            else null
        end as delay_severity,

        -- Derived: Severity numeric order (untuk sorting di Power BI)
        case
            when f.is_cancelled              then null
            when f.arr_delay_minutes < 0     then 1
            when f.arr_delay_minutes <= 15   then 2
            when f.arr_delay_minutes <= 45   then 3
            when f.arr_delay_minutes <= 120  then 4
            when f.arr_delay_minutes <= 240  then 5
            when f.arr_delay_minutes > 240   then 6
            else null
        end as delay_severity_order,

        f.carrier_delay_minutes,
        f.weather_delay_minutes,
        f.nas_delay_minutes,
        f.security_delay_minutes,
        f.late_aircraft_delay_minutes,
        f.total_cause_minutes,

        case
            when dc.any_cause_not_null is null   then null
            when dc.max_delay_minutes = 0        then 'Unattributed'
            when f.carrier_delay_minutes
                 = dc.max_delay_minutes          then 'Carrier'
            when f.late_aircraft_delay_minutes
                 = dc.max_delay_minutes          then 'Late Aircraft'
            when f.nas_delay_minutes
                 = dc.max_delay_minutes          then 'NAS'
            when f.weather_delay_minutes
                 = dc.max_delay_minutes          then 'Weather'
            when f.security_delay_minutes
                 = dc.max_delay_minutes          then 'Security'
            else 'Unknown'
        end as primary_delay_cause,

        -- Durasi & Jarak
        f.scheduled_elapsed_minutes,
        f.actual_elapsed_minutes,
        f.air_time_minutes,
        f.distance_miles,
        f.distance_group,

        -- Ratio actual vs scheduled time (1.0 = perfect, >1.0 = longer than planned)
        {{ safe_divide('f.actual_elapsed_minutes', 'f.scheduled_elapsed_minutes') }} as schedule_efficiency_ratio,

        case
            when f.distance_miles < 250  then 'Short-Haul (<250mi)'
            when f.distance_miles < 750  then 'Medium-Haul (250-750mi)'
            when f.distance_miles < 1500 then 'Long-Haul (750-1500mi)'
            else 'Ultra Long-Haul (>1500mi)'
        end as route_distance_category,

        -- Metadata
        f.loaded_at,
        f.source_file

    from flights f

    left join airlines al
        on f.carrier_code = al.carrier_code

    left join origin_airports oa
        on f.origin_airport_code = oa.airport_code

    left join dest_airports da
        on f.dest_airport_code = da.airport_code

    left join delay_calc dc
        on f.flight_id = dc.flight_id

    left join hub_flags hf
        on f.flight_id = hf.flight_id

)

select * from enriched
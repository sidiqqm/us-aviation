with

flights as (
    select * from {{ ref('stg_on_time_perfomance') }}
),

airlines as (
    select * from {{ ref('stg_airline_lookup') }}
),

origin_airports as (
    select
        airport_code,
        airport_name,
        city_name as origin_city_name,
        state_code as origin_state_code,
        is_major_hub as origin_is_major_hub
    from {{ ref('stg_airport_lookup') }}
),

dest_airports as (
    select
        airport_code,
        airport_name,
        city_name as dest_city_name,
        state_code as dest_state_code,
        is_major_hub as dest_is_major_hub
    from {{ ref('stg_airport_lookup') }}
),

enriched as (
    select
        flight_id,

        -- dimensi waktu
        f.flight_date,
        f.flight_year,
        f.flight_quarter,
        f.flight_month,
        f.flight_day_of_month,
        f.flight_day_of_week,
        f.day_of_week_name,

        case f.flight_month
            when '1' then 'January'
            when '2' then 'February'
            when '3' then 'March'
            when '4' then 'April'
            when '5' then 'May'
            when '6' then 'June'
            when '7' then 'July'
            when '8' then 'August'
            when '9' then 'September'
            when '10' then 'October'
            when '11' then 'November'
            when '12' then 'December'
        end as flight_month_name,

        case
            when f.flight_month in (12, 1, 2) then 'Winter'
            when f.flight_month in (3, 4, 5)  then 'Spring'
            when f.flight_month in (6, 7, 8)  then 'Summer'
            when f.flight_month in (9, 10, 11)  then 'Fall'
        end as flight_season,

        case
            when f.flight_date < 2020-03-01 then "Pre-COVID"
            when f.flight_date < 2022-01-01 then "COVID-Impact"
            else then "Recovery"
        end as covid_period,


        -- Maskapai
        coalesce(
            al.airline_name_full,
            f.carrier_code
        ) as airline_name_full,

        coalesce(
            al.airline_name_short,
            f.carrier_code
        ) as airline_name_short,

        coalesce(
            al.carrier_type,
            'Other'
        ) as airline_type,

        f.tail_number,
        f.flight_number,

        -- Bandara Asal
        f.airport_id,
        f.origin_airport_code
        coalesce(
            oa.airport_name,
            f.origin_airport_code
        ) as origin_airport_name,

        coalesce(
            oa.origin_city_name,
            f.origin_city_name
        ) as origin_city_name,

        coalesce(
            oa.origin_state_code,
            f.origin_state_code
        ) as origin_state_code,

        coalesce(oa.origin_is_major_hub, false) as origin_is_major_hub

        

)
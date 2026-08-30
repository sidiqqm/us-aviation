-- GRAIN       : Satu baris = satu route × carrier × year × month
-- (aggregasi bulanan per rute per maskapai)

--   Agregasi bulanan kinerja rute untuk:
--   1. KPI per rute per bulan (OTP rate, avg delay, volume)
--   2. Moving average OTP untuk tren smoothing
--   3. Chronic delay route identification
--   4. Route ranking per carrier

with flights as (
    select *
    from {{ ref('int_flights_enriched') }}

    where not is_cancelled
)

-- Agregasi bulanan per rute
monthly_route as (
    select
        flight_year,
        flight_month,
        flight_month_name,
        flight_season,
        covid_period,

        date_trunc(flight_date, month) as flight_month_date,

        carrier_code,
        airline_name_short,
        carrier_type,
        route_key,
        origin_airport_code,
        dest_airport_code,
        origin_state_code,
        dest_state_code,
        origin_is_major_hub,
        dest_is_major_hub,
        route_distance_category,

        count(*) as total_operated_flights,
        count(is_arr_delayed) as delayed_flights,
        count(is_on_time) as on_time_flights,

        round(
            {{
                safe_divide(
                    'countif(is_on_time)',
                    'total_operated_flights'
                )
            }} * 100, 2
        ) as otp_rate_pct


        -- Delay metrics
        round(avg(arr_delay_minutes), 2) as avg_arr_delay_all,

        round(
            avg(
                case when is_arr_delayed then arr_delay_minutes end
            ), 2
        ) as avg_arr_delay_delayed_only,
        
        round(max(arr_delay_minutes), 2) as max_arr_delay,

        approx_quantile(arr_delay_minutes, 100)[offset(50)] as median_arr_delay,

        -- Delay total (minutes)
        round(sum(coalesce(carrier_delay_minutes, 0)), 0) as total_carrier_delay_min,
        round(sum(coalesce(weather_delay_minutes, 0)), 0) as total_weather_delay_min,
        round(sum(coalesce(nas_delay_minutes, 0)), 0) as total_nas_delay_min,
        round(sum(coalesce(security_delay_minutes, 0)), 0) as total_security_delay_min,
        round(sum(coalesce(late_aircraft_delay_minutes, 0)), 0) as total_late_aircraft_delay_min,

        round(sum(coalesce(total_cause_minutes, 0)), 0) as total_delay_minutes,

        round(avg(distance_miles), 2) as avg_distance_miles

    from flights
    group by
        flight_year,
        flight_month,
        flight_month_name,
        flight_season,
        covid_period,
        date_trunc(flight_date, month),
        carrier_code,
        airline_name_short,
        carrier_type,
        route_key,
        origin_airport_code,
        dest_airport_code,
        origin_state_code,
        dest_state_code,
        origin_is_major_hub,
        dest_is_major_hub,
        route_distance_category,
),

with_windows as (
    select
        *,
        round(
            avg(otp_rate_pct) over(
                partition by carrier_code, route_key
                order by flight_year, flight_month
                rows between 2 preceding and current row
            ), 2
        ) as otp_rate_3m_avg,

        lag(otp_rate_pct, 12) over(
            partition by carrier_code, route_key
            order by flight_year, flight_month
        ) as otp_rate_same_month_prev_year,

        lag(otp_rate_pct, 1) over(
            partition by carrier_code, route_key
            order by flight_year, flight_month
        ) as otp_rate_prev_month,

        rank() over(
            partition by carrier_code, flight_year, flight_month
            order by otp_rate_pct
        ) as route_rank_worst_otp,

        (otp_rate_pct < 70 and total_operated_flights >= 30) as is_below_chronic_threshold,

        lag(otp_rate_pct < 70 and total_operated_flights, 1) over(
            partition by carrier_code, route_key
            order by flight_year, flight_month
        ) as prev_month_below_threshold,

        lag(otp_rate_pct < 70 and total_operated_flights >= 30) over(
            partition by carrier_code, route_key
            order by flight_year, flight_month
        ) as prev2_month_below_threshold
    
    from monthly_route
),

with_dominant as (
    select
        *,
        greatest(
            total_carrier_delay_min,
            total_late_aircraft_delay_min,
            total_nas_delay_min,
            total_weather_delay_min,
            total_security_delay_min
        ) as max_cause_delay_min
    from with_windows
),

with final as (
    select
        *,
        (
            otp_rate_pct
            and coalesce(prev_month_below_threshold, false)
            and coalesce(prev2_month_below_threshold, false)
        ) as is_chronic_delay_route,

        case
            when otp_rate_pct >= 85 then 'Excellent (≥85%)'
            when otp_rate_pct >= 80 then 'Good (80-85%)'
            when otp_rate_pct >= 70 then 'Fair (70-80%)'
            when otp_rate_pct >= 60 then 'Poor (60-70%)'
            else 'Critical (<60%)'
        end as otp_performance_band,

        round(otp_rate_pct - otp_rate_prev_month, 2) as otp_rate_mom_change,
        round(otp_rate_pct - otp_rate_same_month_prev_year, 2) as otp_rate_yoy_change,

        case
            when total_delay_minutes = 0 then 'No Delay'
            when total_carrier_delay_min = max_cause_delay_min then 'Carrier'
            when total_weather_delay_min = max_cause_delay_min then 'Weather'
            when total_nas_delay_min = max_cause_delay_min then 'Weather'
            when total_security_delay_min = max_cause_delay_min then 'Weather'
            when total_late_aircraft_delay_min = max_cause_delay_min then 'Weather'
            else 'Unknown'
        end as dominant_delay_cause
    from with_dominant
)
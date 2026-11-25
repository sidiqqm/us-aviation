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
    where is_cancelled = false

),

route_universe as (

    select
        carrier_code,
        carrier_type,
        route_key,
        origin_airport_code,
        dest_airport_code,
        origin_state_code,
        dest_state_code,
        route_distance_category,

        min(date_trunc(flight_date, month)) as first_month,
        max(date_trunc(flight_date, month)) as last_month

    from flights

    group by
        carrier_code,
        carrier_type,
        route_key,
        origin_airport_code,
        dest_airport_code,
        origin_state_code,
        dest_state_code,
        route_distance_category

),

calendar_month_attributes as (

    select
        date_trunc(flight_date, month) as month_start,

        any_value(flight_season) as flight_season,
        any_value(covid_period) as covid_period

    from flights

    group by 1

),

calendar_spine as (

    select
        r.carrier_code,
        r.carrier_type,
        r.route_key,
        r.origin_airport_code,
        r.dest_airport_code,
        r.origin_state_code,
        r.dest_state_code,
        r.route_distance_category,

        month_start
    from route_universe r

    cross join unnest(
        generate_date_array(
            r.first_month,
            r.last_month,
            interval 1 month
        )
    ) as month_start

),

monthly_route as (

    select
        date_trunc(flight_date, month) as month_start,

        carrier_code,
        carrier_type,
        route_key,
        origin_airport_code,
        dest_airport_code,
        origin_state_code,
        dest_state_code,
        route_distance_category,

        count(*) as total_operated_flights,

        countif(is_arr_delayed) as delayed_flights,

        countif(is_on_time) as on_time_flights,

        countif(arr_delay_minutes is not null)
            as flights_with_valid_arr_delay,

        round(
            {{
                safe_divide(
                    'countif(is_on_time)',
                    'countif(arr_delay_minutes is not null)'
                )
            }} * 100,
            2
        ) as otp_rate_pct,

        -- Delay metrics
        round(avg(arr_delay_minutes), 2)
            as avg_arr_delay_all,

        round(
            avg(
                case
                    when is_arr_delayed
                    then arr_delay_minutes
                end
            ),
            2
        ) as avg_arr_delay_delayed_only,

        round(max(arr_delay_minutes), 2)
            as max_arr_delay,

        approx_quantiles(
            arr_delay_minutes,
            100
        )[offset(50)] as median_arr_delay,

        -- Delay cause totals
        sum(coalesce(carrier_delay_minutes, 0))
            as total_carrier_delay_min,

        sum(coalesce(weather_delay_minutes, 0))
            as total_weather_delay_min,

        sum(coalesce(nas_delay_minutes, 0))
            as total_nas_delay_min,

        sum(coalesce(security_delay_minutes, 0))
            as total_security_delay_min,

        sum(coalesce(late_aircraft_delay_minutes, 0))
            as total_late_aircraft_delay_min,

        sum(coalesce(total_cause_minutes, 0))
            as total_delay_minutes,

        round(avg(distance_miles), 2)
            as avg_distance_miles

    from flights

    group by
        month_start,
        carrier_code,
        carrier_type,
        route_key,
        origin_airport_code,
        dest_airport_code,
        origin_state_code,
        dest_state_code,
        route_distance_category

),

spine_monthly as (

    select
        -- Calendar attributes
        extract(year from s.month_start) as flight_year,
        extract(month from s.month_start) as flight_month,

        format_date('%B', s.month_start)
            as flight_month_name,

        extract(quarter from s.month_start)
            as flight_quarter,

        s.month_start,

        a.flight_season,
        a.covid_period,

        -- Route dimensions
        s.carrier_code,
        s.carrier_type,
        s.route_key,
        s.origin_airport_code,
        s.dest_airport_code,
        s.origin_state_code,
        s.dest_state_code,
        s.route_distance_category,

        -- Flight volume
        coalesce(m.total_operated_flights, 0)
            as total_operated_flights,

        coalesce(m.delayed_flights, 0)
            as delayed_flights,

        coalesce(m.on_time_flights, 0)
            as on_time_flights,

        coalesce(m.flights_with_valid_arr_delay, 0)
            as flights_with_valid_arr_delay,

        -- OTP
        m.otp_rate_pct,

        -- Delay metrics
        m.avg_arr_delay_all,
        m.avg_arr_delay_delayed_only,
        m.max_arr_delay,
        m.median_arr_delay,

        -- Delay cause totals
        coalesce(m.total_carrier_delay_min, 0)
            as total_carrier_delay_min,

        coalesce(m.total_weather_delay_min, 0)
            as total_weather_delay_min,

        coalesce(m.total_nas_delay_min, 0)
            as total_nas_delay_min,

        coalesce(m.total_security_delay_min, 0)
            as total_security_delay_min,

        coalesce(m.total_late_aircraft_delay_min, 0)
            as total_late_aircraft_delay_min,

        coalesce(m.total_delay_minutes, 0)
            as total_delay_minutes,

        m.avg_distance_miles

    from calendar_spine s

    left join monthly_route m
        on s.carrier_code = m.carrier_code
        and s.route_key = m.route_key
        and s.month_start = m.month_start

    left join calendar_month_attributes a
        on s.month_start = a.month_start

),

with_windows as (

    select
        *,

        round(
            {{
                safe_divide(
                    'sum(on_time_flights) over (partition by carrier_code, route_key order by month_start rows between 2 preceding and current row)',
                    'sum(flights_with_valid_arr_delay) over (partition by carrier_code, route_key order by month_start rows between 2 preceding and current row)'
                )
            }} * 100,
            2
        ) as otp_rate_3m_avg,

        lag(otp_rate_pct, 12) over (
            partition by carrier_code, route_key
            order by month_start
        ) as otp_rate_same_month_prev_year,

        lag(otp_rate_pct, 1) over (
            partition by carrier_code, route_key
            order by month_start
        ) as otp_rate_prev_month,

        coalesce(
            otp_rate_pct < 70
            and total_operated_flights >= 30,
            false
        ) as is_below_chronic_threshold,

        lag(
            coalesce(
                otp_rate_pct < 70
                and total_operated_flights >= 30,
                false
            ),
            1
        ) over (
            partition by carrier_code, route_key
            order by month_start
        ) as prev_month_below_threshold,

        lag(
            coalesce(
                otp_rate_pct < 70
                and total_operated_flights >= 30,
                false
            ),
            2
        ) over (
            partition by carrier_code, route_key
            order by month_start
        ) as prev2_month_below_threshold

    from spine_monthly

),

route_rankings as (

    select
        carrier_code,
        route_key,
        month_start,

        rank() over (
            partition by carrier_code, month_start
            order by otp_rate_pct asc
        ) as route_rank_worst_otp

    from spine_monthly

    where total_operated_flights >= 30
        and otp_rate_pct is not null

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


final as (

    select
        w.*,

        r.route_rank_worst_otp,

        (
            is_below_chronic_threshold
            and coalesce(prev_month_below_threshold, false)
            and coalesce(prev2_month_below_threshold, false)
        ) as is_chronic_delay_route,

        case
            when otp_rate_pct is null then 'No Operations / No Data'
            when otp_rate_pct >= 85 then 'Excellent (>=85%)'
            when otp_rate_pct >= 80 then 'Good (80-85%)'
            when otp_rate_pct >= 70 then 'Fair (70-80%)'
            when otp_rate_pct >= 60 then 'Poor (60-70%)'
            else 'Critical (<60%)'
        end as otp_performance_band,

        round(
            otp_rate_pct - otp_rate_prev_month,
            2
        ) as otp_rate_mom_change,

        round(
            otp_rate_pct - otp_rate_same_month_prev_year,
            2
        ) as otp_rate_yoy_change,

        -- Dominant delay cause
        case
            when total_operated_flights = 0
                then 'No Operations'

            when total_delay_minutes = 0
                then 'No Delay'

            when (
                case when total_carrier_delay_min = max_cause_delay_min then 1 else 0 end
                + case when total_late_aircraft_delay_min = max_cause_delay_min then 1 else 0 end
                + case when total_nas_delay_min = max_cause_delay_min then 1 else 0 end
                + case when total_weather_delay_min = max_cause_delay_min then 1 else 0 end
                + case when total_security_delay_min = max_cause_delay_min then 1 else 0 end
            ) > 1 then 'Multiple Causes'

            when total_carrier_delay_min = max_cause_delay_min
                then 'Carrier'

            when total_late_aircraft_delay_min = max_cause_delay_min
                then 'Late Aircraft'

            when total_nas_delay_min = max_cause_delay_min
                then 'NAS'

            when total_weather_delay_min = max_cause_delay_min
                then 'Weather'

            when total_security_delay_min = max_cause_delay_min
                then 'Security'

            else 'Unknown'
        end as dominant_delay_cause

    from with_dominant w

    left join route_rankings r
        on w.carrier_code = r.carrier_code
        and w.route_key = r.route_key
        and w.month_start = r.month_start

)

select *
from final
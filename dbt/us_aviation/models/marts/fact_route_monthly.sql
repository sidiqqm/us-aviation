-- dbt/us_aviation/models/marts/fact_route_monthly.sql
-- ============================================================
-- MODEL       : fact_route_monthly
-- LAYER       : Marts — Fact (Periodic Snapshot)
-- GRAIN       : Satu baris = satu carrier × route × year-month
-- ROWS        : ~90,000 rows
-- MATERIALIZED: table
--               Partitioned by flight_month_date (MONTH)
--               Clustered by carrier_code
--
-- Periodic snapshot fact table: merekam "kondisi" kinerja
-- setiap rute pada setiap bulan dalam periode analisis.
--
-- Berbeda dengan fact_flights (transactional), tabel ini
-- adalah pre-aggregated — cocok untuk:
-- - Trend analysis (OTP time series per rute)
-- - Executive dashboard (aggregated KPIs)
-- - Forecasting (data sudah dalam grain yang tepat)
-- - Power BI time intelligence functions
--
-- SEMI-ADDITIVE MEASURES:
-- otp_rate_pct, cancel_rate_pct, dan measures berbasis rate
-- TIDAK BOLEH di-SUM lintas rute — gunakan AVERAGEX di DAX
-- atau re-calculate dari komponen (on_time / total_operated).
-- ============================================================

with
route_stats as (
    select * from {{ ref('int_route_stats') }}
),
dim_date as (
    select 
        date_key, 
        full_date 
    from {{ ref('dim_date') }}
),
dim_carrier as (
    select 
        carrier_id, 
        carrier_code 
    from {{ ref('dim_carrier') }}
),

dim_airport as (
    select 
        airport_id, 
        airport_code 
    from {{ ref('dim_airport') }}
),
dim_route as (
    select 
        route_id, 
        route_key 
    from {{ ref('dim_route') }}
),

fact as (

    select

        {{ dbt_utils.generate_surrogate_key([
            'rs.carrier_code',
            'rs.route_key',
            'rs.flight_year',
            'rs.flight_month'
        ]) }} as route_monthly_id,

        d.date_key as month_date_key,
        c.carrier_id,
        r.route_id,
        oa.airport_id as origin_airport_id,
        da.airport_id as dest_airport_id,

        -- Untuk cancel rate: gunakan fact_flights atau tambahkan total_scheduled ke int_route_stats
        -- cancel_rate sudah ada di dim_carrier

        rs.flight_month_date,
        rs.flight_year,
        rs.flight_month,
        rs.flight_month_name,
        rs.flight_quarter,
        rs.flight_season,
        rs.covid_period,
        rs.carrier_code,
        rs.airline_name_short,
        rs.carrier_type,
        rs.route_key,
        rs.origin_airport_code,
        rs.dest_airport_code,
        rs.origin_state_code,
        rs.dest_state_code,
        rs.route_distance_category,

        rs.otp_performance_band,
        rs.dominant_delay_cause,

        -- [FIX] Di-cast ke INT64 — konsisten dengan fact_flights
        -- agar bisa di-SUM langsung di Power BI
        cast(rs.is_chronic_delay_route as INT64) as is_chronic_delay_route,
        cast(rs.origin_is_major_hub    as INT64) as origin_is_major_hub,
        cast(rs.dest_is_major_hub      as INT64) as dest_is_major_hub,

        rs.total_operated_flights,
        rs.delayed_flights,
        rs.on_time_flights,

        -- Semi-Additive Measures — OTP Rates
        -- JANGAN SUM lintas rute/bulan
        -- on_time_flights / total_operated_flights
        rs.otp_rate_pct,
        rs.otp_rate_3m_avg,
        rs.otp_rate_prev_month,
        rs.otp_rate_same_month_prev_year,
        rs.otp_rate_mom_change,
        rs.otp_rate_yoy_change,

        -- Semi-Additive / Non-Additive Measures — Delay ─
        -- ini bukan additive — tidak bisa di-SUM

        rs.avg_arr_delay_all,
        rs.avg_arr_delay_delayed_only,
        rs.max_arr_delay,
        rs.median_arr_delay,

        -- Additive Measures — Delay Cause (Total Menit)
        -- Ini truly additive — bisa di-SUM lintas bulan/rute
        rs.total_carrier_delay_min,
        rs.total_weather_delay_min,
        rs.total_nas_delay_min,
        rs.total_security_delay_min,
        rs.total_late_aircraft_delay_min,
        rs.total_delay_minutes,

        -- Semi-Additive — Delay Cause Share (%) ─────────
        -- JANGAN SUM — re-calc dari total menit jika perlu
        round(
            {{ safe_divide(
                'rs.total_carrier_delay_min',
                'rs.total_delay_minutes'
            ) }} * 100, 2
        ) as carrier_delay_share_pct,

        round(
            {{ safe_divide(
                'rs.total_late_aircraft_delay_min',
                'rs.total_delay_minutes'
            ) }} * 100, 2
        ) as late_aircraft_delay_share_pct,

        round(
            {{ safe_divide(
                'rs.total_nas_delay_min',
                'rs.total_delay_minutes'
            ) }} * 100, 2
        ) as nas_delay_share_pct,

        round(
            {{ safe_divide(
                'rs.total_weather_delay_min',
                'rs.total_delay_minutes'
            ) }} * 100, 2
        ) as weather_delay_share_pct,

        round(
            {{ safe_divide(
                'rs.total_security_delay_min',
                'rs.total_delay_minutes'
            ) }} * 100, 2
        ) as security_delay_share_pct,

        rs.avg_distance_miles,

        rs.route_rank_worst_otp,

        current_timestamp() as dw_last_refreshed_at

    from route_stats rs
    left join dim_date d on rs.flight_month_date = d.full_date
    left join dim_carrier c on rs.carrier_code = c.carrier_code
    left join dim_airport oa on rs.origin_airport_code = oa.airport_code
    left join dim_airport da on rs.dest_airport_code = da.airport_code
    left join dim_route r on rs.route_key = r.route_key

)

select * from fact
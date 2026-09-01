
-- GRAIN       : Satu baris = satu scheduled flight segment
--               (operated + cancelled, non-diverted)
-- MATERIALIZED: table
--               Partitioned by flight_date (MONTH)
--               Clustered by carrier_code, origin_airport_code

-- DESIGN DECISIONS:
-- 1. Menyimpan BOTH surrogate key (untuk proper DW join)
--    DAN natural key (untuk readability dan ad-hoc query)
-- 2. Semua boolean flags di-cast ke INT64 (0/1) agar
--    dapat di-SUM langsung di Power BI dan SQL
-- 3. Degenerate dimensions (delay_severity, covid_period, dll.)
--    disertakan langsung di fact table untuk menghindari
--    join yang tidak perlu di Power BI queries
-- 4. flight_count = 1 selalu, untuk kemudahan SUM aggregation

with

flights as (
    select * from {{ ref('int_flights_enriched') }}
),

dim_date as (
    select date_key, full_date
    from {{ ref('dim_date') }}
),

dim_carrier as (
    select carrier_id, carrier_code
    from {{ ref('dim_carrier') }}
),

dim_airport as (
    select airport_id, airport_code
    from {{ ref('dim_airport') }}
),

dim_route as (
    select route_id, route_key
    from {{ ref('dim_route') }}
),

fact as (

    select

        f.flight_id,

        d.date_key,
        c.carrier_id,
        oa.airport_id as origin_airport_id,
        da.airport_id as dest_airport_id,
        r.route_id,

        f.flight_date,
        f.carrier_code,
        f.origin_airport_code,
        f.dest_airport_code,
        f.route_key,

        f.flight_number,
        f.tail_number,
        f.flight_year,
        f.flight_quarter,
        f.flight_month,
        f.flight_day_of_week,
        f.day_of_week_name,
        f.flight_month_name,
        f.flight_season,
        f.covid_period,
        f.dep_time_of_day,
        f.delay_severity,
        f.delay_severity_order,
        f.primary_delay_cause,
        f.cancellation_reason,
        f.carrier_type,
        f.route_distance_category,

        cast(f.is_cancelled as INT64) as is_cancelled,
        cast(f.is_arr_delayed as INT64) as is_arr_delayed,
        cast(f.is_dep_delayed as INT64) as is_dep_delayed,
        cast(f.is_on_time as INT64) as is_on_time,
        cast(f.is_weekend as INT64) as is_weekend,
        cast(f.is_hub_to_hub_route as INT64) as is_hub_to_hub_route,
        cast(f.is_covid_period as INT64) as is_covid_period,
        cast(f.origin_is_major_hub as INT64) as origin_is_major_hub,
        cast(f.dest_is_major_hub as INT64) as dest_is_major_hub,

        -- Diverted tidak muncul di data (sudah difilter),
        -- tapi flag ini dipertahankan sebagai audit trail = selalu 0
        cast(f.is_diverted           as INT64) as is_diverted,

        -- Additive Measures — Delay (menit)
        -- NULL dipertahankan untuk cancelled: agar AVG tetap akurat
        f.arr_delay_minutes,
        f.arr_delay_minutes_pos,
        f.dep_delay_minutes,

        -- Additive Measures — Delay Cause
        -- NULL jika on-time atau cancelled (MAR, by design)
        f.carrier_delay_minutes,
        f.weather_delay_minutes,
        f.nas_delay_minutes,
        f.security_delay_minutes,
        f.late_aircraft_delay_minutes,
        f.total_cause_minutes,

        -- Additive Measures — Operations
        f.air_time_minutes,
        f.actual_elapsed_minutes,
        f.scheduled_elapsed_minutes,
        f.taxi_out_minutes,
        f.taxi_in_minutes,
        f.distance_miles,

        -- schedule_efficiency_ratio removed,
        -- rawan disalahgunakan dengan SUM() di Power BI karena hasilnya gak akurat seperti kasus otp_rate_pct.
        -- Hitung di DAX nanti DIVIDE(SUM(actual_elapsed), SUM(scheduled_elapsed)) lebih akurat (true weighted ratio)

        1 as flight_count,

        -- Metadata
        f.loaded_at,
        f.source_file

    from flights f
    left join dim_date d on f.flight_date = d.full_date
    left join dim_carrier c on f.carrier_code = c.carrier_code
    left join dim_airport oa on f.origin_airport_code = oa.airport_code
    left join dim_airport da on f.dest_airport_code = da.airport_code
    left join dim_route r on f.route_key = r.route_key

)

select * from fact
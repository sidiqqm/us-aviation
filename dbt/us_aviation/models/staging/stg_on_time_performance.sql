-- GRAIN : 1 baris 1 schedule

-- TRANSFORMASI YANG DILAKUKAN : 
--   1. Rename kolom ke snake_case konsisten
--   2. Cast tipe data ke tipe BigQuery yang tepat
--   3. Generate surrogate key (flight_id)
--   4. Derive boolean flags (is_cancelled, is_delayed, dll.)
--   5. Derive cancellation_reason dari CancellationCode
--   6. Konversi HHMM integer ke format waktu yang readable
--   7. Hanya filter: exclude diverted flights (analisis terpisah)
--   8. Keep _loaded_at dan _source_file untuk lineage

with source as (
    select * from {{ source('raw', 'on_time_performance') }}
),

renamed as (
    select
        {{ dbt_utils.generate_surrogate_key([
            'FL_DATE',
            'OP_UNIQUE_CARRIER',
            'OP_CARRIER_FL_NUM',
            'ORIGIN',
            'DEST'
        ]) }} as flight_id,

        -- Waktu
        cast(FL_DATE as DATE) as flight_date,
        cast(YEAR as INT64) as flight_year,
        cast(QUARTER as INT64) as flight_quarter,
        cast(MONTH as INT64) as flight_month,
        cast(DAY_OF_MONTH as INT64) as flight_day_of_month,
        cast(DAY_OF_WEEK as INT64) as flight_day_of_week,
        
        case cast(DAY_OF_WEEK as INT64)
            when 1 then 'Monday'
            when 2 then 'Tuesday'
            when 3 then "Wednesday"
            when 4 then "Thursday"
            when 5 then "Friday"
            when 6 then "Saturday"
            when 7 then "Sunday"
            else "Unknown"
        end as day_of_week_name,

        -- Identifikasi Penerbangan
        cast(OP_UNIQUE_CARRIER as STRING) as carrier_code,
        cast(TAIL_NUM as STRING) as tail_number,
        cast(OP_CARRIER_FL_NUM as STRING) as flight_number,

        -- Rute
        cast(ORIGIN_AIRPORT_ID as INT64) as origin_airport_id,
        cast(ORIGIN as STRING) as origin_airport_code,
        cast(ORIGIN_CITY_NAME as STRING) as origin_city_name,
        cast(ORIGIN_STATE_ABR as STRING) as origin_state_code,

        cast(DEST_AIRPORT_ID as INT64) as dest_airport_id,
        cast(DEST as STRING) as dest_airport_code,
        cast(DEST_CITY_NAME as STRING) as dest_city_name,
        cast(DEST_STATE_ABR as STRING) as dest_state_code,

        -- Jadwal Keberangkatan
        cast(CRS_DEP_TIME as INT64) as scheduled_dep_time_hhmm,
        cast(DEP_TIME as FLOAT64) as actual_dep_time_hhmm,
        cast(DEP_DELAY as FLOAT64) as dep_delay_minutes,
        cast(DEP_DELAY_NEW as FLOAT64) as dep_delay_minutes_pos,
        cast(DEP_DEL15 as FLOAT64) = 1 as is_dep_delayed,
        cast(TAXI_OUT as FLOAT64) as taxi_out_minutes,
        cast(WHEELS_OFF as FLOAT64) as wheels_off_time_hhmm,

        -- Jadwal Kedatangan
        cast(WHEELS_ON as FLOAT64) as wheels_on_time_hhmm,
        cast(TAXI_IN as FLOAT64) as taxi_in_minutes,
        cast(CRS_ARR_TIME as INT64) as scheduled_arr_time_hhmm,
        cast(ARR_TIME as FLOAT64) as actual_arr_time_hhmm,
        cast(ARR_DELAY as FLOAT64) as arr_delay_minutes,
        cast(ARR_DELAY_NEW as FLOAT64) as arr_delay_minutes_pos,
        cast(ARR_DEL15 as FLOAT64) = 1 as is_arr_delayed,

        -- Status Flags
        cast(CANCELLED as FLOAT64) = 1 as is_cancelled,
        cast(DIVERTED as FLOAT64) = 1 as is_diverted,

        -- Derived : Ontime = tidak cancelled dan tidak delayed
        case
            when cast(CANCELLED as FLOAT64) = 1 then null
            when cast(ARR_DEL15 as FLOAT64) = 0 then true
            when cast(ARR_DEL15 as FLOAT64) = 1 then false
        end as is_on_time,

        cast(CANCELLATION_CODE as STRING) as cancellation_code,

        case cast(CANCELLATION_CODE as STRING)
            when 'A' then 'Carrier'
            when 'B' then 'Weather'
            when 'C' then 'National Air System'
            when 'D' then 'Security'
            else null -- berarti tidak dibatalkan
        end as cancellation_reason,

        -- Durasi Penerbangan
        cast(CRS_ELAPSED_TIME as FLOAT64) as scheduled_elapsed_minutes,
        cast(ACTUAL_ELAPSED_TIME as FLOAT64) as actual_elapsed_minutes,
        cast(AIR_TIME as FLOAT64) as air_time_minutes,
        cast(DISTANCE as FLOAT64) as distance_miles,
        cast(DISTANCE_GROUP as INT64) as distance_group,

        -- Penyebab Delay
        cast(CARRIER_DELAY as FLOAT64) as carrier_delay_minutes,
        cast(WEATHER_DELAY as FLOAT64) as weather_delay_minutes,
        cast(NAS_DELAY as FLOAT64) as nas_delay_minutes,
        cast(SECURITY_DELAY as FLOAT64) as security_delay_minutes,
        cast(LATE_AIRCRAFT_DELAY as FLOAT64) as late_aircraft_delay_minutes,

        -- Total Delay
        coalesce(cast(CARRIER_DELAY as FLOAT64), 0)
        + coalesce(cast(WEATHER_DELAY as FLOAT64), 0)
        + coalesce(cast(NAS_DELAY as FLOAT64), 0)
        + coalesce(cast(SECURITY_DELAY as FLOAT64), 0)
        + coalesce(cast(LATE_AIRCRAFT_DELAY as FLOAT64), 0)
        as total_cause_minutes,

        -- Metadata
        cast(_loaded_at as TIMESTAMP) as loaded_at,
        cast(_source_file as STRING) as source_file
    from source
), 

final as (
    select * from renamed
    where is_diverted = false
)

select * from final
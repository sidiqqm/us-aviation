-- 1. Total Row per Count

SELECT
    EXTRACT(YEAR FROM FL_DATE) AS year,
    COUNT(*) AS total_row
    SUM(CANCELLED) AS cancelled_flights
FROM `us-aviation-analytics.raw.on_time_performance`
GROUP BY year
ORDER BY year

-- 2. Row Count per Month

SELECT
    EXTRACT(YEAR FROM FL_DATE) AS year,
    EXTRACT(MONTH FROM FL_DATE) AS month,
    COUNT(*) AS row_count,
    MIN(FL_DATE) AS first_date,
    MAX(FL_DATE) AS last_date
FROM `us-aviation-analytics.raw.on_time_performance`
GROUP BY year, month
ORDER BY year, month

-- 3. Carrier Distribution
SELECT
    OP_UNIQUE_CARRIER AS reporting_airline,
    COUNT(*) AS total_flights,
    MIN(FL_DATE) AS first_flight,
    MAX(FL_DATE) AS last_flight,
    COUNT(DISTINCT EXTRACT(YEAR FROM FL_DATE)) AS year_present
FROM `us-aviation-analytics.raw.on_time_performance`
GROUP BY OP_UNIQUE_CARRIER
ORDER BY total_flights DESC

-- 4. NULL Rate Pada Key Column
SELECT
    COUNTIF(FL_DATE IS NULL) / COUNT(*) * 100 AS pct_null_flight_date,
    COUNTIF(OP_UNIQUE_CARRIER IS NULL) / COUNT(*) * 100 AS pct_null_carrier,
    COUNTIF(ORIGIN IS NULL) / COUNT(*) * 100 AS pct_null_origin,
    COUNTIF(DEST IS NULL) / COUNT(*) * 100 AS pct_dest_origin,
    COUNTIF(ARR_DELAY IS NULL) / COUNT(*) * 100 AS pct_arrdel_origin,
    COUNTIF(ARR_DEL15 IS NULL) / COUNT(*) * 100 AS pct_arr_del15_origin
FROM `us-aviation-analytics.raw.on_time_performance`

-- 5. Delay Cause Coverage

SELECT
    ARR_DEL15 AS delay_15,
    CANCELLED AS cancelled,
    COUNTIF(CARRIER_DELAY IS NOT NULL) has_carrier_delay,
    COUNTIF(WEATHER_DELAY IS NOT NULL) has_weather_delay,
    ROUND(COUNTIF(CARRIER_DELAY IS NOT NULL) / COUNT(*) * 100, 2) AS pct_has_cause_data
FROM `us-aviation-analytics.raw.on_time_perfomance`
GROUP BY ARR_DEL15, CANCELLED
ORDER BY delay_15, cancelled

-- 6. Metadata Validation

SELECT
    COUNTIF(_loaded_at IS NULL) AS null_loaded_at,
    COUNTIF(_source_file IS NULL) AS null_source_file,
    COUNT(DISTINCT _source_file) AS distinct_source_file,
    MIN(_loaded_at) AS earliest_loaded_file,
    MAX(_loaded_at) AS latest_loaded_file
FROM `us-aviation-analytics.raw.on_time_performance`

-- 7. Lookup Table Validation

SELECT 'airline_lookup' AS table_name, COUNT(*) AS row_count
FROM `us-aviation-analytics.raw.airline_lookup`
UNION ALL
SELECT 'airport_lookup' AS table_name, COUNT(*) AS row_count
FROM `us-aviation-analytics.raw.airport_lookup`

-- 8. Reconsiliation Join Test

SELECT
    o.OP_UNIQUE_CARRIER AS reporting_airline,
    COUNT(*) AS flight_count,
    MAX(a.Description) AS airline_name
FROM `us-aviation-analytics.raw.on_time_performance` o
LEFT JOIN `us-aviation-analytics.raw.airline_lookup` a
    ON CAST(o.OP_UNIQUE_CARRIER AS STRING) = CAST(a.Code AS STRING)

-- 9. Duplicate Check

SELECT
    FL_DATE,
    OP_UNIQUE_CARRIER,
    OP_CARRIER,
    ORIGIN,
    DEST,
    COUNT(*) AS occurence_count
FROM `us-aviation-analytics.raw.on_time_perfomance`
GROUP BY FL_DATE, OP_UNIQUE_CARRIER, OP_CARRIER, ORIGIN, DEST
ORDER BY occurence_count DESC
LIMIT 20
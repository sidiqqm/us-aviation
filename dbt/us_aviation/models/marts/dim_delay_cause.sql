-- dbt/us_aviation/models/marts/dim_delay_cause.sql
-- ============================================================
-- MODEL       : dim_delay_cause
-- LAYER       : Marts — Dimension
-- GRAIN       : Satu baris = satu kategori penyebab delay
-- ROWS        : 6 rows (static reference table)
-- MATERIALIZED: table
--
-- Static reference table — nilai berasal dari definisi domain
-- DOT/BTS, bukan dari source flight data.
--
-- Digunakan sebagai:
--   1. Lookup untuk delay cause analysis di Power BI
--   2. Slicer dimension — filter by cause category
--   3. Reference untuk controllability segmentation
--
-- Unattributed ditambahkan untuk menangani delayed flights
-- yang tidak memiliki delay cause yang dapat diatribusikan.
-- ============================================================

with delay_causes as (

    select
        1 as delay_cause_id,
        'carrier' as delay_cause_code,
        'Carrier Delay' as delay_cause_name,
        'Internal' as delay_cause_category,
        'carrier_delay_minutes' as fact_column_name,
        'Delay caused by circumstances within the airline''s control: maintenance, crew problems, aircraft cleaning, baggage loading, fueling'
            as cause_definition,
        true as is_controllable_by_airline

    union all

    select
        2,
        'late_aircraft',
        'Late Aircraft Delay',
        'Internal',
        'late_aircraft_delay_minutes',
        'Delay caused by a previous flight with the same aircraft arriving late, causing a ripple effect (cascade delay)',
        true

    union all

    select
        3,
        'nas',
        'NAS Delay',
        'External',
        'nas_delay_minutes',
        'Delay attributable to the National Aviation System: non-extreme weather conditions, airport operations, heavy traffic volume, air traffic control',
        false

    union all

    select
        4,
        'weather',
        'Weather Delay',
        'External',
        'weather_delay_minutes',
        'Delay caused by extreme weather conditions: hurricanes, blizzards, heavy snow, icing, low ceilings, visibility',
        false

    union all

    select
        5,
        'security',
        'Security Delay',
        'External',
        'security_delay_minutes',
        'Delay caused by security issues: evacuation of gate area, re-boarding due to security breach, inoperative screening equipment, long lines',
        false

    union all

    select
        6,
        'unattributed',
        'Unattributed Delay',
        'Unattributed',
        null,
        'Flight arrived delayed but no specific delay cause was attributed.',
        null

)

select
    delay_cause_id,
    delay_cause_code,
    delay_cause_name,
    delay_cause_category,
    fact_column_name,
    cause_definition,
    is_controllable_by_airline,
    current_timestamp() as dw_last_refreshed_at

from delay_causes
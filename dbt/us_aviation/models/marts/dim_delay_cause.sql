-- GRAIN       : Satu baris = satu kategori penyebab delay
-- Digunakan sebagai:
--   1. Lookup untuk delay cause analysis di Power BI
--   2. Slicer dimension — filter by cause category
--   3. Reference untuk controllability segmentation


with delay_causes as (

    select
        1 as delay_cause_id,
        'carrier' as delay_cause_code,
        'Carrier Delay' as delay_cause_name,
        'Airline Operations' as operational_domain,
        'carrier_delay_minutes' as fact_column_name,
        'Delay caused by circumstances within the airline control, such as maintenance, crew problems, aircraft cleaning, baggage loading, and fueling.' as cause_definition,
        'Direct' as controllability_class

    union all

    select
        2,
        'late_aircraft',
        'Late Aircraft Delay',
        'Aircraft Rotation',
        'late_aircraft_delay_minutes',
        'Delay caused by a previous flight with the same aircraft arriving late, resulting in a cascading delay.',
        'Indirect'

    union all

    select
        3,
        'nas',
        'NAS Delay',
        'National Aviation System',
        'nas_delay_minutes',
        'Delay attributable to the National Aviation System, including air traffic control, airport operations, and non-extreme weather conditions.',
        'External'

    union all

    select
        4,
        'weather',
        'Weather Delay',
        'Weather',
        'weather_delay_minutes',
        'Delay caused by extreme weather conditions, such as hurricanes, blizzards, heavy snow, icing, low ceilings, and poor visibility.',
        'External'

    union all

    select
        5,
        'security',
        'Security Delay',
        'Security',
        'security_delay_minutes',
        'Delay caused by security issues, such as evacuation of gate areas, security breaches, inoperative screening equipment, and long security lines.',
        'External'

)

select
    delay_cause_id,
    delay_cause_code,
    delay_cause_name,
    operational_domain,
    fact_column_name,
    cause_definition,
    controllability_class

from delay_causes

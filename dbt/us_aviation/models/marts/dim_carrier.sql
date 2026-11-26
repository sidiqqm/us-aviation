with airlines as (
    select
        carrier_id,
        carrier_code,
        
        trim(
            regexp_extract(airline_name_full, r'^([^:]+):')
        ) as airline_name,

        carrier_type,
        carrier_code in ('AA', 'DL', 'UA', 'WN') as is_big4_carrier,

        carrier_code in (
            'AA', 'DL', 'UA', 'WN', 'AS',
            'B6', 'NK', 'F9', 'G4', 'HA'
        ) as is_major_carrier,

        current_timestamp() as dw_last_refreshed_at
    
    from {{ref("stg_airline_lookup")}}
)

select * from airlines
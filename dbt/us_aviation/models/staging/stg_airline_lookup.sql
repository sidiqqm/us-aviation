-- TRANSFORMASI:
--   1. Rename kolom ke snake_case
--   2. Ekstrak carrier_code dan airline_name dari sumber
--   3. Tambah kategorisasi maskapai (carrier_type)

with

source as (

    select * from {{ source('raw', 'airline_lookup') }}

),

renamed as (

    select
        cast(Code as STRING)        as carrier_code,
        cast(Description as STRING) as airline_name_full,

        -- Ekstrak nama pendek (sebelum " Inc.", " Co.", dll.)
        regexp_replace(
            cast(Description as STRING),
            r'\s+(Inc\.|Co\.|LLC|Corp\.|Ltd\.|Airlines|Air Lines|Airways|Air|dba\s.*)$',
            ''
        ) as airline_name_short,

        case cast(Code as STRING)
            when 'AA' then 'Legacy'
            when 'DL' then 'Legacy'
            when 'UA' then 'Legacy'
            when 'WN' then 'Low-Cost'
            when 'B6' then 'Low-Cost'
            when 'AS' then 'Mid-Size'
            when 'NK' then 'Ultra Low-Cost'
            when 'F9' then 'Ultra Low-Cost'
            when 'G4' then 'Ultra Low-Cost'
            when 'HA' then 'Regional'
            when 'MQ' then 'Regional'
            when 'OO' then 'Regional'
            when 'YX' then 'Regional'
            when 'OH' then 'Regional'
            when 'QX' then 'Regional'
            when '9E' then 'Regional'
            when 'YV' then 'Regional'
            else 'Other'
        end as carrier_type,

        cast(_loaded_at as TIMESTAMP) as loaded_at,
        cast(_source_file as STRING)  as source_file

    from source

    qualify row_number() over (
        partition by cast(Code as STRING)
        order by cast(_loaded_at as TIMESTAMP) desc
    ) = 1

)

select * from renamed
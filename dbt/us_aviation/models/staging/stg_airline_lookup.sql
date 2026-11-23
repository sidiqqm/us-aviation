-- TRANSFORMASI:
--   1. Rename kolom ke snake_case
--   2. Ekstrak carrier_code dan airline_name_short (kode IATA/ICAO setelah ":")
--   3. Tambah kategorisasi maskapai (carrier_type) berdasarkan airline_name_short

with

source as (

    select * from {{ source('raw', 'airline_lookup') }}

),

deduped as (

    select * from source
    qualify row_number() over (
        partition by cast(Code as STRING)
        order by cast(_loaded_at as TIMESTAMP) desc
    ) = 1

),

extracted as (

    select
        cast(Code as STRING) as carrier_id,
        cast(Description as STRING) as airline_name_full,

        -- Ekstrak teks setelah tanda ":" (contoh: "Mackey International Inc.: MAC" -> "MAC")
        trim(
            regexp_extract(cast(Description as STRING), r':\s*([^:]+)$')
        ) as airline_name_short,

        cast(_loaded_at as TIMESTAMP) as loaded_at,
        cast(_source_file as STRING)  as source_file

    from deduped

),

final as (

    select
        carrier_id,
        airline_name_short as carrier_code,
        airline_name_full,

        -- Gunakan airline_name_short yang sudah diekstrak untuk mapping carrier_type
        case airline_name_short
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

        loaded_at,
        source_file

    from extracted

)

select * from final
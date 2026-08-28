
-- TRANSFORMASI:
--   1. Rename kolom ke snake_case
--   2. Parse Description menjadi komponen: city, state, airport_name
--   3. Identifikasi hub bandara utama

with

source as (

    select * from {{ source('raw', 'airport_lookup') }}

),

renamed as (

    select
        cast(Code as STRING)        as airport_code,
        cast(Description as STRING) as airport_description_full,

        -- Parse format: "Atlanta, GA: Hartsfield-Jackson Atlanta International"
        trim(split(cast(Description as STRING), ',')[safe_offset(0)]) as city_name,

        -- Ekstrak state code (2 karakter setelah koma, sebelum ':')
        trim(
            split(
                split(cast(Description as STRING), ',')[safe_offset(1)],
                ':'
            )[safe_offset(0)]
        ) as state_code,

        -- Ekstrak nama bandara (setelah ':')
        trim(
            split(cast(Description as STRING), ':')[safe_offset(1)]
        ) as airport_name,

        -- Flag: apakah ini hub bandara besar (Top 30 busiest US airports)
        cast(Code as STRING) in (
            'ATL', 'DFW', 'DEN', 'ORD', 'LAX', 'JFK', 'LAS', 'MCO',
            'CLT', 'PHX', 'SEA', 'MIA', 'IAH', 'BOS', 'SFO', 'MSP',
            'DTW', 'FLL', 'EWR', 'LGA', 'BWI', 'SLC', 'SAN', 'DCA',
            'MDW', 'HNL', 'PDX', 'DAL', 'STL', 'BNA'
        ) as is_major_hub,

        cast(_loaded_at as TIMESTAMP) as loaded_at,
        cast(_source_file as STRING)  as source_file

    from source

    qualify row_number() over (
        partition by cast(Code as STRING)
        order by cast(_loaded_at as TIMESTAMP) desc
    ) = 1

)

select * from renamed
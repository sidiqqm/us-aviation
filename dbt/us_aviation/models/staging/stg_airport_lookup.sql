
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
        safe_cast(Code as STRING) as airport_id,
        cast(Description as STRING) as airport_description_full,

        trim(
            split(cast(Description as STRING), ',')[safe_offset(0)]
        ) as city_name,

        trim(
            split(
                split(cast(Description as STRING), ',')[safe_offset(1)],
                ':'
            )[safe_offset(0)]
        ) as state_code,

        trim(
            split(cast(Description as STRING), ':')[safe_offset(1)]
        ) as airport_name,

        cast(_loaded_at as TIMESTAMP) as loaded_at,
        cast(_source_file as STRING) as source_file

    from source

    qualify row_number() over (
        partition by safe_cast(Code as INT64)
        order by cast(_loaded_at as TIMESTAMP) desc
    ) = 1

)

select * from renamed
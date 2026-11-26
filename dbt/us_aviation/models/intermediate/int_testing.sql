with testing as (
    select
        *
    from {{ ref("stg_airport_lookup") }}
    where airport_id = '10397'
)

select * from testing
with testing as (
    select
        carrier_code,
        count(*) as total_count
    from {{ ref("stg_on_time_performance") }}
    where is_arr_delayed is null
    group by carrier_code
)

select * from testing
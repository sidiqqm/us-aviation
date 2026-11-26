with testing as (
    select *
    from {{ ref("stg_on_time_performance") }}
)

select * from testing
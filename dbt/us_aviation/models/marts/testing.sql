with testing as (
    select 
        total_operated_flights,
        count(*) as total_rows
    from {{ref("int_route_stats")}}
    where total_operated_flights is null
    group by total_operated_flights
)
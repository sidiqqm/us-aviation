with airports as (
    select
        airport_id,
        city_name,
        state_code,
        airport_name,
        case
            when state_code in ('ME', 'VT', 'RI', 'NY', 'PA', 'NH', 'MA', 'CT', 'NJ') then 'Northeast'
            when state_code in ('OH', 'MI', 'IN', 'IL', 'WI', 'MN', 'IA', 'MO', 'ND', 'SD', 'NE', 'KS') then 'Midwest'
            when state_code in ('DE', 'MD', 'DC', 'VA', 'WV', 'NC', 'SC', 'GA', 'FL', 'KY', 'TN', 'AL', 'MS', 'AR', 'LA', 'OK', 'TX') then 'South'
            when state_code in ('MT', 'ID', 'WY', 'CO', 'NM', 'AZ', 'UT', 'NV', 'WA', 'OR', 'CA', 'AK', 'HI') then 'West'
            else 'Other'
        end as us_region,
        loaded_at
    from {{ ref("stg_airport_lookup") }}
),

origin_dest_airports as (
    select
        origin_airport_id as airport_id,
        origin_airport_code as airport_code
    from {{ref("int_flights_enriched")}}

    union distinct

    select
        dest_airport_id as airport_id,
        dest_airport_code as airport_code
    from {{ref("int_flights_enriched")}}
),

joined as (
    select
        a.airport_id,
        oda.airport_code,
        a.city_name,
        a.state_code,
        a.airport_name,
        a.us_region,
        a.loaded_at
    from airports a
    inner join origin_dest_airports oda
        on a.airport_id = oda.airport_id
),

final as (
    select
        airport_id,
        airport_code,
        city_name,
        state_code,
        airport_name,
        us_region,
        case 
            when airport_code in (
                'ATL', 'DFW', 'DEN', 'ORD', 'LAX', 'JFK', 'LAS', 'MCO',
                'CLT', 'PHX', 'SEA', 'MIA', 'IAH', 'BOS', 'SFO', 'MSP',
                'DTW', 'FLL', 'EWR', 'LGA', 'BWI', 'SLC', 'SAN', 'DCA',
                'MDW', 'HNL', 'PDX', 'DAL', 'STL', 'BNA'
            ) then true
            else false
        end as is_major_hub,
        loaded_at

    from joined
)

select * from enriched
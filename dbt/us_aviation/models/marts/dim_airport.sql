with airports as (
    select * from {{ ref('stg_airport_lookup') }}
),

origin_stats as (
    select
        origin_airport_code as airport_code,
        count(*) as total_origin_departure,
        countif(not is_cancelled) as total_origin_operated,
        round(
            avg(
                case
                    when not is_cancelled then dep_delay_minutes
                end
            ), 2
        ) as avg_delay_as_origin,

        round(
            {{
                safe_divide(
                    'countif(not is_cancelled and is_on_time)',
                    'countif(not is_cancelled)'
                )
            }} * 100, 2
            
        ) as otp_rate_as_origin_pct,
    from {{ ref('int_flights_enriched') }}
    group by origin_airport_code
),

dest_stats as (
    select
        dest_airport_code as airport_code,
        count(*) as total_dest_arrivals,

        round(
            avg(
                case
                    when not is_cancelled then arr_delay_minutes
            ), 2
        ) as avg_arr_delay_as_dest,
        
        round(
            {{
                safe_divide(
                    'countif(not is_cancelled and is_on_time)',
                    'countif(not is_cancelled)'
                )
            }}  * 100, 2
        ) as otp_rate_as_dest_pct

    from {{ ref('int_flights_enriched') }}
    group by dest_airport_code
),

joined as (
    select
        {{ dbt_utils.generate_surrogate_key(['airport_code']) }} as airport_key,

        a.airport_code,
        a.airport_name,
        a.city_name,
        a.state_code,
        a.is_major_hub,

        case a.state_code
            when 'ME' then 'Northeast'
            when 'VT' then 'Northeast'
            when 'RI' then 'Northeast'
            when 'NY' then 'Northeast'
            when 'PA' then 'Northeast'
            when 'NH' then 'Northeast'
            when 'MA' then 'Northeast'
            when 'CT' then 'Northeast'
            when 'NJ' then 'Northeast'
            when 'OH' then 'Midwest'
            when 'MI' then 'Midwest'
            when 'IN' then 'Midwest'
            when 'IL' then 'Midwest'
            when 'WI' then 'Midwest'
            when 'MN' then 'Midwest'
            when 'IA' then 'Midwest'
            when 'MO' then 'Midwest'
            when 'ND' then 'Midwest'
            when 'SD' then 'Midwest'
            when 'NE' then 'Midwest'
            when 'KS' then 'Midwest'
            when 'DE' then 'South'     
            when 'MD' then 'South'
            when 'DC' then 'South'     
            when 'VA' then 'South'
            when 'WV' then 'South'     
            when 'NC' then 'South'
            when 'SC' then 'South'     
            when 'GA' then 'South'
            when 'FL' then 'South'     
            when 'KY' then 'South'
            when 'TN' then 'South'     
            when 'AL' then 'South'
            when 'MS' then 'South'     
            when 'AR' then 'South'
            when 'LA' then 'South'     
            when 'OK' then 'South'
            when 'TX' then 'South'
            when 'MT' then 'West'      
            when 'ID' then 'West'
            when 'WY' then 'West'      
            when 'CO' then 'West'
            when 'NM' then 'West'      
            when 'AZ' then 'West'
            when 'UT' then 'West'      
            when 'NV' then 'West'
            when 'WA' then 'West'      
            when 'OR' then 'West'
            when 'CA' then 'West'      
            when 'AK' then 'West'
            when 'HI' then 'West'
            else 'Other'
        end as us_region,

        coalesce(os.total_origin_departure) as total_origin_departure,
        coalesce(os.total_origin_operated) as total_origin_operated,
        os.avg_delay_as_origin,
        os.otp_rate_as_origin_pct,

        coalesce(od.total_dest_arrivals) as total_dest_arrivals,
        od.avg_arr_delay_as_dest,
        od.otp_rate_as_dest_pct

    from airports a
    left join origin_stats os
        on a.airport_code = os.airport_code
    left join dest_stats ds
        on a.airport_code = ds.airport_code

)

select * from joined
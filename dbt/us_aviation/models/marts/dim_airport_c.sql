with airports as (
    select
        *,
        upper(trim(airport_code)) as clean_airport_code
    from {{ ref('stg_airport_lookup') }}
),

origin_stats as (
    select
        upper(trim(origin_airport_code)) as airport_code,
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
        ) as otp_rate_as_origin_pct
    from {{ ref('int_flights_enriched') }}
    group by 1
),

dest_stats as (
    select
        upper(trim(dest_airport_code)) as airport_code,
        count(*) as total_dest_arrivals,
        round(
            avg(
                case
                    when not is_cancelled then arr_delay_minutes
                end
            ), 2
        ) as avg_arr_delay_as_dest,
        round(
            {{
                safe_divide(
                    'countif(not is_cancelled and is_on_time)',
                    'countif(not is_cancelled)'
                )
            }} * 100, 2
        ) as otp_rate_as_dest_pct
    from {{ ref('int_flights_enriched') }}
    group by 1
),

joined as (
    select
        {{ dbt_utils.generate_surrogate_key(['a.clean_airport_code']) }} as airport_id,

        a.clean_airport_code as airport_code,
        a.airport_name,
        a.city_name,
        a.state_code,
        a.is_major_hub,

        case
            when a.state_code in ('ME', 'VT', 'RI', 'NY', 'PA', 'NH', 'MA', 'CT', 'NJ') then 'Northeast'
            when a.state_code in ('OH', 'MI', 'IN', 'IL', 'WI', 'MN', 'IA', 'MO', 'ND', 'SD', 'NE', 'KS') then 'Midwest'
            when a.state_code in ('DE', 'MD', 'DC', 'VA', 'WV', 'NC', 'SC', 'GA', 'FL', 'KY', 'TN', 'AL', 'MS', 'AR', 'LA', 'OK', 'TX') then 'South'
            when a.state_code in ('MT', 'ID', 'WY', 'CO', 'NM', 'AZ', 'UT', 'NV', 'WA', 'OR', 'CA', 'AK', 'HI') then 'West'
            else 'Other'
        end as us_region,

        -- Tambahkan nilai default 0 pada COALESCE
        coalesce(os.total_origin_departure, 0) as total_origin_departure,
        coalesce(os.total_origin_operated, 0) as total_origin_operated,
        os.avg_delay_as_origin,
        os.otp_rate_as_origin_pct,

        coalesce(ds.total_dest_arrivals, 0) as total_dest_arrivals,
        ds.avg_arr_delay_as_dest,
        ds.otp_rate_as_dest_pct

    from airports a
    left join origin_stats os
        on a.clean_airport_code = os.airport_code
    left join dest_stats ds
        on a.clean_airport_code = ds.airport_code
)

select * from joined
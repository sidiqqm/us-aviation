with airlines as (
    select * from {{ ref('stg_airline_lookup') }}
),

flight_stats as (
    select
        carrier_code,
        count(*) as total_scheduled_flights,
        countif(not is_cancelled) as total_operated_flights,
        countif(is_cancelled) as total_cancelled_flights,
        countif(not is_cancelled and is_arr_delayed) as total_delayed_flights,

        round(
            {{
                safe_divide(
                    'countif(not is_cancelled and is_on_time)',
                    'countif(not is_cancelled)'
                )
            }} * 100, 2
        ) as overall_otp_rate_pct,

        round(
            {{
                safe_divide(
                    'countif(is_cancelled)',
                    'count(*)'
                )
            }} * 100, 2
        ) as overall_cancel_rate_pct,

        round(
            avg(
                case
                    when not is_cancelled then arr_delay_minutes
                end
            ), 2
        ) as avg_arr_delay_minutes,

        min(flight_date) as first_flight_date,
        max(flight_date) as last_flight_date,
        count(
            distinct concat(origin_airport_code, '-', dest_airport_code)
        ) as unique_routes_served

    from {{ ref('int_flights_enriched') }}
    group by carrier_code
),

joined as (
    select
        {{ dbt_utils.generate_surrogate_key(['a.carrier_code']) }} as carrier_id,

        a.carrier_code,
        a.airline_name_full,
        a.airline_name_short,
        a.carrier_type,

        a.carrier_code in ('AA', 'DL', 'UA', 'WN') as is_big4_carrier,

        a.carrier_code in (
            'AA', 'DL', 'UA', 'WN', 'AS',
            'B6', 'NK', 'F9', 'G4', 'HA'
        ) as is_major_carrier,

        coalesce(f.total_scheduled_flights, 0) as total_scheduled_flights,
        coalesce(f.total_operated_flights, 0) as total_operated_flights,
        coalesce(f.total_cancelled_flights, 0) as total_cancelled_flights,
        coalesce(f.total_delayed_flights, 0) as total_delayed_flights,

        f.overall_otp_rate_pct,
        f.overall_cancel_rate_pct,
        f.avg_arr_delay_minutes,
        f.first_flight_date,
        f.last_flight_date,
        coalesce(f.unique_routes_served, 0) as unique_routes_served,

        current_timestamp() as dw_last_refreshed_at

    from airlines a
    left join flight_stats f
        on a.carrier_code = f.carrier_code
)

select * from joined
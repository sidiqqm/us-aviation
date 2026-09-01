-- GRAIN       : Satu baris = satu kombinasi origin-dest unik
--               (directional: ATL→LAX ≠ LAX→ATL)
-- CATATAN GRAIN int_route_stats:
--   route × carrier × year × month
--   → satu route bisa punya banyak rows per bulan (multi-carrier)
--   → months_operated dan chronic_delay_months harus pakai
--     count(distinct ...) bukan count(*) untuk menghindari
--     double-counting per carrier

with

route_base as (

    select
        route_key,
        origin_airport_code,
        dest_airport_code,
        origin_state_code,
        dest_state_code,
        origin_is_major_hub,
        dest_is_major_hub,
        route_distance_category,

        sum(total_operated_flights) as lifetime_flights,

        -- Raw counts untuk weighted OTP — lebih akurat dari avg(pct)
        -- Lihat: avg(otp_rate_pct) memberi bobot sama ke setiap bulan
        -- meski volume penerbangan per bulan berbeda
        sum(on_time_flights) as lifetime_on_time_flights,

        max(avg_distance_miles) as route_distance_miles,

        round(min(otp_rate_pct), 2) as min_otp_rate,
        round(max(otp_rate_pct), 2) as max_otp_rate,

        count(distinct carrier_code) as carriers_serving_route,

        -- → satu bulan bisa punya N rows jika N carrier melayani rute ini
        -- → count(*) akan overcount sebesar jumlah carrier per bulan
        count(
            distinct concat(
                cast(flight_year as string),
                '-',
                cast(flight_month as string)
            )
        ) as months_operated,

        count(
            distinct case
                when is_chronic_delay_route
                then concat(
                    cast(flight_year  as string),
                    '-',
                    cast(flight_month as string)
                )
            end
        ) as chronic_delay_months

    from {{ ref('int_route_stats') }}
    group by
        route_key,
        origin_airport_code,
        dest_airport_code,
        origin_state_code,
        dest_state_code,
        origin_is_major_hub,
        dest_is_major_hub,
        route_distance_category

),

with_otp_rate as (

    select
        *,
        round(
            {{ safe_divide(
                'lifetime_on_time_flights',
                'lifetime_flights'
            ) }} * 100, 2
        ) as lifetime_otp_rate_pct

    from route_base

),

enriched as (

    select

        {{ dbt_utils.generate_surrogate_key(['route_key']) }} as route_id,

        route_key,

        origin_airport_code,
        dest_airport_code,
        origin_state_code,
        dest_state_code,
        origin_is_major_hub,
        dest_is_major_hub,

        case
            when origin_state_code is null
              or dest_state_code   is null then null
            when origin_state_code
               = dest_state_code         then false
            else true
        end as is_interstate_route,

        origin_is_major_hub and dest_is_major_hub as is_hub_to_hub,

        route_distance_category,
        route_distance_miles,

        lifetime_flights,
        lifetime_otp_rate_pct,
        min_otp_rate,
        max_otp_rate,

        round(
            max_otp_rate - min_otp_rate, 2
        ) as otp_rate_range,

        carriers_serving_route,
        months_operated,
        chronic_delay_months,

        chronic_delay_months > 0 as has_chronic_delay_history,

        case
            when lifetime_otp_rate_pct >= 85 then 'Excellent (≥85%)'
            when lifetime_otp_rate_pct >= 80 then 'Good (80-85%)'
            when lifetime_otp_rate_pct >= 70 then 'Fair (70-80%)'
            when lifetime_otp_rate_pct >= 60 then 'Poor (60-70%)'
            else 'Critical (<60%)'
        end as lifetime_otp_band,

        current_timestamp() as dw_last_refreshed_at

    from with_otp_rate

)

select * from enriched
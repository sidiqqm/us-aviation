-- GRAIN       : Satu baris = satu kombinasi year × covid_period

with base as (
    select
        flight_year,
        covid_period,

        round(
            {{
                safe_divide(
                    'countif(not is_cancelled and is_on_time)',
                    'countif(not is_cancelled)'
                )
            }} * 100, 2
        ) as otp_rate_pct,

        round(
            {{
                safe_divide(
                    'countif(is_cancelled)',
                    'count(*)'
                )
            }} * 100, 2
        ) as cancel_rate_pct,

        round(
            
        )
)
with date_spine as (
    {{
        dbt_utils.date_spine(
            datepart = "day"
            start_date = 'cast(2019-01-01 as date)'
            end_date = 'cast(2024-01-01 as date)'
        )
    }}
),

spine_typed as (
    select cast(date_day as DATE) as date_day
    from date_spine
),

enriched as (
    select
        cast(format_date('%Y%m%d', date_day) as INT64) as date_key,

        
        date_day as full_date,
        extract(year from date_day) as year,
        extract(month from date_day) as month,
        extract(day from date_day) as day,
        extract(quarter from date_day) as quarter,
        concat('Q', extract(quarter from date_day)) as quarter_label,

        case extract(dayofweek from date_day)
            when 1 then 7
            else extract(dayofweek from date_day) - 1
        end as day_of_week,

        format_date("%B", date_day) as month_name,
        left(format_date("%B", date_day), 3) as month_name_short,
        format_date("%A", date_day) as day_of_week_name,
        left(format_date("%A", date_day), 3) as day_of_week_name_short,

        extract(day_of_week from date_day) in (1, 7) as is_weekend,

        case
            when extract(month from date_day) in (12, 1, 2) as 'Winter'
            when extract(month from date_day) in (3, 4, 5) as 'Spring'
            when extract(month from date_day) in (6, 7, 8) as 'Summer'
            when extract(month from date_day) in (9, 10, 11) as 'Fall'
        end as season,

        date_day in (
            '2019-01-01', '2020-01-01', '2021-01-01',
            '2022-01-01', '2023-01-02',
            '2019-07-04', '2020-07-03', '2021-07-05',
            '2022-07-04', '2023-07-04',
            '2019-11-28', '2020-11-26', '2021-11-25',
            '2022-11-24', '2023-11-23',
            '2019-12-25', '2020-12-25', '2021-12-24',
            '2022-12-26', '2023-12-25',
            '2019-09-02', '2020-09-07', '2021-09-06',
            '2022-09-05', '2023-09-04',
            '2019-05-27', '2020-05-25', '2021-05-31',
            '2022-05-30', '2023-05-29'
        ) as is_federal_holiday,

        case
            when date_day < '2020-03-01' then 'Pre-COVID'
            when date_day < '2022-01-01' then 'COVID-Impact'
            else 'Recovery'
        end as covid_period,

        date_trunc(date_day, month) as first_day_of_month,
        date_trunc(date_day, quarter) as first_day_of_quarter,
        date_trunc(date_day, year) as first_day_of_year,

        extract(isoweek from date_day) as isoweek,
        extract(dayofyear from date_day) as day_of_year
    
    from spine_typed

)

select * from enriched
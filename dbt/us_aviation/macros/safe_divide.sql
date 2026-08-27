-- MACRO : safe_divide
-- TUJUAN: Pembagian yang aman — return NULL jika denominator = 0
--          Mencegah division by zero error dalam KPI calculations
-- USAGE  : {{ safe_divide('numerator_col', 'denominator_col') }}

{% macro safe_divide(numerator, denominator) %}

    CASE
        WHEN {{ denominator }} = 0 OR {{ denominator }} IS NULL
        THEN NULL
        ELSE {{ numerator }} / {{ denominator }}
    END

{% endmacro %}
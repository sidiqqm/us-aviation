-- MACRO : generate_surrogate_key
-- TUJUAN: Membuat surrogate key dari kombinasi kolom
--          menggunakan MD5 hash.
-- PENGGUNAAN  : {{ generate_surrogate_key(['col1', 'col2', 'col3']) }}

-- Catatan: dbt_utils sudah menyediakan generate_surrogate_key,
-- tapi kita buat versi custom untuk transparansi dan kontrol.
-- Kita akan menggunakan {{ dbt_utils.generate_surrogate_key() }}
-- di model, tapi macro ini menjelaskan cara kerjanya.

{% macro generate_surrogate_key(field_list) %}

    {% set fields = [] %}

    {%- for field in field_list -%}

        {%- set _ = fields.append(
            "coalesce(cast(" ~ field ~ " as " ~ dbt.type_string() ~ "), '_dbt_null')"
        ) -%}

    {%- endfor -%}

    to_hex(md5(concat({{ fields | join(", '-', ") }})))

{% endmacro %}
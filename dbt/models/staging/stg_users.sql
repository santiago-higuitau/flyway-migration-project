with fuente as (

    select * from {{ source('raw_library', 'users') }}

),

casteado as (

    select
        id::integer         as user_id,
        name::string        as name,
        registered_at::date as registered_at,
        status::string      as status,
        birth_date::date    as birth_date,
        email::string       as email,
        phone::string       as phone

    from fuente

)

select * from casteado

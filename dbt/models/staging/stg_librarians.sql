with fuente as (

    select * from {{ source('raw_library', 'librarians') }}

),

casteado as (

    select
        id::integer    as librarian_id,
        name::string   as name,
        hired_at::date as hired_at,
        status::string as status,
        email::string  as email,
        role::string   as role

    from fuente

)

select * from casteado

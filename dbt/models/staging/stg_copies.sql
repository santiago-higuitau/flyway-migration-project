with fuente as (

    select * from {{ source('raw_library', 'copies') }}

),

casteado as (

    select
        id::integer               as copy_id,
        edition_id::integer       as edition_id,
        inventory_code::string    as inventory_code,
        status::string            as status,
        acquired_at::date         as acquired_at,
        physical_location::string as physical_location

    from fuente

)

select * from casteado

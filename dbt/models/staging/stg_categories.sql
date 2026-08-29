with fuente as (

    select * from {{ source('raw_library', 'categories') }}

),

casteado as (

    select
        id::integer          as category_id,
        name::string         as name,
        description::string  as description

    from fuente

)

select * from casteado

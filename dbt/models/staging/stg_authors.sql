with fuente as (

    select * from {{ source('raw_library', 'authors') }}

),

casteado as (

    select
        id::integer            as author_id,
        name::string           as name,
        place_of_birth::string as place_of_birth,
        nationality::string    as nationality,
        birth_date::date       as birth_date,
        death_date::date       as death_date

    from fuente

)

select * from casteado

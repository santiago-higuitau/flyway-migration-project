with fuente as (

    select * from {{ source('raw_library', 'editions') }}

),

casteado as (

    select
        id::integer             as edition_id,
        book_id::integer        as book_id,
        publisher::string       as publisher,
        release_year::integer   as release_year,
        page_count::integer     as page_count,
        language::string        as language,
        replacement_cost::float as replacement_cost_usd

    from fuente

)

select * from casteado

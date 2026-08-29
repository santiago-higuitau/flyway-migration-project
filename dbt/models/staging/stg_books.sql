with fuente as (

    select * from {{ source('raw_library', 'books') }}

),

casteado as (

    select
        id::integer               as book_id,
        title::string             as title,
        isbn::string              as isbn,
        original_language::string as original_language

    from fuente

)

select * from casteado

-- Tabla bridge (muchos a muchos): un libro puede pertenecer a varias categorías, y
-- una categoría agrupa varios libros.

with fuente as (

    select * from {{ source('raw_library', 'books_categories') }}

),

casteado as (

    select
        book_id::integer     as book_id,
        category_id::integer as category_id

    from fuente

)

select * from casteado

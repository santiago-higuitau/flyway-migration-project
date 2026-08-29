-- Tabla bridge (muchos a muchos): un libro puede tener varios autores, y un autor
-- puede haber escrito varios libros.

with fuente as (

    select * from {{ source('raw_library', 'books_authors') }}

),

casteado as (

    select
        book_id::integer   as book_id,
        author_id::integer as author_id

    from fuente

)

select * from casteado

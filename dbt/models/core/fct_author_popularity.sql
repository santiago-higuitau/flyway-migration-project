-- ¿Qué autores generan más préstamos y mejores reseñas?
-- Grano: una fila por autor. Un libro con varios autores aporta sus préstamos y
-- reseñas a cada uno (vía stg_books_authors) — un autor no "compite" por el crédito
-- de un libro coescrito, lo recibe completo, igual que cualquier coautor.

with prestamos_por_libro as (

    select
        editions.book_id,
        count(loans.loan_id) as total_loans

    from {{ ref('stg_loans') }} as loans
    inner join {{ ref('stg_copies') }} as copies
        on loans.copy_id = copies.copy_id
    inner join {{ ref('stg_editions') }} as editions
        on copies.edition_id = editions.edition_id
    group by editions.book_id

),

resenas_por_libro as (

    select
        book_id,
        avg(rating)               as avg_rating,
        count(distinct review_id) as total_reviews

    from {{ ref('stg_book_reviews') }}
    group by book_id

),

libros_por_autor as (

    select
        books_authors.author_id,
        count(distinct books_authors.book_id)             as total_books,
        sum(coalesce(prestamos_por_libro.total_loans, 0))  as total_loans,
        sum(coalesce(resenas_por_libro.total_reviews, 0))  as total_reviews,
        avg(resenas_por_libro.avg_rating)                  as avg_rating

    from {{ ref('stg_books_authors') }} as books_authors
    left join prestamos_por_libro
        on books_authors.book_id = prestamos_por_libro.book_id
    left join resenas_por_libro
        on books_authors.book_id = resenas_por_libro.book_id
    group by books_authors.author_id

),

final as (

    select
        authors.author_id,
        authors.name        as author_name,
        authors.nationality,
        coalesce(libros_por_autor.total_books, 0)  as total_books,
        coalesce(libros_por_autor.total_loans, 0)  as total_loans,
        coalesce(libros_por_autor.total_reviews, 0) as total_reviews,
        libros_por_autor.avg_rating

    from {{ ref('stg_authors') }} as authors
    left join libros_por_autor
        on authors.author_id = libros_por_autor.author_id

)

select * from final

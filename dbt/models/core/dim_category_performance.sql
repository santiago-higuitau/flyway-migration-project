-- ¿Qué categorías/géneros se prestan más y tienen mejor reseña?
-- Grano: una fila por categoría. Un libro con varias categorías aporta sus
-- préstamos y reseñas a cada una (vía stg_books_categories); no se divide entre
-- categorías, igual que fct_author_popularity no divide entre coautores.

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

libros_por_categoria as (

    select
        books_categories.category_id,
        count(distinct books_categories.book_id)           as total_books,
        sum(coalesce(prestamos_por_libro.total_loans, 0))   as total_loans,
        sum(coalesce(resenas_por_libro.total_reviews, 0))   as total_reviews,
        avg(resenas_por_libro.avg_rating)                   as avg_rating

    from {{ ref('stg_books_categories') }} as books_categories
    left join prestamos_por_libro
        on books_categories.book_id = prestamos_por_libro.book_id
    left join resenas_por_libro
        on books_categories.book_id = resenas_por_libro.book_id
    group by books_categories.category_id

),

final as (

    select
        categories.category_id,
        categories.name as category_name,
        coalesce(libros_por_categoria.total_books, 0)  as total_books,
        coalesce(libros_por_categoria.total_loans, 0)  as total_loans,
        coalesce(libros_por_categoria.total_reviews, 0) as total_reviews,
        libros_por_categoria.avg_rating

    from {{ ref('stg_categories') }} as categories
    left join libros_por_categoria
        on categories.category_id = libros_por_categoria.category_id

)

select * from final

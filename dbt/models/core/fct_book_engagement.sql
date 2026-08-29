-- ¿Cuáles libros se prestan más, y cuáles tienen mejor reseña?
-- Grano: una fila por libro. Cruza préstamos (relacional: loans -> copies ->
-- editions -> books) con reseñas de lectores (semi-estructurado: stg_book_reviews).

with resenas_por_libro as (

    select
        book_id,
        avg(rating)                as avg_rating,
        count(distinct review_id)  as total_reviews

    from {{ ref('stg_book_reviews') }}
    group by book_id

),

prestamos_por_libro as (

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

final as (

    select
        books.book_id,
        books.title,
        coalesce(prestamos_por_libro.total_loans, 0) as total_loans,
        resenas_por_libro.avg_rating,
        coalesce(resenas_por_libro.total_reviews, 0) as total_reviews

    from {{ ref('stg_books') }} as books
    left join prestamos_por_libro
        on books.book_id = prestamos_por_libro.book_id
    left join resenas_por_libro
        on books.book_id = resenas_por_libro.book_id

)

select * from final

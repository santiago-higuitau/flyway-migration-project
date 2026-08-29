-- ¿Cuántas copias hay por edición, y cuántas están dañadas?
-- Grano: una fila por edición. damaged_value_usd cuantifica el costo de reposición
-- de las copias dañadas de esa edición.

with copias_por_edicion as (

    select
        edition_id,
        count(*)                           as total_copies,
        count_if(status = 'available')     as available_copies,
        count_if(status = 'loaned')        as loaned_copies,
        count_if(status = 'damaged')       as damaged_copies

    from {{ ref('stg_copies') }}
    group by edition_id

),

final as (

    select
        editions.edition_id,
        editions.book_id,
        books.title,
        editions.publisher,
        editions.release_year,
        editions.replacement_cost_usd,
        coalesce(copias_por_edicion.total_copies, 0)     as total_copies,
        coalesce(copias_por_edicion.available_copies, 0) as available_copies,
        coalesce(copias_por_edicion.loaned_copies, 0)    as loaned_copies,
        coalesce(copias_por_edicion.damaged_copies, 0)   as damaged_copies,
        coalesce(copias_por_edicion.damaged_copies, 0) * editions.replacement_cost_usd as damaged_value_usd

    from {{ ref('stg_editions') }} as editions
    left join {{ ref('stg_books') }} as books
        on editions.book_id = books.book_id
    left join copias_por_edicion
        on editions.edition_id = copias_por_edicion.edition_id

)

select * from final

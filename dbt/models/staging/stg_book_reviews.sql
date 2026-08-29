with fuente as (

    select * from {{ source('raw_book_reviews', 'raw_reviews') }}

),

resenas as (

    select
        fuente.raw_data:book_id::integer   as book_id,
        fuente.raw_data:isbn::string       as isbn,
        fuente.raw_data:title::string      as title,
        r.value:review_id::string          as review_id,
        r.value:reviewer_name::string      as reviewer_name,
        r.value:rating::integer            as rating,
        r.value:comment::string            as comment,
        r.value:submitted_at::date         as submitted_at,
        r.value:verified_loan::boolean     as verified_loan,
        r.value:tags                       as tags

    from fuente,
         lateral flatten(input => fuente.raw_data:reviews) r

),

con_tags as (

    select
        resenas.* exclude tags,
        t.value::string as tag

    from resenas,
         lateral flatten(input => resenas.tags, outer => true) t

)

select * from con_tags

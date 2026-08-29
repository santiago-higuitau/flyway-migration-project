with fuente as (

    select * from {{ source('raw_library', 'loans') }}

),

casteado as (

    select
        id::integer           as loan_id,
        copy_id::integer      as copy_id,
        user_id::integer      as user_id,
        librarian_id::integer as librarian_id,
        loan_date::date       as loan_date,
        due_date::date        as due_date,
        returned_at::date     as returned_at
 
    from fuente

)

select * from casteado

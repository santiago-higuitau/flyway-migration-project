with fuente as (

    select * from {{ source('raw_library', 'penalties') }}

),

casteado as (

    select
        id::integer                  as penalty_id,
        loan_id::integer             as loan_id,
        reason::string               as reason,
        issued_at::date              as issued_at,
        base_fee::float              as base_fee_usd,
        total_fee::float             as total_fee_usd,
        paid::boolean                as paid,
        try_to_date(paid_at::string) as paid_at

    from fuente

)

select * from casteado

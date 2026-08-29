-- ¿Qué usuarios están morosos y con cuánto valor de mora?
-- Grano: una fila por usuario. Moroso = tiene al menos un préstamo con due_date
-- pasada y sin devolver. El valor de mora es la suma de multas ya generadas y sin
-- pagar (no todo préstamo vencido tiene multa creada todavía).

with prestamos as (

    select * from {{ ref('stg_loans') }}

),

prestamos_vencidos as (

    select
        user_id,
        loan_id,
        datediff('day', due_date, current_date()) as days_overdue

    from prestamos
    where returned_at is null
      and due_date < current_date()

),

mora_por_usuario as (

    select
        user_id,
        count(distinct loan_id) as overdue_loans,
        max(days_overdue)       as max_days_overdue

    from prestamos_vencidos
    group by user_id

),

multas_no_pagadas as (

    select
        prestamos.user_id,
        sum(penalties.total_fee_usd) as unpaid_penalty_usd

    from prestamos
    inner join {{ ref('stg_penalties') }} as penalties
        on prestamos.loan_id = penalties.loan_id
    where penalties.paid = false
    group by prestamos.user_id

),

final as (

    select
        users.user_id,
        users.name   as user_name,
        users.status as user_status,
        coalesce(mora_por_usuario.overdue_loans, 0)   as overdue_loans,
        mora_por_usuario.max_days_overdue,
        coalesce(multas_no_pagadas.unpaid_penalty_usd, 0) as unpaid_penalty_usd,
        coalesce(mora_por_usuario.overdue_loans, 0) > 0   as is_delinquent

    from {{ ref('stg_users') }} as users
    left join mora_por_usuario
        on users.user_id = mora_por_usuario.user_id
    left join multas_no_pagadas
        on users.user_id = multas_no_pagadas.user_id

)

select * from final

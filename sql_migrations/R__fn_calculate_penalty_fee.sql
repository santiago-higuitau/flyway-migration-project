-- Compound late fee: 7-day grace period, then 5% per full week overdue.
-- payment_date is an explicit argument (not now()) so the function stays
-- IMMUTABLE: same inputs, same output, regardless of when it is called.

CREATE OR REPLACE FUNCTION fn_calculate_penalty_fee(
    p_base_fee NUMERIC,
    p_issued_at DATE,
    p_payment_date DATE
)
RETURNS NUMERIC
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
    v_overdue_days INTEGER;
    v_overdue_weeks INTEGER;

BEGIN
    IF p_base_fee IS NULL OR p_issued_at IS NULL OR p_payment_date IS NULL THEN
        RETURN NULL;
    END IF;

    v_overdue_days := (p_payment_date - p_issued_at) - 7;

    IF v_overdue_days <= 0 THEN
        RETURN p_base_fee;
    END IF;

    v_overdue_weeks := FLOOR(v_overdue_days / 7.0);

    RETURN ROUND(p_base_fee * POWER(1.05, v_overdue_weeks), 2);
END;
$$;

COMMENT ON FUNCTION fn_calculate_penalty_fee(NUMERIC, DATE, DATE) IS
    'Late fee with 7-day grace period, then 5% compound weekly interest.';

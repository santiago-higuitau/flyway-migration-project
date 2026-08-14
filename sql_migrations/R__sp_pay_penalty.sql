-- Marks a penalty as paid: computes the final fee (base + late interest)
-- and writes total_fee, paid and paid_at in one step.

CREATE OR REPLACE PROCEDURE sp_pay_penalty(
    p_penalty_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_base_fee NUMERIC;
    v_issued_at DATE;
    v_already_paid BOOLEAN;
    v_total_fee NUMERIC;

BEGIN
    SELECT base_fee, issued_at, paid
    INTO v_base_fee, v_issued_at, v_already_paid
    FROM penalties
    WHERE id = p_penalty_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Penalty % does not exist', p_penalty_id;
    END IF;

    IF v_already_paid THEN
        RAISE EXCEPTION 'Penalty % is already paid', p_penalty_id;
    END IF;

    v_total_fee := fn_calculate_penalty_fee(v_base_fee, v_issued_at, CURRENT_DATE);

    UPDATE penalties
    SET total_fee = v_total_fee,
        paid = TRUE,
        paid_at = CURRENT_DATE
    WHERE id = p_penalty_id;

    RAISE NOTICE 'Penalty % paid: base % -> total %', p_penalty_id, v_base_fee, v_total_fee;
END;
$$;

COMMENT ON PROCEDURE sp_pay_penalty(INTEGER) IS
    'Settles a penalty: computes total_fee via fn_calculate_penalty_fee and marks it paid.';

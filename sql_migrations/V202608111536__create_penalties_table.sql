CREATE TABLE penalties (
    id             INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    loan_id        INTEGER NOT NULL REFERENCES loans(id),
    reason         VARCHAR(150) NOT NULL,
    issued_at      DATE NOT NULL DEFAULT CURRENT_DATE,
    base_fee       NUMERIC(8,2) NOT NULL,
    total_fee      NUMERIC(8,2),
    paid           BOOLEAN NOT NULL DEFAULT FALSE,
    paid_at        DATE,
    CHECK (paid = FALSE OR (paid_at IS NOT NULL AND total_fee IS NOT NULL))
);

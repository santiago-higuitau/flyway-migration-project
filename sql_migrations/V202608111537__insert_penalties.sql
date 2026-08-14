INSERT INTO penalties (loan_id, reason, base_fee)
SELECT id, 'late return' AS reason, 5.00 AS base_fee
FROM loans
WHERE returned_at > due_date;

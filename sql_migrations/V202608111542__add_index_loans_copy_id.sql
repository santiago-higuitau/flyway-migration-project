-- Speeds up "who currently has this copy" lookups.
CREATE INDEX idx_loans_copy_id ON loans (copy_id);

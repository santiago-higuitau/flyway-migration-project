-- Speeds up "what does this user currently have on loan" lookups.
CREATE INDEX idx_loans_user_id ON loans (user_id);

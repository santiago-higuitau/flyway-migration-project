ALTER TABLE users
    ALTER COLUMN phone TYPE VARCHAR(18);

COMMENT ON COLUMN users.phone IS
    'Contact phone number. Widened from VARCHAR(10) to VARCHAR(18) to fit '
    'numbers with country code (e.g. +57 3001234567).';

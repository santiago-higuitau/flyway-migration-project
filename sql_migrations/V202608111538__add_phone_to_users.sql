-- Intentional design flaw: 10 chars fits a local number, not one with
-- country code (e.g. '+57 3001234567'). Fixed later via roll forward.
ALTER TABLE users
    ADD COLUMN phone VARCHAR(10);

COMMENT ON COLUMN users.phone IS
    'Contact phone number. NOTE: too short for numbers with country code.';

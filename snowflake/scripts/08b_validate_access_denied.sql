-- These two queries must fail due to permission issues.
-- Evidence that the differentiated access to 08_*.sql is real.

USE ROLE ROLE_DATA_ANALYST;
SELECT * FROM LIBRARY_DW.RAW.PENALTIES;  -- expected: no privileges

USE ROLE ROLE_BUSINESS_MANAGER;
SELECT * FROM LIBRARY_DW.RAW.LOANS;      -- expected: no privileges

USE ROLE ACCOUNTADMIN;
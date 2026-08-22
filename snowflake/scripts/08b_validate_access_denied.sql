-- These two queries must fail due to permission issues.
-- Evidence that the differentiated access to 08_*.sql is real.
USE DATABASE LIBRARY_DW;
USE SCHEMA RAW;

USE ROLE ROLE_DATA_ANALYST;
USE SECONDARY ROLES NONE;
SELECT * FROM PENALTIES;  -- expected: no privileges

USE ROLE ROLE_BUSINESS_MANAGER;
USE SECONDARY ROLES NONE;
SELECT * FROM LOANS;      -- expected: no privileges

USE ROLE ACCOUNTADMIN;
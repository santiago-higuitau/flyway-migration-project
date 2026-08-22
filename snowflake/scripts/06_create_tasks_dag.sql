USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_LIBRARY;
USE DATABASE LIBRARY_DW;
USE SCHEMA BOOK_REVIEWS;

GRANT EXECUTE TASK ON ACCOUNT TO ROLE LIBRARY_LOADER;

CREATE OR REPLACE TASK TASK_INGEST_S3
    WAREHOUSE = WH_LIBRARY
    SCHEDULE = 'USING CRON 0 * * * * America/Bogota'
    COMMENT = 'Root de la DAG: reingesta el bucket de book reviews'
AS
    COPY INTO RAW_REVIEWS (raw_data, _stg_file_name, _stg_loaded_at)
    FROM (
        SELECT $1, METADATA$FILENAME, CURRENT_TIMESTAMP()
        FROM @STG_BOOK_REVIEWS_S3
    )
    FILE_FORMAT = (FORMAT_NAME = FF_BOOK_REVIEWS_JSON)
    ON_ERROR = ABORT_STATEMENT;

CREATE OR REPLACE TASK TASK_FLATTEN_REVIEWS
    WAREHOUSE = WH_LIBRARY
    AFTER TASK_INGEST_S3
AS
    INSERT OVERWRITE INTO STG_BOOK_REVIEWS_FLATTENED (
        book_id, isbn, title, export_batch_id, generated_at,
        review_id, reviewer_name, rating, comment, submitted_at, verified_loan, tag
    )
    SELECT
        raw_data:book_id::NUMBER,
        raw_data:isbn::STRING,
        raw_data:title::STRING,
        raw_data:export_batch_id::STRING,
        raw_data:generated_at::TIMESTAMP_NTZ,
        r.value:review_id::STRING,
        r.value:reviewer_name::STRING,
        r.value:rating::NUMBER,
        r.value:comment::STRING,
        r.value:submitted_at::DATE,
        r.value:verified_loan::BOOLEAN,
        t.value::STRING
    FROM RAW_REVIEWS,
         LATERAL FLATTEN(input => raw_data:reviews) r,
         LATERAL FLATTEN(input => r.value:tags, outer => TRUE) t;

-- Ambas deben aparecer como 'suspended'
SHOW TASKS;

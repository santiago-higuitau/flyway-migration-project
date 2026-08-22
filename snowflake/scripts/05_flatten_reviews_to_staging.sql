USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_LIBRARY;
USE DATABASE LIBRARY_DW;
USE SCHEMA BOOK_REVIEWS;

SELECT
    raw_data:book_id::NUMBER              AS book_id,
    raw_data:isbn::STRING                 AS isbn,
    raw_data:title::STRING                AS title,
    raw_data:export_batch_id::STRING      AS export_batch_id,
    raw_data:generated_at::TIMESTAMP_NTZ  AS generated_at,
    raw_data:reviews                      AS reviews_array
FROM RAW_REVIEWS;

SELECT
    raw_data:book_id::NUMBER       AS book_id,
    r.value:review_id::STRING      AS review_id,
    r.value:reviewer_name::STRING  AS reviewer_name,
    r.value:rating::NUMBER         AS rating,
    r.value:tags                   AS tags_array
FROM RAW_REVIEWS,
     LATERAL FLATTEN(input => raw_data:reviews) r;

CREATE TABLE IF NOT EXISTS STG_BOOK_REVIEWS_FLATTENED (
    book_id          NUMBER,
    isbn             STRING,
    title            STRING,
    export_batch_id  STRING,
    generated_at     TIMESTAMP_NTZ,
    review_id        STRING,
    reviewer_name    STRING,
    rating           NUMBER,
    comment          STRING,
    submitted_at     DATE,
    verified_loan    BOOLEAN,
    tag              STRING,
    _flattened_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

TRUNCATE TABLE STG_BOOK_REVIEWS_FLATTENED;

INSERT INTO STG_BOOK_REVIEWS_FLATTENED (
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

-- Validate
SELECT * FROM STG_BOOK_REVIEWS_FLATTENED;

SELECT 
    (SELECT COUNT(1) FROM RAW_REVIEWS) AS libros,
    (SELECT COUNT(DISTINCT review_id) FROM STG_BOOK_REVIEWS_FLATTENED) AS resenas;

-- Reseñas sin tags deben salir con tag = NULL, no fallar
SELECT review_id, tag FROM STG_BOOK_REVIEWS_FLATTENED WHERE tag IS NULL LIMIT 5;
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE WH_LIBRARY;
USE DATABASE LIBRARY_DW;
USE SCHEMA BOOK_REVIEWS;

-- Activar el DAG completo (root + hijas) de un solo golpe, en el orden correcto.
SELECT SYSTEM$TASK_DEPENDENTS_ENABLE('TASK_INGEST_S3');

-- Ambas deben aparecer como 'started'
SHOW TASKS;

-- Disparar manualmente, sin esperar al CRON.
EXECUTE TASK TASK_INGEST_S3;

-- Ver el resultado (esperar unos segundos; deben aparecer ambas tasks).
SELECT name, state, scheduled_time, completed_time, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY())
WHERE name IN ('TASK_INGEST_S3', 'TASK_FLATTEN_REVIEWS')
ORDER BY scheduled_time DESC
LIMIT 10;


-- Apagar siempre raíz primero. Al reves fallaría con error.
ALTER TASK TASK_INGEST_S3     SUSPEND;
ALTER TASK TASK_FLATTEN_REVIEWS SUSPEND;

SHOW TASKS;  -- ambas: suspended


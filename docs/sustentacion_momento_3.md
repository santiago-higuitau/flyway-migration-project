# Sustentación: Momento 3 (dbt sobre LIBRARY_DW)

Vamos a recorrer el proyecto criterio por criterio de la rúbrica, mostrando en cada
uno los archivos que sustentan por qué lo cumplimos. Al cierre, hacemos la demo en
vivo: un cambio real, commit, CI, y el resultado reflejado en Snowflake.

---

## C1: Arquitectura Medallón

**Rúbrica:** "Capas `staging/` (Silver) y `core/` (Gold) con
responsabilidades limpias, sin fugas de lógica entre capas. Uso consistente de
`ref()` y `source()`. Convención de nombres coherente."

**Argumento:** las dos capas están separadas por materialización y por
responsabilidad. Staging solo hace cast y rename sobre una fuente cruda, nunca sobre
otro modelo. Core solo usa `ref()` sobre Silver, nunca lee una fuente cruda
directamente. La convención de nombres (`stg_`, `fct_`, `dim_`) es consistente en
los 17 modelos del proyecto.

1. [`dbt_project.yml`](../dbt_project.yml) (raíz del repo): materializaciones de
   staging (vista) y core (tabla).
2. [`dbt/models/staging/_staging__sources.yml`](../dbt/models/staging/_staging__sources.yml):
   las dos sources declaradas, la relacional (`raw_library`, 11 tablas) y la
   semi-estructurada (`raw_book_reviews`, JSON crudo).
3. [`dbt/models/staging/stg_authors.sql`](../dbt/models/staging/stg_authors.sql):
   modelo Silver típico, cast y rename, nada más.
4. [`dbt/models/staging/stg_book_reviews.sql`](../dbt/models/staging/stg_book_reviews.sql):
   el caso especial, dos `LATERAL FLATTEN` encadenados para aplanar el JSON de
   reseñas, migrado desde un script SQL suelto del Momento 2.
5. [`dbt/models/core/fct_book_engagement.sql`](../dbt/models/core/fct_book_engagement.sql):
   modelo Gold usando `ref()` exclusivamente, nunca una fuente cruda.
6. [`docs/evidencias/images/04_lineage_graph.png`](evidencias/images/04_lineage_graph.png):
   cierre visual, el grafo completo del proyecto sin nodos huérfanos, mostrando el
   flujo Bronze, Silver, Gold.

---

## C2: Modelos Gold y lógica de negocio

**Rúbrica:** "≥2 modelos Gold que responden preguntas de
negocio explícitas y bien elegidas. Al menos uno cruza dos orígenes de datos
distintos del proyecto propio. El grano de cada tabla es inequívoco y está
documentado."

**Argumento:** hay 5 modelos Gold, más del doble del mínimo pedido, cada uno con
su pregunta de negocio en un comentario al inicio del `.sql` y su grano explícito
en la `description:`. Tres de los cinco cruzan el dominio relacional (préstamos)
con el semi-estructurado (reseñas de lectores).

7. [`dbt/models/core/_core__models.yml`](../dbt/models/core/_core__models.yml):
   los 5 modelos Gold con su grano documentado (`fct_user_delinquency`,
   `dim_edition_inventory`, `fct_book_engagement`, `fct_author_popularity`,
   `dim_category_performance`).
8. [`dbt/models/core/fct_book_engagement.sql`](../dbt/models/core/fct_book_engagement.sql)
   (ya abierto en el paso 5, solo se cambia de qué se habla): cruce de orígenes
   relacional y semi-estructurado para responder qué libros se prestan más y
   tienen mejor reseña.
9. [`dbt/models/core/fct_author_popularity.sql`](../dbt/models/core/fct_author_popularity.sql):
   decisión de negocio documentada en comentario, un libro coescrito aporta su
   volumen completo a cada autor, sin dividirlo entre coautores.

---

## C3: Pruebas de calidad de datos

**Rúbrica:** "Tests genéricos cubren llaves y relaciones de
todos los modelos. ≥2 tests de `dbt-expectations`, cada uno con una justificación
de negocio clara."

**Argumento:** los 17 modelos (12 staging más 5 core) tienen `unique`/`not_null` en
sus llaves y `relationships` en sus llaves foráneas. Hay más de 2 tests de
`dbt_expectations` (rango de rating, montos no negativos, formato de email, costo
de reposición), cada uno con un comentario explicando por qué esa regla importa
para el negocio, no solo por integridad estructural.

10. [`dbt/models/staging/_staging__models.yml`](../dbt/models/staging/_staging__models.yml):
    tests genéricos en todas las llaves/relaciones, y los `dbt_expectations` con
    su comentario de justificación (por ejemplo, formato de email, costo de
    reposición mayor o igual a 0).
11. [`dbt/models/core/_core__models.yml`](../dbt/models/core/_core__models.yml):
    `dbt_expectations` sobre los modelos Gold (rating promedio entre 1 y 5,
    montos de mora mayores o iguales a 0).

---

## C4: Automatización con GitHub Actions

**Rúbrica:** "Workflow versionado que ejecuta `dbt build`,
con Secrets configurados y ≥1 ejecución real exitosa demostrable. Falla
visiblemente si un test no pasa."

**Argumento:** el workflow tiene dos jobs encadenados con `needs:`. `build_dev`
corre primero, y `build_pdn` solo se ejecuta si `build_dev` termina sin error. Se
demostró el ciclo completo tres veces: éxito, fallo controlado con el gate
frenando producción, y corrección posterior.

12. [`.github/workflows/dbt-build.yml`](../.github/workflows/dbt-build.yml): los
    dos jobs encadenados con `needs: build_dev`, cada uno apuntando a un target
    distinto (`dev`/`pdn`).
13. [`profiles.yml.example`](../profiles.yml.example): los dos targets
    declarados (`dev` y `pdn`), con esquemas físicamente distintos en Snowflake
    (`ANALYTICS_*` y `ANALYTICS_PDN_*`).
14. [`docs/evidencias/images/05_execution_workflow_ok.png`](evidencias/images/05_execution_workflow_ok.png):
    ejecución real exitosa, `PASS=97, ERROR=0` en ambos jobs.
15. [`docs/evidencias/images/07_workflow-evidence_of_a_failed_test.png`](evidencias/images/07_workflow-evidence_of_a_failed_test.png):
    `build_dev` falla por un test roto a propósito, `build_pdn` queda sin
    ejecutarse. El gate funciona.
16. [`docs/evidencias/images/08_workflow-evidence_correction.png`](evidencias/images/08_workflow-evidence_correction.png):
    tras revertir el cambio, ambos jobs vuelven a correr en verde.

---

## C5: Documentación y sustentación

**Rúbrica:** "Todos los modelos Gold y sus columnas
documentados en lenguaje de negocio. Lineage graph completo. Demo del cambio en
vivo exitosa y dentro del tiempo, con discurso que conecta decisiones técnicas y
necesidades de negocio."

**Argumento:** cada modelo y cada columna relevante, tanto en staging como en
core, tiene una `description:` en lenguaje de negocio, sin jerga SQL. El lineage
graph ya se mostró en el paso 6. Lo que sigue es la demo en vivo.

17. [`dbt/models/staging/_staging__models.yml`](../dbt/models/staging/_staging__models.yml)
    (ya visto en el paso 10): descripciones de columna en lenguaje de negocio.
18. [`dbt/models/core/_core__models.yml`](../dbt/models/core/_core__models.yml)
    (ya visto en el paso 7): descripciones de columna en lenguaje de negocio.
19. [`docs/evidencias/images/04_lineage_graph.png`](evidencias/images/04_lineage_graph.png)
    (ya visto en el paso 6): referencia rápida de cierre antes de pasar a la demo.

---

## Transición a la demo en vivo

Con esto queda cubierto el recorrido por el repo. Ahora vamos a la parte en vivo:
editamos un modelo Gold, hacemos commit y push, y seguimos el workflow corriendo en
la pestaña Actions hasta ver el resultado reflejado en Snowflake.

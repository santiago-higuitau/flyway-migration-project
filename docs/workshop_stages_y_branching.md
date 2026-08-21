# Workshop: Momento 2 (Snowflake), PR gate + branching en GitHub

Este documento es la bitácora del workshop. La idea: cada módulo tiene una
explicación breve del concepto, una tarea concreta para ejecutar, y un criterio
de aceptación. Marca `[x]` cuando termines una tarea y anota evidencia (comando
corrido, captura, link al run de Actions, decisión tomada) en la línea de
`Notas:` de cada módulo. Cuando termines un módulo, lo revisamos juntos antes
de pasar al siguiente.

No hay código de solución escrito aquí a propósito — se construye en la sesión,
módulo por módulo.

## Prioridad

**Track M2 va primero.** Es lo que evalúa la rúbrica de
[Momento 2 — Cloud Data Warehouse e Ingesta](../../data_ops_course_101/evaluaciones/momento_2_cloud_dw.md)
(30 % de la nota final), con sustentación **sábado 22/08/2026, 08:00, aula
33-302** y código entregado **antes de las 07:00 del mismo día**. Todo sobre el
dominio biblioteca de este repo (`flyway-migration-project`), no sobre
Parch & Posey.

Los Tracks B y C (branching y PR gates en GitHub) **no forman parte de esta
rúbrica** — son aprendizaje de CI/CD sobre este mismo repo, independiente del
Momento 2. Se trabajan en paralelo o después, según tiempo.

**Antes de escribir una sola línea de SQL, verifica dos cosas de tu cuenta de
Snowflake** (bloquean todo si fallan el día de la sustentación):
- [ ] Vigencia del trial (30 días desde su creación).
- [ ] Edición de la cuenta, con `SHOW ACCOUNTS;` conectado como `ORGADMIN`. Si
      quieres demostrar Masking en vivo (parte de C5) necesitas `ENTERPRISE` o
      superior — el upgrade (`ALTER ACCOUNT ... SET EDITION`, desde la
      Organization Account) no es instantáneo, no se puede improvisar mañana.

---

## Track M2 — Momento 2: Cloud DW e Ingesta (evaluado, 100 pts / 30 % de la nota)

Estructura de entregables esperada en el repo (según el enunciado, sección 4):

```
snowflake/setup/    E1 — arquitectura Snowflake como código (Módulo M2-1)
ingesta/             E2, E3 — extracción relacional + drift (Módulo M2-2)
snowflake/json/      E4 — File Format, External Stage, FLATTEN (Módulo M2-3)
                      E5 — Tasks + evidencia (Módulo M2-4, en snowflake/ o ingesta/)
                      E6 — roles y Masking (Módulo M2-5, en snowflake/)
.env.example         E7 — cero credenciales reales (raíz del repo)
docs/                E8 — documento de decisiones (Módulo M2-6)
```

Hoy el repo tiene `code/`, `sql_migrations/`, `docs/`. Decide en el Módulo M2-1
si reorganizas para calzar con esa estructura o si documentas el mapeo
equivalente — lo que importa para la rúbrica es que esté versionado y
razonado, no el nombre exacto de la carpeta.

### Módulo M2-1 — Arquitectura Snowflake como código (C1, 10 pts)

**Concepto:** todo objeto de Snowflake (warehouse, bases, esquemas, rol de
servicio) se crea desde un script `.sql` versionado en el repo, nunca a mano
desde la UI. Además, los datos relacionales y los semi-estructurados deben
vivir en esquemas separados dentro de la misma base — mezclar todo en `RAW` no
alcanza el nivel "Excelente" de la rúbrica.

**Tarea:**
- [ ] Escribir (o adaptar el de la sesión 4) un script de setup con: warehouse
      `XSMALL` + `AUTO_SUSPEND`, base de datos del proyecto biblioteca, al
      menos dos esquemas (uno para datos relacionales, otro para
      semi-estructurados), y un rol de servicio sin `ACCOUNTADMIN`.
- [ ] Incluir en ese mismo script (o en uno hermano) el `FILE FORMAT` para
      parquet y el `INTERNAL STAGE` que usará el Módulo M2-2 — así queda todo
      la arquitectura como código en un solo lugar.
- [ ] Guardar ese script en `snowflake/setup/` (o la carpeta que decidiste).
- [ ] Ejecutarlo contra tu cuenta real y confirmar con `SHOW WAREHOUSES`,
      `SHOW SCHEMAS IN DATABASE ...`, `SHOW GRANTS TO ROLE ...`,
      `SHOW STAGES`, `SHOW FILE FORMATS`.

**Criterio de aceptación:** puedes borrar todos los objetos y recrearlos
completos corriendo un solo script, sin tocar la UI.

Notas:

---

### Módulo M2-2 — Ingesta relacional vía Internal Stage, sin `write_pandas` (C2, 20 pts)

**Concepto:** mismo objetivo del patrón de la sesión 4
(`elt_postgres_to_snowflake.py`) — extraer de Neon y cargar en Snowflake sin
transformar — pero con un mecanismo de carga distinto.

`write_pandas` no evita el staging: por debajo, también convierte el
DataFrame a parquet, lo sube con `PUT` a un stage temporal que Snowflake crea
y borra solo, y corre `COPY INTO` — los mismos tres pasos que harías a mano.
La diferencia real, y la razón para cambiarlo, es **quién decide los tipos de
columna**. Con `auto_create_table=True`, Snowflake infiere el esquema a
partir de los dtypes de pandas en memoria, **chunk por chunk** — la propia
documentación de Snowflake advierte que esto puede producir tipos
inconsistentes si hay `None` o si los chunks varían entre sí. Ese trabajo
queda del lado de pandas, propenso a fallar, y fuera de nuestra vista.

El cambio: `PUT` explícito a un **Internal Stage** propio + `INFER_SCHEMA`
sobre el archivo parquet ya aterrizado + `CREATE TABLE ... USING TEMPLATE`
(o el DDL a mano si se prefiere) + `COPY INTO`. La inferencia se hace desde
los metadatos del parquet, no desde objetos Python en memoria, y el
`CREATE TABLE` resultante queda como artefacto SQL explícito — auditable y
versionable, coherente con "arquitectura como código" (C1). El control de
tipos queda del lado nuestro, no del lado de pandas.

**Tarea:**
- [ ] Adaptar la lista de tablas del script a las del dominio biblioteca
      (`sql_migrations/`), conexión a `NEON_MAIN_DATABASE_URL` o `dev`.
- [ ] Confirmar que el proyecto tiene `pyproject.toml` **y** `uv.lock` (no
      `requirements.txt`, no `pip install` suelto).
- [ ] Confirmar que el `FILE FORMAT` y el `INTERNAL STAGE` (ej.
      `STG_LIBRARY_RAW`) ya existen (Módulo M2-1).
- [ ] Reemplazar `write_pandas` en el script Python: exportar cada tabla a un
      parquet local (directorio temporal), subirlo con `PUT` al stage vía el
      conector de Snowflake (no manualmente).
- [ ] Correr `INFER_SCHEMA` sobre el archivo ya en el stage y, si la tabla
      destino no existe, crearla desde ese resultado
      (`CREATE TABLE ... USING TEMPLATE`).
- [ ] Cargar con `COPY INTO tabla FROM @stage/... FILE_FORMAT = ...` en vez
      de `write_pandas`.
- [ ] Mantener (o adaptar) la detección de schema drift ya existente: comparar
      columnas del origen contra `information_schema.columns` del destino
      **antes** de intentar el `COPY INTO`, con mensaje accionable si hay
      drift.
- [ ] Provocar un caso real de drift: agrega una columna a una tabla en Neon
      (vía una migración nueva de Flyway) y corre la ingesta sin haber tocado
      Snowflake todavía. Debe fallar con el mensaje accionable, no con un
      error críptico de Snowflake.
- [ ] Aplicar el DDL que el script sugiere, y volver a correr — debe cargar
      sin error.
- [ ] Decidir idempotencia: `TRUNCATE` + `COPY INTO` completo en cada corrida,
      o control de qué archivos ya se cargaron. `COPY INTO` deduplica por
      nombre de archivo por defecto — decidir si eso basta.
- [ ] Agregar `REMOVE @stage/...` al final de la corrida para no dejar
      archivos residuales en el stage.
- [ ] Guardar evidencia (log de la corrida con el error de drift, y de la
      corrida exitosa después) en `docs/` o donde decidiste.

**Criterio de aceptación:** la carga relacional no usa `write_pandas`; el
`CREATE TABLE` de cada tabla existe como artefacto SQL versionado generado
desde `INFER_SCHEMA`; existe un caso de drift provocado y corregido, con
evidencia de ambos momentos (falla y éxito).

Notas:

---

### Módulo M2-3 — Ingesta semi-estructurada: External Stage + VARIANT + FLATTEN (C3, 20 pts)

**Concepto:** ingesta de una fuente **semi-estructurada** (no no-estructurada
— tiene forma, pero sin esquema de columnas fijo de antemano). El patrón:
**External Stage** (bucket S3) con un archivo **JSON que tenga al menos un
array anidado real**, cargado a una columna `VARIANT` sin definir esquema
(schema-on-read), y aplanado con `LATERAL FLATTEN`.

**Tarea:**
- [ ] Inventar una fuente JSON propia del dominio biblioteca, con un array
      anidado real. Ejemplos: reseñas de lectores por libro (array de reseñas
      dentro de cada libro), o un log de eventos de préstamo con metadata
      anidada (ej. lista de renovaciones por préstamo). Debe ser algo que
      *no* exista ya como tabla relacional en `sql_migrations/`.
- [ ] Generar 2-3 archivos JSON de ejemplo (pocos archivos, no un dataset de
      producción — lo que importa es el patrón).
- [ ] Crear el `FILE FORMAT` (con `STRIP_OUTER_ARRAY = TRUE` si cada archivo es
      un array JSON) y el `EXTERNAL STAGE` apuntando a tu bucket S3.
- [ ] Cargar a una tabla `RAW_*` con columna `VARIANT` vía `COPY INTO`.
- [ ] Escribir la consulta con notación de punto + `LATERAL FLATTEN` para
      desenrollar el array anidado en una fila por elemento.
- [ ] Verificar el manejo de claves ausentes (si algún registro no tiene un
      campo que otros sí tienen, la consulta no debe fallar — debe salir
      `NULL`).
- [ ] Materializar el resultado aplanado en una tabla de staging.
- [ ] Guardar los scripts en `snowflake/json/` (o la carpeta que decidiste).

**Criterio de aceptación:** existe un array anidado real en el JSON (no una
tabla plana disfrazada), y `LATERAL FLATTEN` produce una fila por elemento del
array, con claves ausentes en `NULL` en vez de error.

Notas:

---

### Módulo M2-4 — Orquestación con Snowflake Tasks (C4, 20 pts)

**Concepto:** un DAG de al menos dos tareas nativas de Snowflake (sin Airflow,
sin cron externo): una raíz con `SCHEDULE`, una hija con `AFTER`, encadenando
ingesta y transformación de al menos una de las dos fuentes (relacional o
JSON).

**Tarea:**
- [ ] Otorgar `EXECUTE TASK` (privilegio de cuenta, no de objeto) al rol que
      va a manejar las tasks.
- [ ] Crear la task raíz con `SCHEDULE` (ej. cada N minutos, para poder
      demostrarla rápido) que dispare algo reproducible (ej. un `COPY INTO`
      o un `MERGE`).
- [ ] Crear la task hija con `AFTER <raíz>` que dependa de la anterior.
      Cuidado con el orden de propiedades en el `CREATE TASK`: `COMMENT`
      antes de `AFTER`.
- [ ] Activar el DAG con `SYSTEM$TASK_DEPENDENTS_ENABLE('<raíz>')`.
- [ ] Disparar manualmente con `EXECUTE TASK`, y confirmar la ejecución
      consultando `TASK_HISTORY`.
- [ ] Apagar el DAG en el orden correcto: la raíz primero
      (`ALTER TASK <raíz> SUSPEND`), nunca la hija mientras la raíz siga
      `started` (falla con error 091421 si el orden es al revés).
- [ ] Guardar los scripts en `snowflake/` (o donde decidiste) y capturar el
      resultado de `TASK_HISTORY` como evidencia.

**Criterio de aceptación:** el DAG corrió con éxito al menos una vez
(visible en `TASK_HISTORY`), y puedes explicar por qué el apagado tiene un
orden obligatorio y la activación no.

Notas:

---

### Módulo M2-5 — RBAC y protección de datos sensibles (C5, 20 pts)

**Concepto:** al menos dos roles de negocio (distintos del rol de servicio de
ingesta) con `GRANT`s deliberadamente distintos. Si el dominio biblioteca
tiene un campo sensible (nombre de usuario, teléfono, dirección, dato de
pago), se protege con una Masking Policy — visible según el rol activo.

**Tarea:**
- [ ] Identificar en tu modelo biblioteca qué columna es sensible o PII
      (ej. teléfono o email de `usuarios`).
- [ ] Crear al menos 2 roles de negocio (ej. `ROLE_BIBLIOTECARIO`,
      `ROLE_ANALISTA`) con `GRANT`s distintos entre sí — no ambos con acceso
      total a todo.
- [ ] Confirmar, antes de aplicar la política, que ambos roles ven el dato
      sensible igual (sin máscara).
- [ ] Si tu cuenta es Enterprise: crear la `MASKING POLICY` y aplicarla a la
      columna. Repetir la consulta con cada rol activo — el mismo `SELECT`,
      resultado distinto según el rol.
- [ ] Si tu cuenta es Standard: intentar el `CREATE MASKING POLICY`, capturar
      el error (`Unsupported feature`), y documentar que el resto (roles y
      grants) funciona igual sin Enterprise. Eso cuenta como evidencia válida
      según la rúbrica.
- [ ] Guardar los scripts de roles/masking en `snowflake/` (o donde
      decidiste).

**Criterio de aceptación:** los roles existen con acceso realmente
diferenciado (no "todos ven lo mismo"), y hay evidencia clara de la Masking
Policy funcionando o del intento documentado si la edición no alcanza.

Notas:

---

### Módulo M2-6 — Documentación y ensayo de la sustentación (C6, 10 pts)

**Concepto:** la rúbrica pide decisiones argumentadas por escrito, no solo
descripción de lo que se hizo. Y la demo es en vivo, contra la cuenta real —
"funciona en mi máquina" no cumple.

**Tarea:**
- [ ] Escribir el documento de decisiones (1-2 páginas) en `docs/`: qué fuente
      semi-estructurada eligieron y por qué, y la estrategia de roles.
      Incluir la razón del cambio de `write_pandas` a Internal Stage
      (control de tipos), como parte de las decisiones de C2.
- [ ] Ensayar la demo de 10 minutos en el orden que pide el enunciado:
      (1) ingesta relacional + comportamiento ante drift, (2) disparar el DAG
      de Tasks + mostrar `TASK_HISTORY`, (3) diferencia de visibilidad entre
      roles sobre el dato protegido.
- [ ] Confirmar `.env.example` en la raíz del repo, sin ninguna credencial
      real.
- [ ] Preparar respuestas a las preguntas obvias: ¿por qué Internal Stage y no
      `write_pandas` para lo relacional? ¿por qué External Stage y no Internal
      para el JSON? ¿por qué ese campo es el sensible? ¿qué pasa si Neon
      cambia de esquema en producción sin avisar?

**Criterio de aceptación:** puedes explicar cada decisión sin leer el código
en pantalla, y la demo corre completa en los 10 minutos contra la cuenta real.

Notas:

---

## Track B — PR gate y branching en GitHub (no evaluado en Momento 2)

Estado actual conocido: ya existen `flyway-migrate-dev.yml` (push a `feature/**`
→ migra `dev`), `flyway-migrate-pdn.yml` (push a `main` → migra `main`, ya
corregido) y `flyway-pr-check.yml` (pull_request a `main` → info + validate,
sin migrate).

### Módulo B1 — Diagnóstico y separación del gate — ✅ completado

**Tarea:**
- [X] Quitar el trigger `pull_request` de `flyway-migrate-pdn.yml`.
- [X] Crear `flyway-pr-check.yml` con `info` + `validate`, sin `migrate`.
- [X] Decidir `NEON_MAIN_DATABASE_URL` para el gate, y justificar por qué.
- [X] Corregir el `paths` filter que apuntaba al archivo equivocado.
- [X] Renombrar el `name`/`id` del job para que no quede como copia sin
      terminar de `flyway-migrate-pdn.yml`.
- [X] Concurrency por PR (`group` con `github.event.pull_request.number`) y
      `cancel-in-progress: true`.

Nota: Flyway validate compara checksums contra flyway_schema_history de la
base a la que apunta — validar contra `main` es correcto porque el checksum
que importa es el de `main`, no el de `dev`. El gate no predice si la
migración nueva va a funcionar; garantiza que nadie alteró el pasado (las
migraciones ya aplicadas siguen siendo lo que Flyway cree que son). El status
check en GitHub se identifica por el `name` del job, no por su `id` — deben
ser únicos entre workflows para evitar ambigüedad.

**Pendiente de este módulo:** la prueba end-to-end real se hace junto con el
Módulo B3, no aislada.

---

### Módulo B2 — Branch protection rule en `main`

**Concepto:** el workflow por sí solo no impide un push directo a `main`. Eso
lo impone una regla de protección de rama en GitHub, que además puede exigir
que un status check específico pase antes de permitir el merge.

**Tarea:**
- [X] En **Settings → Branches → Branch protection rules**, crear/editar la
      regla sobre `main`.
- [X] Activar "Require a pull request before merging" (approvals desactivado
      por decisión propia, para no bloquearse mientras se trabaja en
      solitario — se puede reactivar más adelante con los 2 colaboradores).
- [X] Marcar el `name` exacto del job de `flyway-pr-check.yml`
      (`Info and validation to Neon (main)`) como *required status check* —
      apareció en el buscador después de la primera corrida real generada
      en el Módulo B3.
- [X] Activar "Require branches to be up to date before merging" — decisión
      propia, dado que ya hay 2 colaboradores y el repo versiona esquema de
      base de datos (evita mergear contra una versión vieja de `main`).
- [X] (Opcional) Activar "Do not allow bypassing the above settings" si se
      quiere que aplique incluso a administradores del repo.

**Criterio de aceptación:** intentar un `git push` directo a `main` desde local
debe ser rechazado por GitHub, o el PR no debe poder mergearse si
`flyway-pr-check` falló o no corrió.

Notas: regla creada sobre `main`, "Currently applies to 1 branch". Check
`Info and validation to Neon (main)` (GitHub Actions) agregado como required
tras la primera corrida real del Módulo B3. Approvals desactivado por ahora
aunque el repo tiene 2 colaboradores — se puede reactivar después. También se
agregó un step de "Run Summary" a `flyway-pr-check.yml` (con `id:
flyway_validation` en el step de validate, referenciado como
`steps.flyway_validation.outcome` en el summary) para mostrar PR, target,
resultado de drift y status del job en `$GITHUB_STEP_SUMMARY`.

---

### Módulo B3 — Prueba end-to-end del flujo de tres etapas

**Concepto:** verificar el ciclo completo: `feature/*` → dev automático → PR →
gate (sin migrate) → merge → `main` real.

**Tarea:**
- [X] Crear branch `feature/prueba-workshop`.
- [X] Agregar una migración SQL trivial (ej. un comentario o índice inofensivo)
      y hacer push.
- [X] Confirmar en la pestaña Actions que se disparó `flyway-migrate-dev.yml`
      y que migró contra `dev`.
- [X] Abrir PR de `feature/prueba-workshop` hacia `main`.
- [X] Confirmar que se disparó `flyway-pr-check.yml` (info + validate) y NO
      `flyway-migrate-pdn.yml`.
- [ ] Mergear el PR.
- [ ] Confirmar que el merge (push resultante a `main`) disparó
      `flyway-migrate-pdn.yml` y migró `main` de verdad.

**Criterio de aceptación:** los tres workflows corrieron en el momento correcto
del ciclo, cada uno exactamente una vez, con el resultado esperado en Neon.

Notas:

---

### Módulo B4 — Actualizar el README con el flujo nuevo

**Tarea:**
- [ ] Reescribir la sección "Cómo se despliega a main" del `README.md` del
      repo para documentar las tres etapas (dev automático, gate de PR,
      despliegue real), reemplazando la descripción del flujo viejo (que
      mencionaba un solo workflow `flyway-migrate.yml`).

Notas:

---

## Track C — Ramas efímeras de Neon por Pull Request (opcional, no evaluado en Momento 2)

### Módulo C1 — Setup de la API key y las Actions oficiales de Neon

**Concepto:** crear/borrar branches de Neon vía API requiere un `NEON_API_KEY`
(distinto del connection string). Neon publica Actions oficiales
(`neondatabase/create-branch-action`, `neondatabase/delete-branch-action`) para
esto.

**Tarea:**
- [ ] Generar un API key en Neon Console y guardarlo como secreto
      `NEON_API_KEY` en GitHub.
- [ ] Revisar la documentación de `neondatabase/create-branch-action` y
      `delete-branch-action` en GitHub Marketplace, anotar qué inputs mínimos
      necesita (project id, parent branch, nombre de branch).

Notas:

---

### Módulo C2 — Branch efímera por PR

**Concepto:** en vez de que todos los `feature/*` compartan la misma `dev`,
cada PR obtiene su propia branch de Neon (copy-on-write sobre `dev` o `main`),
se migra ahí, y se borra al cerrar el PR.

**Tarea:**
- [ ] Diseñar un workflow (o modificar el de PR check) que en
      `pull_request: [opened, reopened, synchronize]` cree una branch Neon con
      nombre derivado del PR (ej. `pr-123`) y migre contra ella.
- [ ] Agregar un job en `pull_request: [closed]` que borre esa branch.
- [ ] Probar con un PR real: verificar en Neon Console que la branch aparece
      al abrir el PR y desaparece al cerrarlo/mergearlo.

**Criterio de aceptación:** cada PR deja evidencia de una branch Neon efímera
creada y destruida automáticamente, sin intervención manual.

Notas:

---

## Bitácora de revisiones conjuntas

| Fecha | Módulo revisado | Resultado | Comentarios |
|---|---|---|---|
| | Módulo B1 | Aprobado | 4 bugs corregidos: pull_request quitado, paths filter, name/id del job, concurrency por PR |
| | | | |

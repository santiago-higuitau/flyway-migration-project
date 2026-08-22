# Momento 2 | Cloud Data Warehouse e Ingesta: documento de decisiones

Este archivo acompaña el entregable en `snowflake/scripts/`. La primera
sección es el recap para armar la presentación; el resto explica el **por
qué** de cada decisión (el **qué** está en el código, comentado donde hace
falta).

## Resumen ejecutivo

El Momento 1 dejó la base de datos del proyecto biblioteca en Neon, versionada
con Flyway y desplegada mediante un pipeline de tres etapas: `feature/*` migra
automáticamente contra `dev`, un Pull Request valida contra `main` sin aplicar
cambios, y el merge, una vez pase el workflow de validación, dispara el despliegue real. Esa es la base sobre la cual se construyó el momento 2.

El objetivo de este momento es mover esos datos a un Cloud Data Warehouse en
Snowflake de forma programática y gobernada, desde dos formas de origen
distintas: los datos relacionales que ya existen en Neon, y una fuente
semi-estructurada nueva que no tiene esquema fijo.

---

## Arquitectura

Un warehouse (`WH_LIBRARY`, XSMALL con auto-suspend), una
base de datos (`LIBRARY_DW`) con dos esquemas separados por dominio (`RAW`
para lo relacional, `BOOK_REVIEWS` para el JSON), y un rol de servicio
(`LIBRARY_LOADER`) sin privilegios de administrador. Todo creado por scripts en Snowflake.

## Ingesta relacional

Un pipeline ELT (extrae sin transformar) que carga las
11 tablas del dominio biblioteca desde Neon hacia `LIBRARY_DW.RAW`, con carga
masiva vía `write_pandas`. Antes de cargar, compara las columnas del origen
contra las del destino: si Neon tiene una columna que Snowflake no conoce
todavía, el pipeline se detiene con el DDL que resolvería la diferencia, en
vez de fallar a ciegas. Se demostró con un caso real, donde se agregó una columna
nueva en Neon, la carga falló como se esperaba, luego se aplicó el ajuste sugerido
en Snowflake, y la siguiente carga de la tabla terminó sin error.

## Orquestación

Un flujo de dos tareas nativas de Snowflake: una tarea raíz
programada por horario que reingesta el bucket (un FULL LOAD DATA), y una tarea hija, encadenada
a la anterior, que recalcula el aplanado. Se activó el flujo completo, se
disparó manualmente, se confirmó su ejecución exitosa en el historial de
tareas de Snowflake, y se apagó respetando el orden correcto visto en clase: la raíz
primero, porque Snowflake no permite suspender una tarea hija mientras la
raíz sigue activa.

## Fuente semi-estructurada elegida

**Reseñas de lectores por libro**, simuladas como 5 lotes de exportación
mensual desde una plataforma externa de reseñas (`code/generate_book_reviews_json.py`,
salida en `data/json/resenas_lote_1.json` a `_5.json`).

Se eligió sobre otras opciones (log de eventos de préstamo, export de
proveedor de compras) por una razón de negocio y por otra técnica. La primera se debe a que es natural que los libros tengan reseñas, y la segunda porque produce un array anidado genuino y de dos
niveles: cada libro trae un array `reviews[]`, y cada reseña trae a su vez un
array `tags[]` que **no siempre existe** (~26% de los casos). Eso permite
demostrar tanto `LATERAL FLATTEN` sobre un array simple como sobre un array
anidado dentro de otro, y el manejo de claves ausentes sin que la consulta
falle (`tag` sale `NULL`, no se pierde la fila; confirmado con evidencia real
sobre 5 reseñas del lote 1).

No se modela como tabla relacional porque, a diferencia del catálogo o los
préstamos, las reseñas no tienen un esquema estable: la plataforma externa
puede agregar o quitar campos sin avisar, y el número de reseñas por libro es
variable. Es exactamente el caso de uso que `VARIANT` + schema-on-read resuelve
mejor que una tabla con columnas fijas.

## Internal Stage para lo relacional, en vez de `write_pandas`

La ingesta de Neon (`code/elt_neon_to_library_dw.py`) usa `write_pandas` con
`auto_create_table=True`. Por debajo, esta función ya sube a un stage interno
temporal y ejecuta `COPY INTO`; el mismo mecanismo que se haría a mano. La
diferencia real está en la inferencia de tipos: `write_pandas` infiere el
esquema desde los dtypes de pandas, chunk por chunk, lo cual la documentación
oficial de Snowflake señala como propenso a inconsistencias con valores nulos.
Se evaluó migrar a un patrón de `PUT` explícito + `INFER_SCHEMA` sobre el
parquet ya aterrizado (control de tipos más auditable), pero se priorizó
cerrar los cinco criterios de la rúbrica dado el tiempo disponible. Queda como
mejora pendiente adicional.

## External Stage: bucket S3 propio, con una limitación conocida

Se intentó usar el storage S3-compatible de Supabase como origen del External
Stage. Snowflake lo rechazó (`Endpoint ... not allowed`), pues los endpoints
S3-compatible fuera de Cloudflare R2 requieren activación manual por soporte
de Snowflake (Toca enviar un correo a soporte), y Supabase no está en la lista de proveedores certificados. De manera que se
migró a un bucket S3 (`library-project-dataops-s3-bucket-dev`) en AWS, creado
para este ejercicio.

Ese bucket tiene hoy una bucket policy de lectura pública anónima, replicando
el patrón que se usó en clase. Es una decisión de demo, pues la
alternativa correcta para producción debe ser `STORAGE INTEGRATION` con un rol IAM
(autenticación sin exponer credenciales ni exponer el bucket). El dataset es sintético y no contiene información real, por lo que el riesgo de exposición es bajo para este ejercicio puntual.

## Estrategia de roles

Tres roles de negocio, con acceso realmente diferenciado (no solo enmascarado):

- **`ROLE_DATA_ENGINEER`** —> acceso completo a `RAW`, necesario para depurar
  drift y fallos de carga.
- **`ROLE_DATA_ANALYST`** —> acceso a catálogo, usuarios y préstamos. Sin
  acceso a `PENALTIES` (dato financiero) ni `LIBRARIANS` (dato de personal).
- **`ROLE_BUSINESS_MANAGER`** —> acceso únicamente a `USERS`, para reporting.

Se agregó un cuarto rol de prueba, `ROLE_PASANTE`, de manera deliberada no
mencionado en la Masking Policy, para demostrar que el `ELSE` protege también
a roles futuros sin que alguien tenga que acordarse de actualizarlo.

La Masking Policy protege `USERS.PHONE` (parcial para analyst, oculto para el
resto) y `USERS.EMAIL` (oculto para todos salvo engineer); datos del
dominio relacional.

**Nota técnica de la demo:** el usuario usado en la sustentación tiene los
cinco roles otorgados a la vez (para poder alternar entre puntos de vista sin
crear cinco usuarios). Snowflake, por defecto, combina los privilegios de
todos los roles otorgados a un usuario (`secondary roles`), no solo el rol
activo; por eso los scripts de validación (`08b`, `09`) incluyen
`USE SECONDARY ROLES NONE` antes de cada prueba. En un despliegue real, cada
persona tendría su propio usuario con un solo rol otorgado, y ese comando no
haría falta, ya que el aislamiento vendría dado por la separación de usuarios, no por
un ajuste de sesión.

## Caso de drift demostrado

Se agregó la columna `website` a `authors` en Neon (branch `dev`) sin tocar
Snowflake primero. Al correr la ingesta, el script detectó la columna nueva y
falló con el DDL sugerido, sin escribir nada. Se aplicó el `ALTER TABLE` en
Snowflake y se reintentó, cargando sin error.

# Momento 2 | Cloud Data Warehouse e Ingesta: documento de decisiones

Este archivo acompaña el entregable en `snowflake/scripts/`. Aquí 
se explica el **por qué** de las decisiones tomadas; el **qué** está en el código, comentado donde hace
falta.

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
Snowflake y se reintentó: cargó sin error.

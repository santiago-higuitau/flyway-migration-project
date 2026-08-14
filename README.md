# Sistema de biblioteca | CI/CD de base de datos con Flyway

Este repo es el entregable del Momento 1 (CI/CD en Base de Datos). La idea de fondo:
el esquema de la base de datos vive versionado en git, igual que el código, y los
cambios llegan a producción (branch `main` de Neon) solo a través de un pipeline
automatizado de ci-cd.

El dominio elegido fue biblioteca. Para entender el modelo completo (por
qué separamos libros de ediciones y de copias, por qué usuarios y bibliotecarios
son tablas distintas, etc.), está explicado en
[`docs/dominio_de_negocio.md`](docs/dominio_de_negocio.md), con el diagrama
entidad-relación incluido.

## Qué se necesita antes de empezar

- Una cuenta en [Neon](https://neon.tech) con un proyecto que tenga dos branches:
  `dev` y `main`.
- [Flyway CLI](https://documentation.red-gate.com/flyway) instalado
  (`brew install flyway` en macOS).
- [uv](https://docs.astral.sh/uv/) para correr el script de generación de datos
  (opcional, solo si se quiere regenerar los datos de sintéticos; para cambios también se puede editar el script .py).
- `psql`, si se quiere probar manualmente los procedimientos o forzar el error que
  se documenta más abajo.

## Cómo está organizado el repo

```
sql_migrations/      Las migraciones de Flyway (esto es lo importante)
code/                Script que genera los datos de prueba (no toca ninguna base)
docs/                Descripción del dominio, diagrama ER y evidencias de los runs
.github/workflows/   El pipeline que aplica migraciones a main
flyway.conf.example  Plantilla de configuración; cópiala a flyway.conf localmente
```

## Levantar el ambiente local (branch dev)

1. Copia la plantilla de configuración de Flyway:

   ```bash
   cp flyway.conf.example flyway.conf
   ```

2. Abre `flyway.conf` y completa `flyway.url`, `flyway.user` y `flyway.password`
   con los datos de tu branch **dev** de Neon. Neon te da el connection string en
   formato `postgresql://usuario:clave@host/db`, pero Flyway usa JDBC, así que
   queda así:

   ```
   flyway.url=jdbc:postgresql://tu-host.neon.tech/neondb?sslmode=require
   flyway.user=tu_usuario
   flyway.password=tu_clave
   ```

   Este archivo nunca se sube al repo (está en `.gitignore`), así que no hay
   riesgo de filtrar credenciales.

3. Revisa qué va a pasar antes de aplicar nada:

   ```bash
   flyway info
   ```

   Deberías ver las 9 migraciones listadas, todas en estado `Pending`.

4. Aplica todo:

   ```bash
   flyway migrate
   ```

   Esto crea las 11 tablas, carga los datos de prueba, y deja el esquema en su
   versión final. Se puede confirmar entrando al Neon Console y mirando las
   tablas de la branch `dev`.

## Cómo se regeneraron los datos de prueba

Los datos de la migración `V202608111535__seed_data.sql` no se escribieron a
mano. Se generaron con un script de Python que usa
[Faker](https://faker.readthedocs.io/) y los volcó como texto SQL; el script
nunca se conecta a ninguna base de datos, solo produce el archivo `.sql` de la migración.

Si se quiere regenerar (por ejemplo, para tener otro set de datos):

```bash
cd code
uv sync
uv run data_generation.py
```

Va a sobrescribir `sql_migrations/V202608111535__seed_data.sql`. La generación
usa una semilla fija, así que el resultado es siempre el mismo; útil para poder
comparar el diff en git si algo cambia en el script.

## Cómo se despliega a main

La idea es que nadie se conecte manualmente a la branch `main`. Sino que cada vez que se haga push a `main`
en el repo de GitHub, tocando algo dentro de `sql_migrations/`, se dispara el workflow
[`flyway-migrate.yml`](.github/workflows/flyway-migrate.yml), que:

1. Traduce el connection string de Neon al formato que Flyway necesita.
2. Corre `flyway info` para ver qué hay pendiente.
3. Corre `flyway validate` para asegurarse de que nadie editó una migración ya
   aplicada.
4. Corre `flyway migrate`.
5. Deja un resumen del resultado en la pestaña Actions del repo.

Para que esto funcione, hay que configurar un secreto en el repo:

**Settings → Secrets and variables → Actions → New repository secret**

| Nombre | Valor |
|---|---|
| `NEON_MAIN_DATABASE_URL` | El connection string completo de la branch **main** de Neon |

## Cómo agregar una migración nueva

1. Crea el archivo en `sql_migrations/` siguiendo el nombre `V<timestamp>__descripcion.sql`
   para cambios de estructura (crear tabla, agregar columna, índice), o
   `R__descripcion.sql` para funciones, store procedures o vistas.
2. Pruébala primero contra `dev`, corriendo `flyway migrate` en la terminal.
3. Cuando funcione, haz commit y push a `main`. El pipeline ci-cd correrá de manera automática toda la migration.

## El error real y cómo se corrigió

Como parte del ejercicio, se introdujo un error de diseño real (no un typo) para
poder documentar el patrón de corrección de Flyway: **roll forward**, nunca
editar una migración que ya corrió.

La migración `V202608111537__add_phone_to_users.sql` agrega la columna `phone`
como `VARCHAR(10)`, pensando solo en números locales. El problema aparece con
cualquier número que incluya el código de país, por ejemplo `+57 3001234567`
(13 caracteres):

```sql
UPDATE users SET phone = '+57 3001234567' WHERE id = 1;
-- ERROR: value too long for type character varying(10)
```

La corrección no edita ese archivo, pues eso rompería el checksum que Flyway guarda
de cada migración ya aplicada. En cambio, `V202608111538__fix_users_phone_length.sql`
amplía la columna a `VARCHAR(18)` como una migración nueva. Después de aplicarla,
el mismo `UPDATE` funciona sin problema.

Las capturas de este error (contra `dev` y contra `main`, en dos runs separados
del pipeline) están en [`docs/evidencias/`](docs/evidencias/).

## Preguntas frecuentes

**¿Por qué hay una tabla `copies` separada de `editions`?**
Porque una edición (por ejemplo, "Cien años de soledad, edición Pingüino") puede
tener varias copias físicas al mismo tiempo, y un préstamo tiene que apuntar a
una copia específica, no a la edición en general; de lo contrario, no sabríamos cuál copia
exacta tiene cada usuario. Más detalle en el documento de dominio.

**¿Por qué `usuarios` y `bibliotecarios` son tablas separadas si ambos son personas?**
Porque tienen atributos distintos (fecha de contratación vs. fecha de registro,
por ejemplo) y roles de negocio distintos. Una misma persona podría, en teoría,
tener una fila en cada tabla sin que eso implique relación entre sí.

**¿Por qué el script de datos no se conecta a la base?**
Porque decidimos que todo el estado inicial —esquema y datos— viviera como
migraciones de Flyway normales, para que `dev` y `main` se levanten exactamente
igual, sin pasos manuales de por medio.

# BanSystem SQL Init Scripts

`BanSystem` usa MySQL como fuente de verdad y no instala automaticamente el schema principal desde SourceMod.

## Scripts

- `mysql/core_schema.sql`
  - base requerida para la suite
- `mysql/access_schema.sql`
  - modulo `bansystem_access`
- `mysql/communication_schema.sql`
  - modulo `bansystem_comm`
- `mysql/sprays_schema.sql`
  - modulo `bansystem_sprays`
- `mysql/adminsync_schema.sql`
  - satelite `bansystem_adminsync`

## Diseno SQL actual

- `BanSystem` ya no depende de procedures MySQL para su runtime normal.
- los scripts de init crean tablas, vistas y triggers; el acceso desde SourcePawn se resuelve con sentencias directas.
- esto evita la limitacion de `SourceMod DBI` con `CALL` + `SQL_TQuery` en flujos threaded.
- `core_schema.sql` define la vista `view_bansystem_auth_summary` como camino normal de lectura para auth.
- si `bansystem_summary` no tiene fila valida para un jugador, el plugin recompone el estado desde los bans activos y vuelve a escribir el summary.

## Orden recomendado

Para una instalación desde cero:

1. importa `access_schema.sql`
2. importa `communication_schema.sql`
3. importa `sprays_schema.sql`
4. importa `core_schema.sql`
5. importa `adminsync_schema.sql` solo si se despliega Admin Sync

`core_schema.sql` crea `view_bansystem_active_summary`, que consulta las vistas activas de acceso, comunicación y sprays. Los schemas de esos tres módulos deben importarse primero, incluso si sus plugins no se cargarán.

No vuelvas a ejecutar `core_schema.sql` para actualizar una base existente: el script elimina y recrea `bansystem_summary`. Las actualizaciones requieren una migración versionada que mantenga los datos existentes y las columnas u objetos adicionales del servidor.

### Core v1 a v3 con extensión callvote

`mysql/migrations/core_v1_to_v3_preserve_callvotes.sql` migra el contrato observado de MariaDB 10.11: core v1, columnas de summary callvote y sus vistas activas. Añade las columnas Legacy que faltan, conserva `bansystem_summary`, los campos y la vista callvote, y actualiza core a v3 solo después de comprobar el contrato.

Las vistas core quedan con `SQL SECURITY DEFINER` y `CURRENT_USER` como definer. Los triggers de summary se crean sin cláusula `DEFINER`, así MariaDB asigna el usuario ejecutor. La cuenta requiere permisos `CREATE VIEW`, `DROP`, `SELECT`, `ALTER`, `TRIGGER`, `UPDATE` y `CREATE TEMPORARY TABLES` sobre el esquema. Sin `SET USER`, MariaDB no permite asignar a la vista otro definer; no ejecutes el script con `--force`.

No la despliegues con un Core cuyo `UpsertPrimarySummary` reemplace `module_mask` por solo `1`, `2` o `4`: esa ruta puede borrar el bit callvote `8` y los campos asociados. Primero valida un binario que conserve bits desconocidos y prueba escrituras sobre cuentas con máscaras `8` y `9`.

Úsala solo si el prechequeo coincide con la base objetivo. Haz un backup completo y verificado, detén los plugins BanSystem y prueba primero sobre un clon sin datos personales. El DDL hace commits implícitos; si falla o necesitas volver atrás, restaura el backup completo. No reviertas solo `version_num` ni uses este script con otro esquema.

## Nota

La version del plugin y la version del schema no son lo mismo. El plugin valida su propio estado de schema al arrancar.

## Limitacion de SourceMod DBI

- `CALL` a procedures MySQL que devuelven filas no debe usarse desde `SQL_TQuery` en caminos threaded sensibles.
- la documentacion oficial de SourceMod indica que el comportamiento del threader es indefinido si la query devuelve multiples resultsets, caso comun en `CALL`.
- para `auth summary`, `detail lookup` y otros flujos de join, `BanSystem` debe preferir `SELECT` directos sobre vistas o tablas.
- los procedures listados arriba siguen siendo validos para mutaciones o tareas administrativas que no dependan de leer resultsets via threader.

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

1. importa `core_schema.sql`
2. importa los scripts de los modulos que realmente vas a desplegar

## Nota

La version del plugin y la version del schema no son lo mismo. El plugin valida su propio estado de schema al arrancar.

## Limitacion de SourceMod DBI

- `CALL` a procedures MySQL que devuelven filas no debe usarse desde `SQL_TQuery` en caminos threaded sensibles.
- la documentacion oficial de SourceMod indica que el comportamiento del threader es indefinido si la query devuelve multiples resultsets, caso comun en `CALL`.
- para `auth summary`, `detail lookup` y otros flujos de join, `BanSystem` debe preferir `SELECT` directos sobre vistas o tablas.
- los procedures listados arriba siguen siendo validos para mutaciones o tareas administrativas que no dependan de leer resultsets via threader.

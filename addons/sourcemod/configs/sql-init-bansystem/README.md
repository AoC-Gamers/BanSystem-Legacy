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

## Orden recomendado

1. importa `core_schema.sql`
2. importa los scripts de los modulos que realmente vas a desplegar

## Nota

La version del plugin y la version del schema no son lo mismo. El plugin valida su propio estado de schema al arrancar.

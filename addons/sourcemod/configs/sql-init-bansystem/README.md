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

## Procedimientos disponibles

- `mysql/core_schema.sql`
  - `bansystem_get_auth_summary`
  - `bansystem_rebuild_summary_account`
  - `bansystem_rebuild_summary_all`
- `mysql/access_schema.sql`
  - `bansystem_access_attempt_record`
  - `bansystem_access_ban_save`
  - `bansystem_access_ban_delete`
  - `bansystem_access_get_active_by_accountid`
  - `bansystem_access_get_active_by_banid`
- `mysql/communication_schema.sql`
  - `bansystem_comm_ban_save`
  - `bansystem_comm_ban_delete`
  - `bansystem_comm_get_active_by_accountid`
  - `bansystem_comm_get_active_by_banid`
- `mysql/sprays_schema.sql`
  - `bansystem_spray_ban_save`
  - `bansystem_spray_ban_delete`
  - `bansystem_spray_get_active_by_accountid`
  - `bansystem_spray_get_active_by_banid`

## Orden recomendado

1. importa `core_schema.sql`
2. importa los scripts de los modulos que realmente vas a desplegar

## Nota

La version del plugin y la version del schema no son lo mismo. El plugin valida su propio estado de schema al arrancar.

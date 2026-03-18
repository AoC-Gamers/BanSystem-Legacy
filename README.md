# BanSystem

Suite modular de sanciones para SourceMod.

`BanSystem` divide autorizacion, bans de acceso, castigos de comunicacion, bans de sprays y sincronizacion de admins en plugins pequenos que comparten una base MySQL y una API comun. La suite esta pensada para desplegar solo los modulos que necesita cada servidor sin duplicar logica de identidad, cache ni detalle de bans.

## Componentes

- `bansystem_core`
  - runtime base de autorizacion, cache local y estado resumido
  - expone la API publica `bansystem_core`
- `bansystem_access`
  - bans de acceso
  - expone la API publica `bansystem_access`
- `bansystem_comm`
  - bans de chat, microfono o ambos
  - expone la API publica `bansystem_comm`
- `bansystem_sprays`
  - bans de sprays
  - expone la API publica `bansystem_sprays`
- `bansystem_sprays_view`
  - vista del propietario del spray para admins
- `bansystem_adminsync`
  - snapshot local de admins y grupos desde MySQL
  - expone la API publica `bansystem_adminsync`
- `bansystem_adminmenu`
  - integracion opcional con el menu admin de SourceMod
  - runtime compartido de paneles para `access`, `comm`, `sprays` y `adminsync`

## Diseño

- `bansystem_core` es la base comun de autorizacion y resumen.
- `access`, `comm` y `sprays` son modulos funcionales independientes sobre MySQL.
- `adminsync` vive como satelite separado porque resuelve otro problema: sincronizar admins de SourceMod desde DB.
- la suite crea autoexecs en:
  - `cfg/sourcemod/bansystem/`
- la suite escribe logs normales en:
  - `addons/sourcemod/logs/bansystem.log`
- los logs debug por plugin viven en:
  - `addons/sourcemod/logs/bansystem/`
- los schemas MySQL viven en:
  - `addons/sourcemod/configs/sql-init-bansystem/`

## Casos de uso comunes

- bans de acceso:
  - `bansystem_core`
  - `bansystem_access`
- bans de comunicacion:
  - `bansystem_core`
  - `bansystem_comm`
- control de sprays:
  - `bansystem_core`
  - `bansystem_sprays`
  - `bansystem_sprays_view`
- sincronizacion de admins:
  - `bansystem_adminsync`
  - `bansystem_adminmenu` opcional

## Documentacion

- [Instalacion](doc/INSTALLATION.md)
- [Plugins y Dependencias](doc/PLUGINS.md)
- [Autorizacion](doc/AUTHORIZATION.md)
- [AdminSync](doc/ADMINSYNC.md)
- [Changelog](CHANGELOG.md)
- [SQL init scripts](doc/SQL_INIT_SCRIPTS.md)
- [SQLite en SourceMod](doc/SQLITE_SOURCEMOD.md)

## SQL

- script base requerido:
  - `addons/sourcemod/configs/sql-init-bansystem/mysql/core_schema.sql`
- scripts modulares:
  - `addons/sourcemod/configs/sql-init-bansystem/mysql/access_schema.sql`
  - `addons/sourcemod/configs/sql-init-bansystem/mysql/communication_schema.sql`
  - `addons/sourcemod/configs/sql-init-bansystem/mysql/sprays_schema.sql`
  - `addons/sourcemod/configs/sql-init-bansystem/mysql/adminsync_schema.sql`

## Limitacion DBI

- `SourceMod DBI` no es una base segura para `CALL` con `SQL_TQuery` cuando el procedure puede devolver multiples resultsets.
- en `BanSystem`, los flujos threaded de autorizacion, summary y detail deben usar `SELECT` directos y deterministas.
- los procedures MySQL pueden seguir usandose para mutaciones o mantenimiento siempre que no dependan de devolver filas por `SQL_TQuery`.
- si un `CALL` con resultados fuera indispensable, debe resolverse fuera del camino critico de join y con una ruta sincronica que consuma todos los resultsets.
- el SQL init actual de `BanSystem` ya no define procedures de runtime; la suite trabaja con sentencias directas, vistas y triggers.

## Estado actual

- MySQL es la fuente de verdad del estado funcional.
- SQLite queda como cache local opcional del core.
- `accountid` es la identidad interna principal.
- `steamid64` se persiste como dato complementario para interoperabilidad externa.
- el auth del core consulta primero la vista consolidada `view_bansystem_auth_summary` sobre `bansystem_summary`.
- si la fila de summary no existe o falla, el core reconstruye el estado con una consulta directa sobre bans activos y repara `bansystem_summary`.

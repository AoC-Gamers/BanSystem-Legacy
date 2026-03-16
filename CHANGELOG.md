# Changelog

## Unreleased

- identidad y cache
  - la cache local limpia ahora usa `accountid` en vez de SteamID string
  - la cache SQLite ahora usa `accountid` como llave interna
  - los lookups MySQL y los bans de acceso/comunicacion se apoyan en `accountid` como identidad principal
- esquema MySQL
  - `steamid64` se mantiene como dato complementario para interoperabilidad externa
  - SteamID2 ya no se persiste en MySQL
  - las tablas de bans ahora almacenan `ban_context`, `banned_by_name` y `banned_by_steamid64`
  - los scripts SQL quedaron separados por modulo en `addons/sourcemod/configs/sql-init-bansystem/mysql/`
  - se elimino del repo el schema monolitico legacy
- resolucion de identidades
  - los comandos que reciben identidades Steam normalizan SteamID2/3 offline
  - la resolucion online de SteamID64 puede completarse via `SteamIDTools`
- documentacion
  - `README.md` paso a ser introduccion e indice
  - se agregaron `doc/INSTALLATION.md`, `doc/PLUGINS.md`, `doc/AUTHORIZATION.md` y `doc/ADMINSYNC.md`
  - se agrego una nota operativa para `sql-init-bansystem`
- release automation
  - se agregaron workflows de build y release para SourceMod
  - el repo ahora soporta canales `develop`, `latest` y releases versionadas por tag

## 1.0.0 - 2026-03-09

Linea estable inicial de `BanSystem`.

- infraestructura base
  - layout SQL externo bajo `addons/sourcemod/configs/sql-init-bansystem/mysql/`
  - validacion de schema MySQL al arranque
  - documentacion operativa para MySQL externo y cache SQLite local
- cambios de arquitectura
  - la instalacion del schema MySQL paso a gestionarse fuera de SourceMod
  - `install.sp` quedo enfocado en reparacion de cache SQLite y constantes compartidas
- fixes
  - los objetos SQLite quedaron alineados con las queries reales del plugin
  - el flujo de unban de comunicacion preserva correctamente el tipo del castigo
  - los caminos de unban limpian entradas stale de SQLite
  - la autorizacion ya no promueve jugadores a cache limpia antes de validar MySQL
  - los menus de duracion preservan los minutos configurados
  - las escrituras SQL escapan correctamente los valores usados al registrar bans

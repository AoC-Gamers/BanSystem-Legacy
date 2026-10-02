# Instalacion

## Requisitos

- SourceMod moderno (`1.11` o `1.12`)
- MySQL

Dependencias opcionales:

- `SteamIDTools`
  - usado por `bansystem_access`, `bansystem_comm`, `bansystem_sprays` y `bansystem_adminsync` para completar resolucion online de SteamID64
- `basecomm`
  - usado por `bansystem_comm` para aplicar mute/gag en vivo
- `adminmenu`
  - usado por `bansystem_adminmenu`
- SQLite local
  - usada por `bansystem_core` como cache opcional mediante la entrada `bansystemcache`

## Despliegue minimo

La forma recomendada es descargar los binarios generados por CI desde GitHub Releases:

- `bansystem-latest.zip`
  - canal estable desde `main`
- `bansystem-develop.zip`
  - canal de integracion desde `develop`
- `bansystem-<version>.zip`
  - release versionada por tag `vX.Y.Z`

Despliegue:

1. Descarga el `.zip` del canal que quieras usar o compila localmente si estas desarrollando.
2. Copia los plugins necesarios a `addons/sourcemod/plugins/`.
3. Copia las traducciones a `addons/sourcemod/translations/`.
4. Si otro plugin va a consumir la API, copia tambien las includes publicas.
5. Reinicia el servidor o carga los plugins.

Compilacion local:

- util para desarrollo o cambios propios de la suite

## SQL de MySQL

BanSystem no instala automaticamente el schema MySQL principal.

En una base nueva, importa en este orden:

1. `addons/sourcemod/configs/sql-init-bansystem/mysql/access_schema.sql`
2. `addons/sourcemod/configs/sql-init-bansystem/mysql/communication_schema.sql`
3. `addons/sourcemod/configs/sql-init-bansystem/mysql/sprays_schema.sql`
4. `addons/sourcemod/configs/sql-init-bansystem/mysql/core_schema.sql`
5. `addons/sourcemod/configs/sql-init-bansystem/mysql/adminsync_schema.sql`, si despliegas Admin Sync.

Core crea `view_bansystem_active_summary`, que depende de las vistas activas de acceso, comunicación y sprays. Por eso los tres schemas modulares deben crear primero sus tablas y vistas, aunque no cargues alguno de esos plugins.

`core_schema.sql` elimina y vuelve a crear `bansystem_summary`. No lo ejecutes sobre una base existente: perderías el summary. Para actualizar, usa una migración versionada que preserve datos, columnas adicionales, vistas y triggers; respáldala y valídala antes de desplegarla. La migración específica para core v1 con extensión callvote está documentada en [SQL_INIT_SCRIPTS.md](SQL_INIT_SCRIPTS.md).

## Configuracion de databases.cfg

Entrada principal:

- `bansystem`
  - MySQL principal de la suite

Entrada opcional:

- `bansystemcache`
  - SQLite local para la cache del core

## Autoexecs

La suite crea autoexecs en:

- `cfg/sourcemod/bansystem/`

Archivos esperados:

- `bansystem_core.cfg`
- `bansystem_access.cfg`
- `bansystem_comm.cfg`
- `bansystem_sprays.cfg`
- `bansystem_sprays_view.cfg`
- `bansystem_adminsync.cfg`

## Despliegues recomendados

### Solo acceso

Carga:

- `bansystem_core`
- `bansystem_access`

### Acceso y comunicacion

Carga:

- `bansystem_core`
- `bansystem_access`
- `bansystem_comm`

### Sprays

Carga:

- `bansystem_core`
- `bansystem_sprays`
- `bansystem_sprays_view` opcional

### Admin Sync

Carga:

- `bansystem_adminsync`
- `bansystem_adminmenu` opcional

## Orden practico de carga

Orden recomendado:

1. `steamidtools` si lo usas
2. `basecomm` si lo usas
3. `bansystem_core`
4. `bansystem_access`
5. `bansystem_comm`
6. `bansystem_sprays`
7. `bansystem_sprays_view`
8. `bansystem_adminsync`
9. `bansystem_adminmenu`

Los modulos toleran dependencias opcionales tardias, pero ese orden reduce ruido de arranque.

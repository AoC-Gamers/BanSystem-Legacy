# Plugins y Dependencias

## bansystem_core

Rol:

- runtime base de autorizacion
- cache local limpia por `accountid`
- cache SQLite opcional de resumen
- coordinacion del estado resumido entre modulos

Comandos:

- ninguno en la linea actual

ConVars principales:

- `sm_bs_core_mysql_config`
- `sm_bs_core_sqlitecache`
- `sm_bs_core_cache_config`
- `sm_bs_core_localcache`
- `sm_bs_core_auth_timeout`
- `sm_bs_core_debug_mask`

Library publica:

- `bansystem_core`

## bansystem_access

Rol:

- bans de acceso
- consultas de detalle y listados de bans activos
- panel de flujo rapido para admins via `bansystem_adminmenu`

Comandos:

- `sm_bs_access_detail`
- `sm_bs_access_add`
- `sm_bs_access_remove`
- `sm_bs_access_info`
- `sm_bs_access_list`

ConVars principales:

- `sm_bs_access_debug_mask`
- `sm_bs_access_mysql_config`
- `sm_bs_access_steamid_provider`

Dependencias:

- requiere `bansystem_core`
- usa `SteamIDTools` si esta presente

Library publica:

- `bansystem_access`

## bansystem_comm

Rol:

- bans de chat, microfono o ambos
- integra aplicacion en vivo mediante `basecomm`
- panel de flujo rapido para admins via `bansystem_adminmenu`

Comandos:

- `sm_bs_comm_detail`
- `sm_bs_comm_add`
- `sm_bs_comm_remove`
- `sm_bs_comm_info`
- `sm_bs_comm_list`

ConVars principales:

- `sm_bs_comm_debug_mask`
- `sm_bs_comm_mysql_config`
- `sm_bs_comm_steamid_provider`

Dependencias:

- requiere `bansystem_core`
- usa `SteamIDTools` si esta presente
- usa `basecomm` para aplicar mute/gag en vivo

Library publica:

- `bansystem_comm`

## bansystem_sprays

Rol:

- bans de sprays
- consultas de detalle y listados
- panel de flujo rapido para admins via `bansystem_adminmenu`

Comandos:

- `sm_bs_sprays_detail`
- `sm_bs_sprays_add`
- `sm_bs_sprays_remove`
- `sm_bs_sprays_info`
- `sm_bs_sprays_list`

ConVars principales:

- `sm_bs_sprays_debug_mask`
- `sm_bs_sprays_mysql_config`
- `sm_bs_sprays_steamid_provider`

Dependencias:

- requiere `bansystem_core`
- usa `SteamIDTools` si esta presente

Library publica:

- `bansystem_sprays`

## bansystem_sprays_view

Rol:

- muestra informacion del propietario del spray al apuntarlo

Comandos:

- ninguno

ConVars principales:

- `sm_bs_sprays_view_enabled`
- `sm_bs_sprays_view_textloc`
- `sm_bs_sprays_view_info_mask`
- `sm_bs_sprays_view_distance`
- `sm_bs_sprays_view_debug_mask`

Dependencias:

- pensado para convivir con `bansystem_sprays`

## bansystem_adminsync

Rol:

- sincroniza admins, grupos y membresias desde MySQL
- construye un snapshot local en `sqlite` o `kv`
- reconstruye el `AdminCache` de SourceMod

Comandos:

- `sm_bs_adminsync_reload`
- `sm_bs_adminsync_verify`
- `sm_bs_adminsync_ls_admins`
- `sm_bs_adminsync_ls_groups`
- `sm_bs_adminsync_ls_memberships`
- `sm_bs_admin_add`
- `sm_bs_admin_del`
- `sm_bs_admin_set_flags`
- `sm_bs_admin_set_immunity`
- `sm_bs_admin_add_group`
- `sm_bs_admin_remove_group`
- `sm_bs_group_add`
- `sm_bs_group_del`
- `sm_bs_group_set_flags`
- `sm_bs_group_set_immunity`

ConVars principales:

- `sm_bs_adminsync_mysql_config`
- `sm_bs_adminsync_backend`
- `sm_bs_adminsync_autosync`
- `sm_bs_adminsync_steamid_provider`
- `sm_bs_adminsync_debug_mask`

Dependencias:

- usa `SteamIDTools` si esta presente

Library publica:

- `bansystem_adminsync`

## bansystem_adminmenu

Rol:

- integra `BanSystem` en el menu admin de SourceMod
- expone y ejecuta los paneles de `access`, `comm`, `sprays` y `adminsync`

Comandos:

- `sm_bs_access_panel`
- `sm_bs_access_abort`
- `sm_bs_comm_panel`
- `sm_bs_comm_abort`
- `sm_bs_sprays_panel`
- `sm_bs_sprays_abort`
- `sm_bs_admin_panel`
- `sm_bs_group_panel`
- `sm_bs_adminsync_abort`

Dependencias:

- requiere `adminmenu`
- consume las APIs publicas de `access`, `comm` y `sprays`
- consume la API publica y el snapshot local de `adminsync`

## bansystem_modular_test

Rol:

- harness manual para validar la linea modular con jugadores reales

ConVars principales:

- `sm_bs_modtest_mysql_config`

Dependencias:

- pensado para entornos de prueba, no para despliegue normal

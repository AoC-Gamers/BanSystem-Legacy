# AdminSync

## Resumen

`bansystem_adminsync` sincroniza administradores, grupos y membresias desde MySQL a un snapshot local y reconstruye el `AdminCache` de SourceMod desde ese snapshot.

## Backend local

Backends soportados:

- `sqlite`
  - recomendado
- `kv`
  - opcional

Configuracion:

- `sm_bs_adminsync_backend`
- `sm_bs_adminsync_mysql_config`
- `sm_bs_adminsync_autosync`
- `sm_bs_adminsync_steamid_provider`
- `sm_bs_adminsync_debug_mask`

## Deteccion de cambios

La deteccion usa:

- `adminsync_meta.snapshot_version`
- chequeo en `OnConfigsExecuted()` por cambio de mapa
- recarga manual con `sm_bs_adminsync_reload`

No hay polling por timer en la linea actual.

## Snapshot local

SQLite local:

- `addons/sourcemod/data/sqlite/bansystem_adminsync.sq3`

KV local:

- `addons/sourcemod/data/bansystem_adminsync_snapshot.txt`

## Flujo

1. conecta a MySQL
2. valida schema del componente `adminsync`
3. lee `snapshot_version`
4. sincroniza `admins`, `groups` y `memberships`
5. reconstruye el snapshot local
6. reaplica `AdminCache` de SourceMod

## Identidad

- identidad interna: `accountid`
- SteamID2 se reconstruye offline para enlazar admins en SourceMod
- SteamID64 queda soportado via `SteamIDTools` en mutaciones donde haga falta

## Comandos

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

## Notas operativas

- los comandos aceptan `target`, `SteamID2`, `SteamID3` y `accountid` offline
- si el target offline entra como `SteamID64`, `SteamIDTools` puede completar la resolucion
- los paneles de admins y grupos ahora viven en `bansystem_adminmenu`
- `bansystem_adminsync` sigue siendo el dueño del snapshot local y de las mutaciones

## API publica

Library:

- `bansystem_adminsync`

Natives utiles:

- `bBSASReload()`
- `bBSASIsSyncInProgress()`
- `iBSASGetSnapshotVersion()`
- `iBSASGetAdminCount()`
- `bBSASGetAdminByIndex(int index, int &accountid, char[] name, int maxlen)`
- `iBSASGetGroupCount()`
- `bBSASGetGroupByIndex(int index, char[] name, int maxlen)`
- `bBSASIsAdmin(int accountid)`
- `bBSASAdminHasGroup(int accountid, const char[] group)`

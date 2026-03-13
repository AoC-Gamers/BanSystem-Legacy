# BanSystem

BanSystem es un plugin para SourceMod que permite gestionar sanciones en servidores de juegos. Este sistema integra una base de datos para almacenar y consultar información sobre prohibiciones de acceso y comunicación.

## Características

- **Prohibiciones de acceso**: Bloquea el acceso de jugadores al servidor.
- **Prohibiciones de comunicación**: Restringe el uso del chat y/o micrófono.
- **Soporte para bases de datos**: Compatible con MySQL y SQLite.
- **Caché local y SQL**: Mejora el rendimiento almacenando temporalmente datos de prohibiciones.
- **Razones personalizables**: Configura razones de prohibición en un archivo de configuración.
- **Soporte multilenguaje**: Traducciones disponibles para mensajes y razones.

## Sistemas de Caché

BanSystem utiliza dos sistemas de caché para optimizar el rendimiento y reducir la carga en la base de datos principal:

### **Base de Datos MySQL**
- **Descripción**: Es la base de datos principal donde se almacenan todas las sanciones.
- **Uso**:
  - Guarda información detallada sobre las prohibiciones de acceso y comunicación.
  - Es obligatoria para el funcionamiento del plugin.
- **Ventajas**:
  - Permite consultas completas y persistencia de datos a largo plazo.
  - Compatible con múltiples servidores que compartan la misma base de datos.

### **Base de Datos SQLite (Opcional)**
- **Descripción**: Es una base de datos ligera utilizada para el sistema de caché.
- **Uso**:
  - Almacena temporalmente información sobre jugadores sancionados para reducir consultas frecuentes a la base de datos MySQL.
  - Es opcional y se puede habilitar o deshabilitar mediante la variable de consola `sm_bansystem_sqlitecache`.
- **Ventajas**:
  - Mejora el rendimiento al manejar jugadores con sanciones permanentes o recientes.
  - La información persiste incluso si el servidor se reinicia.

### Diferencias Principales

| Característica          | MySQL                                | SQLite                              |
|-------------------------|---------------------------------------|-------------------------------------|
| **Propósito**           | Almacenar todas las sanciones        | Sistema de caché opcional          |
| **Persistencia**        | Permanente                           | Temporal (7 días por defecto)      |
| **Requerido**           | Sí                                   | No                                 |
| **Velocidad**           | Más lento debido a consultas remotas | Más rápido para consultas locales  |

Ambos sistemas trabajan en conjunto para garantizar un rendimiento óptimo y minimizar las consultas a la base de datos principal.

## Requisitos

- **SourceMod**: Versión 1.10 o superior.
- **Base de datos**:
  - **MySQL**: Obligatoria para almacenar sanciones.
  - **SQLite**: Opcional para el sistema de caché.

## Instalación

1. **Descargar el plugin**:
   - Clona este repositorio o descarga el archivo ZIP.

2. **Compilar el plugin**:
   - Usa el compilador de SourceMod para compilar los archivos `.sp` en `.smx`.

3. **Subir los archivos**:
   - Copia los archivos `.smx` a la carpeta `addons/sourcemod/plugins/`.
   - Copia los archivos de traducción a `addons/sourcemod/translations/`.

4. **Preparar MySQL externamente**:
   - Importa `ScriptsSQL/mysql/schema.sql`.
   - El plugin valida en el arranque la tabla `bansystem_schema_version`.
   - La versión de esquema MySQL requerida actualmente es `6`.

5. **Configurar la base de datos**:
   - Edita el archivo `addons/sourcemod/configs/databases.cfg` para añadir la configuración de la base de datos MySQL.
   - Si deseas habilitar el caché SQLite, asegúrate de que esté configurado correctamente.

6. **Preparar SQLite cache (opcional)**:
   - El plugin valida esta caché al conectar `bansystemcache`, pero no la instala automáticamente.
   - Si falta el esquema SQLite, el plugin registrará error y desactivará la caché hasta ejecutar `sm_bs_cache_install` o `sm_bs_cache_reinstall`.

7. **Reiniciar el servidor**:
   - Reinicia tu servidor para cargar el plugin.

## Comandos

- `sm_ban <usuario|steamid|steamid3|steamid64|accountid> [tiempo] [razón]`: Prohibir el acceso de un jugador.
- `sm_unban <steamid|steamid3|steamid64|accountid>`: Levantar una prohibición de acceso.
- `sm_ban_info <steamid|steamid3|steamid64|accountid>`: Ver el detalle de una prohibición de acceso activa.
- `sm_ban_ls [limit]`: Listar prohibiciones de acceso activas desde MySQL.
- `sm_ban_attempt_steamid <steamid|steamid3|steamid64|accountid>`: Ver intentos de acceso asociados a una identidad Steam.
- `sm_ban_attempt_ip <ip>`: Ver intentos de acceso asociados a una IP.
- `sm_comm <mic|chat|all> <usuario|steamid|steamid3|steamid64|accountid> [tiempo] [razón]`: Prohibir la comunicación de un jugador.
- `sm_uncomm <usuario|steamid|steamid3|steamid64|accountid>`: Levantar una prohibición de comunicación.
- `sm_comm_info <steamid|steamid3|steamid64|accountid>`: Ver el detalle de una prohibición de comunicación activa.
- `sm_comm_ls`: Listar solo jugadores conectados con castigos de comunicación en memoria.
- `sm_comm_db_ls [limit]`: Listar prohibiciones de comunicación activas desde MySQL.
- `sm_comm_clear`: Limpiar todas las prohibiciones de comunicación.
- `sm_abort`: Cancelar una prohibición en proceso.

Notas:
- Los comandos `*_ls` con sufijo `db` consultan MySQL y muestran bans activos aunque el jugador no esté conectado.
- `sm_comm_ls` es un listado rápido basado en estado local del servidor; no reemplaza `sm_comm_db_ls`.
- `limit` usa `50` por defecto y tiene tope de `200`.
- Si omites `tiempo`, BanSystem lo interpreta como permanente (`0`).

## Configuración

- **Razones de prohibición**:
  - Edita el archivo `configs/bansystem_reasons.txt` para añadir o modificar razones de prohibición.

- **Variables de consola**:
- `sm_bansystem_sqlitecache`: Habilita o deshabilita el caché SQLite (1 = habilitado, 0 = deshabilitado).
- `sm_bansystem_localcache`: Habilita o deshabilita el caché local (1 = habilitado, 0 = deshabilitado).
- `sm_bansystem_auth_timeout`: Tiempo máximo de espera del check de auth antes de rechazar al jugador.
- `sm_bansystem_steamid_provider`: Provider online para resolver SteamID64 en comandos (`auto`, `steamworks`, `system2`).
- `sm_bansystem_Attempt`: Habilita o deshabilita el registro de intentos de acceso en MySQL.
- `sm_bansystem_debug_mask`: Bitmask de debug (`1=general`, `2=sql`, `4=menu`, `8=api`).

## Flujo de autorización

El flujo actual de autorización se basa en `account_id` y distingue entre vida normal del plugin y transición de mapa.

- MySQL es la fuente de verdad.
- SQLite es una caché local opcional, validada y de instalación manual.
- La caché local en memoria guarda jugadores limpios por `account_id` durante toda la vida del plugin.

Orden normal de decisión:

1. resolver `account_id`
2. revisar caché local de limpios
3. consultar MySQL
4. usar SQLite solo como caché auxiliar cuando aplica

Transición de mapa:

- `OnMapEnd` y `OnMapStart` activan modo de transición.
- Los clientes autorizados durante esa ventana entran a una cola de verificación.
- Cuando MySQL queda validada, BanSystem drena la cola.
- Si el jugador ya está en la caché local de limpios, se resuelve sin volver a consultar DB.
- Los demás siguen el flujo normal de autorización.

Notas operativas:

- Si el backend todavía no está listo, BanSystem encola la verificación en vez de expulsar inmediatamente.
- Los callbacks SQL viejos se descartan si el cliente ya salió del estado de verificación.
- Se detecta opcionalmente la librería `l4d2_changelevel`, pero el flujo principal de transición se apoya en `OnMapStart` y `OnMapEnd`.

## Scripts SQL

- `ScriptsSQL/mysql/schema.sql`: esquema canónico actual de MySQL.
- `ScriptsSQL/mysql/adminsync_schema.sql`: esquema MySQL del satélite `bansystem_adminsync`.
- `ScriptsSQL/README.md`: notas operativas sobre versión de esquema.
- `BANSYSTEM_MODULAR_CORE.md`: propuesta de evolución a `core + módulos` con tabla resumen central.
- `SQLITE_SOURCEMOD.md`: marco de trabajo recomendado para usar SQLite desde SourceMod en este proyecto.
- `TESTING.md`: suite de smoke, integración y regresión recomendada para el plugin.

## Estructura del plugin

El archivo principal `addons/sourcemod/scripting/bansystem.sp` actúa como bootstrap y orquestador. La lógica quedó separada por responsabilidad en módulos internos:

- `addons/sourcemod/scripting/bansystem/schema.sp`: constantes de esquema, versión MySQL esperada y gestión/validación del esquema SQLite de caché.
- `addons/sourcemod/scripting/bansystem/helpers.sp`: helpers compartidos de replies, impresión en consola, contextos de callbacks y utilidades de salida.
- `addons/sourcemod/scripting/bansystem/api.sp`: natives, forwards y callbacks asíncronos expuestos a otros plugins.
- `addons/sourcemod/scripting/bansystem/identity.sp`: resolución y normalización de `SteamID2`, `SteamID3`, `SteamID64` y `account_id`.
- `addons/sourcemod/scripting/bansystem/auth.sp`: flujo de autorización, transición de mapa, cola de verificación y callbacks de auth.
- `addons/sourcemod/scripting/bansystem/db.sp`: conexión a MySQL/SQLite, validación de esquema MySQL y limpieza de expirados.
- `addons/sourcemod/scripting/bansystem/access.sp`: comandos y flujo de bans de acceso.
- `addons/sourcemod/scripting/bansystem/communication.sp`: comandos y flujo de bans de comunicación.
- `addons/sourcemod/scripting/bansystem/cache.sp`: comandos administrativos y utilidades de caché local/SQLite.

## Esquema MySQL

- MySQL usa `accountid` como llave numérica principal en las tablas funcionales.
- `steamid64` se persiste como dato complementario para interoperabilidad externa.
- SteamID2 ya no se persiste en MySQL; el plugin lo reconstruye offline desde `accountid` cuando necesita mostrarlo.
- Las tablas de bans ahora guardan además:
  - `ban_context`: contexto opcional adicional al motivo principal
  - `banned_by_name`: nickname del admin al momento del ban
  - `banned_by_steamid64`: SteamID64 del admin al momento del ban

## API

- Harness de integración con jugadores reales: `addons/sourcemod/scripting/bansystem_test.sp`.
- El callback asíncrono recibe `requestId`, `bAccepted`, `szResolvedAuthId`, `szError` y `data`.

## BanSystem Admin Sync

El satélite inicial `addons/sourcemod/scripting/bansystem_adminsync.sp` sincroniza administradores y grupos desde MySQL a un snapshot local.

- Backend local soportado:
  - `sqlite` recomendado
  - `kv` opcional
- Detección de cambios:
  - `adminsync_meta.snapshot_version`
  - polling liviano configurable con `sm_bs_adminsync_check_interval`
  - recarga manual con `sm_bs_adminsync_reload`
- Debug:
  - `sm_bs_adminsync_debug_mask`
  - bitmask: `1=general`, `2=sql`, `4=menu`, `8=api`
- Archivo KV local:
  - `addons/sourcemod/data/bansystem_adminsync_snapshot.txt`
- Base SQLite local:
  - `addons/sourcemod/data/sqlite/bansystem_adminsync.sq3`
- Comandos:
  - `sm_bs_adminsync_reload`
  - `sm_bs_adminsync_status`
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
  - `sm_bs_admin_panel`
  - `sm_bs_group_panel`
  - `sm_bs_adminsync_abort`

El satélite:

- sincroniza `admins`, `groups` y `memberships` desde MySQL
- construye el snapshot local en `sqlite` o `kv`
- reconstruye el `AdminCache` de SourceMod desde ese snapshot local
- usa `accountid` como identidad interna y reconstruye SteamID2 offline solo para enlazar admins en SourceMod
- expone la library pública `bansystem_adminsync` con include en `addons/sourcemod/scripting/include/bansystem_adminsync.inc`
- ejemplo de consumo en `addons/sourcemod/scripting/bansystem_adminsync_example.sp`

Notas operativas:

- Los comandos de admin aceptan `target`, `SteamID2`, `SteamID3` y `accountid` offline.
- `SteamID64` queda soportado vía `SteamIDTools` en mutaciones de admin.
- En `sm_bs_admin_add`, si el target offline entra como `SteamID64`, puedes pasar `[name]` opcional; si no se entrega, se guarda `UNKNOWN`.
- Los paneles están orientados al flujo operativo rápido:
  - alta de admin desde jugador conectado
  - asignación y remoción de grupos a admins
  - edición y borrado desde snapshot local
  - alta/edición/borrado de grupos

### Harness de pruebas

El plugin `bansystem_test.sp` permite correr pruebas reales con 2 jugadores humanos conectados.

Comandos:

- `sm_bs_test_begin <playerA> <playerB>`
- `sm_bs_test_status`
- `sm_bs_test_comm`
- `sm_bs_test_access`
- `sm_bs_test_access_attempt`
- `sm_bs_test_access_unban`
- `sm_bs_test_sqlite_status`
- `sm_bs_test_sqlite_ls`
- `sm_bs_test_sqlite_a`
- `sm_bs_test_sqlite_b`
- `sm_bs_test_perm_comm <a|b> <mic|chat|all>`
- `sm_bs_test_perm_access <a|b>`
- `sm_bs_test_cleanup`
- `sm_bs_test_report`
- `sm_bs_test_reset`

Flujo mínimo:

1. iniciar sesión con `sm_bs_test_begin`
2. correr `sm_bs_test_comm`
3. correr `sm_bs_test_access`
4. esperar reconnect de `playerA`
5. correr `sm_bs_test_access_attempt`
6. correr `sm_bs_test_access_unban`
7. correr `sm_bs_test_report`
8. cerrar con `sm_bs_test_cleanup`

`sm_bs_test_report` resume la sesión como `PASS`, `FAIL` o `INCOMPLETE` con checks esperados/completados/fallidos.

Comandos SQLite:

- `sm_bs_test_sqlite_status`: confirma si el harness pudo abrir la conexión SQLite `bansystemcache`.
- `sm_bs_test_sqlite_ls`: lista el contenido actual de `BanCache_Valid`.
- `sm_bs_test_sqlite_a`: consulta la entrada SQLite del jugador A actual.
- `sm_bs_test_sqlite_b`: consulta la entrada SQLite del jugador B actual.
- `sm_bs_test_perm_comm <a|b> <mic|chat|all>`: aplica un ban permanente y luego valida automáticamente la entrada esperada en SQLite.
- `sm_bs_test_perm_access <a|b>`: aplica un ban de acceso permanente y luego valida automáticamente la entrada esperada en SQLite.

## Versionado

- Desde este corte, el plugin usa versionado semántico.
- `1.0.0` representa la línea estable actual del proyecto.
- El historial de cambios se documenta en `CHANGELOG.md`.

## Nota de versiones

- La versión del plugin y la versión del esquema MySQL no son la misma cosa.
- El plugin actual reporta `1.0.0`.
- El esquema MySQL requerido actualmente es `6`.

## Contribuciones

¡Las contribuciones son bienvenidas! Si encuentras un error o tienes una idea para mejorar el plugin, abre un issue o envía un pull request.

## Licencia

Este proyecto está licenciado bajo la [MIT License](https://opensource.org/licenses/MIT).

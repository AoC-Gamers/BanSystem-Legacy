# Autorizacion

## Resumen

El flujo de autorizacion de `BanSystem` vive en `bansystem_core` y usa `accountid` como identidad interna principal.

Principios:

- MySQL es la fuente de verdad.
- SQLite y la cache limpia en memoria no autorizan conexiones.
- cada conexion necesita una lectura vigente de MySQL.
- el sistema diferencia entre operacion normal y transicion de mapa

## Orden normal de decision

1. resolver `accountid`
2. consultar MySQL y validar el resumen
3. cargar los detalles de cada modulo activo
4. marcar el resumen como resuelto solo al completar toda la cadena

SQLite se conserva para sincronizacion local; nunca cierra una autorizacion.

## Timeout y reintentos

- `sm_bs_core_auth_timeout` limita cuanto tiempo la conexion queda pendiente.
- al vencer sin verificacion, Core permite continuar, deja `HasResolvedSummary`
  falso y reintenta en segundo plano.
- los reintentos usan backoff de 1, 2, 4, 8, 16 y 30 segundos; 30 segundos es
  el maximo mientras la conexion siga activa.
- cada intento tiene una generacion. Los callbacks SQL y de detalle con una
  generacion anterior se descartan y no pueden marcar al usuario como limpio.
- un callback tardio del intento actual puede resolver el estado antes del
  siguiente intento; no se inicia un segundo retry timer.
- las conexiones MySQL y su version de esquema se revalidan cada 30 segundos
  cuando Core no esta listo. Tras una migracion compatible, el flujo recupera
  disponibilidad sin reiniciar el servidor.

## Transicion de mapa

Durante transicion:

- `OnMapStart` y `OnMapEnd` activan modo de transicion
- los clientes autorizados en esa ventana entran a una cola de verificacion
- al cambiar de mapa se cancelan generaciones y timers anteriores
- cuando MySQL queda lista, `bansystem_core` vuelve a verificar clientes conectados

Efectos:

- no se acepta ningun resultado local como prueba de ausencia de ban
- si MySQL no esta lista, el usuario queda sin resumen verificado y se reintenta

## Notas operativas

- si el backend todavia no esta listo, Core permite continuar despues del timeout
- los callbacks viejos se descartan por userid, accountid y generacion
- `l4d2_changelevel` puede estar presente, pero el flujo principal de transicion se apoya en `OnMapStart` y `OnMapEnd`

## API relacionada

Natives utiles de `bansystem_core`:

- `BSCore_IsMapTransitionActive()`
- `BSCore_IsClientAuthPending(int client)`
- `BSCore_GetClientAuthGeneration(int client, int accountid)`
- `BSCore_IsClientAuthGenerationCurrent(int client, int accountid, int generation)`
- `BSCore_IsLocalCleanCached(int accountid)`
- `BSCore_AddLocalCleanCache(int accountid)`
- `BSCore_RemoveLocalCleanCache(int accountid)`

## Visibilidad operativa

- el estado operativo del core se observa por logs y por los modulos que consumen su API
- en modo normal, los eventos relevantes de arranque y enforcement se escriben en `addons/sourcemod/logs/bansystem.log`
- en modo debug, cada plugin escribe su detalle tecnico en `addons/sourcemod/logs/bansystem/`

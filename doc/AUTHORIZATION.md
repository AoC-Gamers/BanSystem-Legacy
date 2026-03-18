# Autorizacion

## Resumen

El flujo de autorizacion de `BanSystem` vive en `bansystem_core` y usa `accountid` como identidad interna principal.

Principios:

- MySQL es la fuente de verdad.
- SQLite es solo cache local opcional.
- la cache local en memoria guarda jugadores limpios por `accountid`
- el sistema diferencia entre operacion normal y transicion de mapa

## Orden normal de decision

1. resolver `accountid`
2. revisar cache local de limpios
3. consultar MySQL
4. usar SQLite solo como cache auxiliar cuando aplica

## Transicion de mapa

Durante transicion:

- `OnMapStart` y `OnMapEnd` activan modo de transicion
- los clientes autorizados en esa ventana entran a una cola de verificacion
- cuando MySQL queda lista, `bansystem_core` drena la cola

Efectos:

- si el jugador ya existe en la cache local de limpios, se resuelve sin nueva consulta remota
- los demas vuelven al flujo normal de autorizacion

## Notas operativas

- si el backend todavia no esta listo, el core encola la verificacion en vez de expulsar inmediatamente
- los callbacks SQL viejos se descartan si el cliente ya salio del estado de verificacion
- `l4d2_changelevel` puede estar presente, pero el flujo principal de transicion se apoya en `OnMapStart` y `OnMapEnd`

## API relacionada

Natives utiles de `bansystem_core`:

- `BSCore_IsMapTransitionActive()`
- `BSCore_IsClientAuthPending(int client)`
- `BSCore_IsLocalCleanCached(int accountid)`
- `BSCore_AddLocalCleanCache(int accountid)`
- `BSCore_RemoveLocalCleanCache(int accountid)`

## Visibilidad operativa

- el estado operativo del core se observa por logs y por los modulos que consumen su API
- en modo normal, los eventos relevantes de arranque y enforcement se escriben en `addons/sourcemod/logs/bansystem.log`
- en modo debug, cada plugin escribe su detalle tecnico en `addons/sourcemod/logs/bansystem/`

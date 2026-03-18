# BanSystem Web Panel Prompt

## Objetivo

Este documento guarda un prompt listo para usar con HeroUI AI para diseñar una plataforma web para BanSystem, junto con ideas complementarias para extender el sistema.

## Prompt Para HeroUI AI

Quiero que diseñes y generes una aplicación web moderna, responsive y lista para producción para un sistema llamado BanSystem. La aplicación consumirá una base de datos MySQL existente y usará autenticación únicamente con Steam OpenID / Sign in through Steam.

### Objetivo del sistema

- Permitir a cualquier usuario autenticado con Steam consultar sus sanciones activas e históricas.
- Permitir a administradores autenticados gestionar bans manualmente sin necesidad de estar conectados al servidor del juego.
- Permitir a administradores revisar intentos de acceso bloqueados.
- No incluir sistema de apelaciones dentro de la web; las apelaciones se hacen por Discord.

### Contexto funcional

- El sistema maneja tres tipos principales de sanciones:
  - Access bans
  - Communication bans
  - Spray bans
- Los datos existen en una base MySQL ya operativa.
- Los usuarios pueden identificarse con cualquier formato de SteamID en el buscador:
  - SteamID64
  - SteamID2
  - SteamID3
  - AccountID
- La UI debe sentirse moderna, clara y administrativa, pero no genérica.
- Diseñar una interfaz con buena jerarquía visual, tablas potentes, filtros útiles y navegación clara.

### Requisitos principales de la aplicación

#### 1. Home

- Crear una página principal que explique claramente para qué sirve la plataforma.
- Incluir:
  - qué es BanSystem
  - qué tipos de sanciones existen
  - cómo iniciar sesión con Steam
  - diferencia entre usuario normal y administrador
  - enlace visible a Discord para apelaciones
- Incluir un bloque de preguntas frecuentes corto.
- Incluir CTA claros:
  - Iniciar sesión con Steam
  - Buscar SteamID
  - Ver documentación / ayuda

#### 2. Login con Steam

- Usar solo autenticación con Steam.
- No implementar login local, email ni contraseña.
- Tras login:
  - si el usuario es normal, llevarlo a una vista de resumen personal
  - si el usuario es administrador, llevarlo a un dashboard administrativo
- El sistema debe detectar rol de administrador a partir de una lista o tabla configurable en backend.

#### 3. Buscador universal de SteamID

- Crear un buscador visible y reusable en la aplicación.
- Debe aceptar cualquier formato de SteamID y normalizarlo.
- Mostrar errores claros si el formato no es válido.
- Si encuentra al usuario:
  - mostrar perfil resumido
  - mostrar accountid, SteamID64, SteamID2, nombre más reciente si existe
  - mostrar pestañas de sanciones
- Si no encuentra registros, mostrar estado vacío útil, no solo error.

#### 4. Vista de usuario autenticado normal

- Si el usuario tiene una sanción activa:
  - mostrar aviso destacado al entrar
  - llevarlo a una página resumen de su sanción activa
- Esa página debe mostrar:
  - tipo de sanción activa
  - duración
  - fecha de expiración
  - motivo
  - contexto
  - aplicado por
  - estado actual
- Si tiene múltiples sanciones activas, mostrar resumen por bloques separados.
- También permitir ver historial de sanciones previas en pestañas o tablas.
- Incluir recordatorio visible:
  - Las apelaciones se hacen por Discord

#### 5. Dashboard de administrador

- Debe permitir:
  - buscar usuarios por cualquier formato de SteamID
  - ver sanciones activas e históricas
  - agregar bans
  - modificar bans
  - desbanear
  - eliminar registros si el rol lo permite
- El dashboard debe estar dividido en secciones claras:
  - Resumen general
  - Gestión de access bans
  - Gestión de communication bans
  - Gestión de spray bans
  - Intentos de acceso bloqueados
- Cada acción sensible debe tener confirmación y feedback claro.
- Incluir auditoría visible:
  - quién hizo el cambio
  - cuándo
  - qué cambió

#### 6. Tablas de sanciones

- Crear pestañas separadas para:
  - Access
  - Comm
  - Spray
- Cada pestaña debe mostrar tabla con filtros y búsqueda.
- Columnas sugeridas:
  - ID
  - accountid
  - SteamID64
  - player_name
  - ban_length
  - ban_reason
  - ban_context
  - banned_by
  - banned_by_name
  - date_expire
  - date_reg
  - estado activo / expirado
- Permitir ordenamiento, búsqueda y filtrado.
- Mostrar badges visuales para:
  - activa
  - permanente
  - expirada
  - voice
  - chat
  - all

#### 7. Gestión de bans

- Formularios administrativos para crear y editar bans.
- Soportar:
  - duration en minutos
  - permanente
  - motivo
  - contexto
  - tipo de communication ban: mic, chat, all
- Validaciones:
  - no permitir motivo vacío
  - controlar rangos de duración
  - confirmar antes de sobrescribir un ban activo
- Si el usuario ya tiene ban activo de ese módulo, la UI debe mostrarlo antes de permitir cambios.

#### 8. Intentos de acceso bloqueados

- Crear una sección administrativa para visualizar bansystem_access_attempts.
- Mostrar tabla con filtros por:
  - player_name
  - accountid
  - steamid64
  - ip_address
  - fecha
- Permitir ordenar por fecha descendente por defecto.
- Permitir abrir desde esa tabla una vista del jugador y sus sanciones relacionadas.

#### 9. Apelaciones

- No implementar sistema interno de apelaciones.
- Reemplazarlo por:
  - botón a Discord
  - mensaje contextual en vistas de sanción
  - texto claro para usuarios sancionados

#### 10. Diseño visual

- Quiero una UI moderna, seria, clara y con personalidad.
- Evitar diseño genérico estilo dashboard básico.
- Buscar una identidad visual limpia, técnica y elegante.
- Usar HeroUI de forma intencional:
  - tablas premium
  - filtros cómodos
  - drawer o modal para acciones
  - cards de resumen
  - estados vacíos trabajados
- Responsive en desktop y mobile.
- La navegación en desktop debe priorizar productividad.
- La navegación mobile debe priorizar consulta rápida.

#### 11. Arquitectura sugerida

- Proponer una arquitectura full-stack clara.
- Preferencia por:
  - Next.js
  - TypeScript
  - HeroUI
  - autenticación con Steam OpenID
  - API server actions o endpoints claros
  - acceso a MySQL con capa de servicios
- Separar:
  - autenticación
  - autorización
  - acceso a datos
  - vistas de usuario
  - vistas de administrador
- No acoplar la UI directamente a queries crudas.

#### 12. Roles y permisos

- Implementar al menos dos roles:
  - user
  - admin
- Los usuarios normales solo pueden ver sus propios datos.
- Los administradores pueden:
  - buscar cualquier usuario
  - ver sanciones
  - gestionar bans
  - ver intentos de acceso
- Considerar un rol opcional future-proof:
  - moderator
- El diseño debe dejar espacio para permisos más finos más adelante.

#### 13. Seguridad

- Toda acción administrativa debe requerir sesión válida y rol admin.
- Validar entradas del buscador y formularios.
- No exponer queries sensibles en cliente.
- Registrar acciones administrativas importantes.
- No confiar en datos enviados por el frontend para determinar privilegios.

#### 14. UX y copy

- El copy debe ser claro y profesional.
- Soportar al menos español e inglés.
- En español, usar tono claro y consistente.
- Para usuarios sancionados, mostrar información útil sin lenguaje agresivo.
- Para administradores, priorizar claridad operativa.

#### 15. Entregables esperados

Quiero que generes:

- estructura completa de la app
- layout principal
- navegación
- home
- buscador universal
- vista de usuario sancionado
- dashboard admin
- tablas de access, comm y spray
- sección de intentos de acceso
- formularios de crear, editar y remover bans
- arquitectura sugerida
- modelo de datos esperado en frontend
- componentes reutilizables clave
- propuesta visual coherente

Además, si falta algo importante para que la plataforma sea realmente útil para administración de bans, proponlo e intégralo al diseño.

### Bloque extra recomendado

No quiero una demo superficial. Quiero una propuesta de producto real para operar BanSystem. Prioriza:

- flujo de trabajo administrativo
- búsqueda rápida
- claridad del estado activo o expirado
- trazabilidad
- filtros potentes
- diseño serio y moderno
- buena experiencia para usuarios sancionados y administradores

Evita:

- páginas de relleno
- componentes genéricos sin propósito
- dashboards vacíos
- tablas sin filtros
- formularios sin validación
- autenticación ficticia

## Ideas Complementarias Para BanSystem

### 1. Historial de cambios administrativos

- Un audit log web visible:
  - quién creó
  - quién modificó
  - quién removió
  - valores anteriores y nuevos

### 2. Vista consolidada por usuario

- Una ficha única del jugador con:
  - identidad
  - bans activos
  - historial
  - intentos de acceso
  - notas administrativas futuras

### 3. Timeline del usuario

- Una cronología con eventos como:
  - access ban creado
  - comm ban actualizado
  - spray unban
  - intento de acceso bloqueado

### 4. Panel de sanciones activas globales

- Totales de:
  - access activos
  - comm activos
  - spray activos
  - permanentes
  - expiraciones próximas

### 5. Filtros por vencimiento próximo

- Bans que vencen hoy
- Bans que vencen esta semana
- Bans permanentes

### 6. Vista de identidad normalizada

- Mostrar todas las formas del ID:
  - SteamID64
  - SteamID2
  - SteamID3
  - accountid

### 7. Buscador con autoconversión visible

- Mostrar:
  - entrada detectada
  - formato detectado
  - formato normalizado

### 8. Acciones rápidas desde tablas

- Desde una fila:
  - editar
  - renovar
  - convertir a permanente
  - remover
  - abrir ficha del usuario

### 9. Indicador de reincidencia

- Señales administrativas como:
  - cantidad histórica de bans
  - cantidad de intentos de acceso
  - última actividad

### 10. Exportación

- Exportar resultados filtrados a CSV:
  - bans activos
  - historial
  - intentos de acceso

### 11. Notas internas para admins

- Campo de observaciones internas por usuario o por sanción.

### 12. Enlaces directos a Discord

- Desde la ficha del sancionado:
  - copiar SteamID
  - abrir enlace de apelación o soporte

### 13. Diferenciar desbanear y eliminar

- No tratar como lo mismo:
  - desbanear
  - eliminar registro

### 14. Modo solo lectura para ciertos admins

- Rol futuro para consulta sin permisos de modificación.

## Recomendación Final

No pedir simplemente una web para bans. Pedir una plataforma administrativa de sanciones con:

- portal de usuario
- autenticación Steam
- búsqueda universal de SteamID
- gestión operativa real
- lectura directa de BanSystem como fuente de verdad
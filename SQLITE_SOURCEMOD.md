# SQLite en SourceMod

Este documento deja un marco de trabajo práctico para usar SQLite desde SourceMod dentro de BanSystem.

## Objetivo

Usar SQLite como caché local simple, estable y fácil de depurar.

No usar SQLite como una segunda base principal ni como una capa con lógica compleja.

## Modelo recomendado

- MySQL es la fuente de verdad.
- SQLite es caché local del servidor.
- El plugin debe asumir que SQLite en SourceMod se consume a través de DBI, no como acceso completo a toda la API moderna de SQLite.

## Qué sí usar

Estas operaciones son adecuadas para BanSystem:

- `CREATE TABLE`
- `CREATE VIEW`
- `CREATE TRIGGER`
- `DROP ... IF EXISTS`
- `INSERT`
- `DELETE`
- `SELECT`
- `PRAGMA table_info(...)`
- consultas a `sqlite_master`
- `strftime('%s', 'now')`

Esto cubre bien el caso de uso actual:

- tabla `BanCache`
- trigger para reemplazar por `account_id`
- vista `BanCache_Valid`
- validación simple de esquema

## Qué evitar

No conviene depender de estas capacidades salvo que se validen explícitamente en runtime para la build concreta de SourceMod:

- `RETURNING`
- generated columns
- window functions
- CTEs complejas o recursivas
- JSON1
- extensiones cargables
- pragmas avanzados de tuning
- features nuevas introducidas en versiones recientes de SQLite

La razón no es que necesariamente no existan, sino que BanSystem no debe depender de una versión exacta del runtime SQLite del servidor.

## Reglas de implementación

- Mantener el esquema SQLite mínimo.
- Mantener nombres de objetos explícitos y alineados con el modelo actual.
- Preferir `account_id` como llave lógica.
- No usar `steamid64` ni `steamid2` como llave de caché.
- No mezclar demasiada lógica de negocio dentro de SQLite.
- Si algo requiere lógica compleja o consistencia fuerte, resolverlo en MySQL.

## Reglas de validación

El plugin debe validar solo lo que realmente necesita:

- existencia de la tabla `BanCache`
- existencia de la columna `account_id`
- existencia del trigger `DeleteOldCacheForAccountID`
- existencia de la vista `BanCache_Valid`

No conviene hacer introspección más profunda si no aporta valor operativo.

## Reglas de operación

- El archivo SQLite puede existir aunque el esquema no esté instalado.
- Tener conexión SQLite abierta no significa que la caché esté lista.
- La caché solo debe considerarse usable si:
  - `sm_bansystem_sqlitecache = 1`
  - el handle SQLite existe
  - el esquema fue validado correctamente

## Instalación en BanSystem

La instalación de SQLite se maneja desde el complemento:

- `sm_bs_cache_install`
- `sm_bs_cache_reinstall`

El arranque normal del plugin no debe reinstalar automáticamente la caché.

## Depuración recomendada

Para depurar SQLite en este proyecto:

- verificar si el handle está conectado
- verificar si el esquema está validado
- listar `BanCache_Valid`
- consultar por `account_id`
- revisar logs de validación del plugin

Los comandos del harness sirven como apoyo:

- `sm_bs_test_sqlite_status`
- `sm_bs_test_sqlite_ls`
- `sm_bs_test_sqlite_a`
- `sm_bs_test_sqlite_b`
- `sm_bs_test_perm_comm`
- `sm_bs_test_perm_access`

## Concurrencia y threading

SQLite en SourceMod entra por DBI. Si se mezclan operaciones threaded y no threaded sobre la misma conexión, hay que respetar las reglas de locking de SourceMod.

Para BanSystem, la recomendación es:

- mantener queries simples
- minimizar operaciones síncronas
- no introducir flujos complejos de locking salvo necesidad real

## Decisión de diseño para BanSystem

BanSystem debe tratar SQLite como:

- caché auxiliar
- esquema pequeño
- SQL conservador
- validación explícita
- recuperación manual mediante comandos admin

No debe tratarlo como una base secundaria rica en features.

## Fuentes

- AlliedModders Wiki, SQL (SourceMod Scripting): https://wiki.alliedmods.net/SQL_%28SourceMod_Scripting%29
- SQLite Documentation: https://sqlite.org/docs.html

## Nota

No se fija aquí una versión exacta de SQLite para SourceMod porque la documentación oficial consultada describe el driver y el marco DBI, pero no asegura una versión numérica concreta para cada build. Por eso este documento define un subconjunto seguro de uso en vez de depender de features por versión.

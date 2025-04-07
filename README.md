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

4. **Configurar la base de datos**:
   - Edita el archivo `addons/sourcemod/configs/databases.cfg` para añadir la configuración de la base de datos MySQL.
   - Si deseas habilitar el caché SQLite, asegúrate de que esté configurado correctamente.

5. **Reiniciar el servidor**:
   - Reinicia tu servidor para cargar el plugin.

## Comandos

- `sm_ban <usuario> <tiempo> [razón]`: Prohibir el acceso de un jugador.
- `sm_unban <steamid>`: Levantar una prohibición de acceso.
- `sm_comm <mic|chat|all> <usuario> <tiempo> [razón]`: Prohibir la comunicación de un jugador.
- `sm_uncomm <usuario>`: Levantar una prohibición de comunicación.
- `sm_abort`: Cancelar una prohibición en proceso.

## Configuración

- **Razones de prohibición**:
  - Edita el archivo `configs/bansystem_reasons.txt` para añadir o modificar razones de prohibición.

- **Variables de consola**:
  - `sm_bansystem_sqlitecache`: Habilita o deshabilita el caché SQLite (1 = habilitado, 0 = deshabilitado).
  - `sm_bansystem_localcache`: Habilita o deshabilita el caché local (1 = habilitado, 0 = deshabilitado).

## Contribuciones

¡Las contribuciones son bienvenidas! Si encuentras un error o tienes una idea para mejorar el plugin, abre un issue o envía un pull request.

## Licencia

Este proyecto está licenciado bajo la [MIT License](https://opensource.org/licenses/MIT).

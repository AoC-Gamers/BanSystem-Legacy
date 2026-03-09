# ScriptsSQL

`mysql/001_schema.sql` is the canonical MySQL schema for the plugin.

- Apply it before loading the plugin.
- The plugin validates `bansystem_schema_version` on startup.
- The current required MySQL schema version is `1`.

`sqlite/cache.sql` mirrors the local cache schema used by the plugin.

- SQLite cache remains managed locally by the plugin.
- The file is provided as a reference for inspection and maintenance.

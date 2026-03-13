# ScriptsSQL

`mysql/schema.sql` is the canonical MySQL schema for the plugin.

- Import `mysql/schema.sql` before loading the plugin.
- The plugin validates `bansystem_schema_version` on startup.
- The current required MySQL schema version is `6`.

Example install flow:

```bash
mysql new_db < ScriptsSQL/mysql/schema.sql
```

SQLite cache is managed locally by the plugin.

- BanSystem repairs/recreates the local cache objects at runtime.
- There is no external SQLite install script to apply.

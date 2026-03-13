# ScriptsSQL

Current SQL layout:

- `mysql/legacy/old_bansystem_schema.sql`
  - legacy monolithic schema used by the current `bansystem` plugin
- `mysql/core_schema.sql`
  - new modular core schema
- `mysql/access_schema.sql`
  - access module schema
- `mysql/communication_schema.sql`
  - communication module schema
- `mysql/sprays_schema.sql`
  - sprays module schema
- `mysql/adminsync_schema.sql`
  - admin sync satellite schema

Recommended install order for the new modular design:

```bash
mysql new_db < ScriptsSQL/mysql/core_schema.sql
mysql new_db < ScriptsSQL/mysql/access_schema.sql
mysql new_db < ScriptsSQL/mysql/communication_schema.sql
mysql new_db < ScriptsSQL/mysql/sprays_schema.sql
```

Use only the module schemas that you actually deploy.

SQLite cache is managed locally by the plugin.

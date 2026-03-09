# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and the project version follows Semantic Versioning from `1.0.0` onward.

## [Unreleased]

## [1.0.0] - 2026-03-09

### Added

- External SQL layout under `ScriptsSQL/mysql/` and `ScriptsSQL/sqlite/`.
- Startup validation for the MySQL schema version through `bansystem_schema_version`.
- Operational documentation for external MySQL deployment and local SQLite cache handling.

### Changed

- MySQL schema installation is now managed outside SourceMod.
- `install.sp` is now focused on SQLite cache repair and shared schema constants.
- The repository now treats this state as the stable `1.0.0` baseline before structural refactors.

### Fixed

- SQLite cache objects now match the queries used by the plugin.
- Communication unban flow and forwards now preserve the ban type correctly.
- Access and communication unban paths now clear stale SQLite cache entries.
- Authorization flow no longer promotes users to the local clean cache before MySQL validation.
- Duration menus now preserve the configured minute values.
- SQL writes now escape the values used in ban registration queries.

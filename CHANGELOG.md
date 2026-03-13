# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and the project version follows Semantic Versioning from `1.0.0` onward.

## [Unreleased]

### Changed

- Local clean cache now stores `account_id` instead of SteamID strings.
- SQLite cache now keys entries by `account_id`.
- MySQL lookups, access bans, communication bans and access-attempt logging now use `account_id` as the internal key.
- The canonical MySQL schema now persists `steamid64` as a complementary column for web-facing consumers while the plugin keeps `account_id` as the internal key.
- Admin commands that receive Steam identities now normalize SteamID2/3 offline and can resolve SteamID64 online through `SteamIDTools`.
- The canonical MySQL schema now uses `accountid` as the persisted numeric key, drops stored SteamID2, stores `banned_by_name` and `banned_by_steamid64`, and adds optional `ban_context`.

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

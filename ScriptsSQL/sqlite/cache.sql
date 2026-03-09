CREATE TABLE IF NOT EXISTS `BanCache` (
    `ban_id` INT NOT NULL DEFAULT 0,
    `steam_id` VARCHAR(64) NOT NULL,
    `date_cache` INTEGER DEFAULT (strftime('%s', 'now'))
);

DROP TRIGGER IF EXISTS `DeleteOldCacheForSteamID`;
CREATE TRIGGER `DeleteOldCacheForSteamID`
BEFORE INSERT ON `BanCache`
BEGIN
    DELETE FROM `BanCache`
    WHERE `steam_id` = NEW.steam_id;
END;

DROP VIEW IF EXISTS `BanCache_Valid`;
CREATE VIEW IF NOT EXISTS `BanCache_Valid` AS
SELECT `ban_id`, `steam_id`, `date_cache`
FROM `BanCache`
WHERE `date_cache` >= strftime('%s', 'now') - 604800;

DELIMITER $$

CREATE TABLE IF NOT EXISTS `bansystem_schema_meta` (
    `component` varchar(64) NOT NULL,
    `version_num` int NOT NULL,
    `installed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`component`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 $$

CREATE TABLE IF NOT EXISTS `bansystem_spray_bans` (
    `id` int NOT NULL AUTO_INCREMENT,
    `accountid` int NOT NULL,
    `steamid64` char(17) NOT NULL DEFAULT '',
    `player_name` varchar(128) NOT NULL DEFAULT 'UNKNOWN',
    `ip_address` varchar(64) NOT NULL DEFAULT '0.0.0.0',
    `ban_length` int NOT NULL DEFAULT 0,
    `ban_reason` varchar(250) NOT NULL DEFAULT 'NOREASON',
    `ban_context` varchar(512) NOT NULL DEFAULT '',
    `banned_by` int NOT NULL DEFAULT 0,
    `banned_by_name` varchar(128) NOT NULL DEFAULT 'Console',
    `banned_by_steamid64` char(17) NOT NULL DEFAULT '',
    `date_expire` DATETIME DEFAULT NULL,
    `date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_bansystem_spray_bans_accountid` (`accountid`),
    KEY `idx_bansystem_spray_bans_steamid64` (`steamid64`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 $$

DROP TRIGGER IF EXISTS `trg_bansystem_spray_bans_before_insert` $$
CREATE TRIGGER `trg_bansystem_spray_bans_before_insert`
BEFORE INSERT ON `bansystem_spray_bans`
FOR EACH ROW
BEGIN
    IF NEW.ban_length > 0 THEN
        SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00');
    ELSE
        SET NEW.date_expire = NULL;
    END IF;
END $$

DROP TRIGGER IF EXISTS `trg_bansystem_spray_bans_before_update` $$
CREATE TRIGGER `trg_bansystem_spray_bans_before_update`
BEFORE UPDATE ON `bansystem_spray_bans`
FOR EACH ROW
BEGIN
    IF NEW.ban_length > 0 THEN
        SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00');
    ELSE
        SET NEW.date_expire = NULL;
    END IF;
END $$

DROP VIEW IF EXISTS `view_bansystem_spray_bans_active` $$
CREATE VIEW `view_bansystem_spray_bans_active` AS
SELECT
    `id`,
    `accountid`,
    `steamid64`,
    `player_name`,
    `ip_address`,
    `ban_length`,
    `ban_reason`,
    `ban_context`,
    `banned_by`,
    `banned_by_name`,
    `banned_by_steamid64`,
    `date_expire`,
    `date_reg`,
    IFNULL(UNIX_TIMESTAMP(`date_expire`), 0) AS `date_expire_ts`
FROM `bansystem_spray_bans`
WHERE (`ban_length` = 0 OR `date_expire` IS NULL OR `date_expire` > UTC_TIMESTAMP()) $$

DROP PROCEDURE IF EXISTS `bansystem_spray_ban_save` $$
CREATE PROCEDURE `bansystem_spray_ban_save`(
    IN inAccountId INT,
    IN inSteamId64 VARCHAR(20),
    IN inPlayerName VARCHAR(128),
    IN inIpAddress VARCHAR(64),
    IN inBanLength INT,
    IN inBanReason VARCHAR(250),
    IN inBanContext VARCHAR(512),
    IN inBannedBy INT,
    IN inBannedByName VARCHAR(128),
    IN inBannedBySteamId64 VARCHAR(20)
)
BEGIN
    INSERT INTO `bansystem_spray_bans` (
        `accountid`, `steamid64`, `player_name`, `ip_address`, `ban_length`, `ban_reason`, `ban_context`, `banned_by`, `banned_by_name`, `banned_by_steamid64`
    ) VALUES (
        inAccountId, inSteamId64, inPlayerName, inIpAddress, inBanLength, inBanReason, inBanContext, inBannedBy, inBannedByName, inBannedBySteamId64
    )
    ON DUPLICATE KEY UPDATE
        `steamid64` = VALUES(`steamid64`),
        `player_name` = VALUES(`player_name`),
        `ip_address` = VALUES(`ip_address`),
        `ban_length` = VALUES(`ban_length`),
        `ban_reason` = VALUES(`ban_reason`),
        `ban_context` = VALUES(`ban_context`),
        `banned_by` = VALUES(`banned_by`),
        `banned_by_name` = VALUES(`banned_by_name`),
        `banned_by_steamid64` = VALUES(`banned_by_steamid64`);

    CALL `bansystem_rebuild_summary_account`(inAccountId);

    SELECT `id`
    FROM `view_bansystem_spray_bans_active`
    WHERE `accountid` = inAccountId
    LIMIT 1;
END $$

DROP PROCEDURE IF EXISTS `bansystem_spray_ban_delete` $$
CREATE PROCEDURE `bansystem_spray_ban_delete`(
    IN inAccountId INT
)
BEGIN
    DELETE FROM `bansystem_spray_bans`
    WHERE `accountid` = inAccountId;

    CALL `bansystem_rebuild_summary_account`(inAccountId);
END $$

DROP PROCEDURE IF EXISTS `bansystem_spray_get_active_by_accountid` $$
CREATE PROCEDURE `bansystem_spray_get_active_by_accountid`(
    IN inAccountId INT
)
BEGIN
    SELECT
        `id`,
        `accountid`,
        `steamid64`,
        `player_name`,
        `ban_length`,
        `ban_reason`,
        `ban_context`,
        `banned_by`,
        `banned_by_name`,
        `banned_by_steamid64`,
                `date_expire_ts`
        FROM `view_bansystem_spray_bans_active`
    WHERE `accountid` = inAccountId
    LIMIT 1;
END $$

DROP PROCEDURE IF EXISTS `bansystem_spray_get_active_by_banid` $$
CREATE PROCEDURE `bansystem_spray_get_active_by_banid`(
    IN inBanId INT
)
BEGIN
    SELECT
        `id`,
        `accountid`,
        `steamid64`,
        `player_name`,
        `ban_length`,
        `ban_reason`,
        `ban_context`,
        `banned_by`,
        `banned_by_name`,
        `banned_by_steamid64`,
                `date_expire_ts`
        FROM `view_bansystem_spray_bans_active`
    WHERE `id` = inBanId
    LIMIT 1;
END $$

INSERT INTO `bansystem_schema_meta` (`component`, `version_num`)
VALUES ('sprays', 1)
ON DUPLICATE KEY UPDATE `version_num` = VALUES(`version_num`) $$

DELIMITER ;

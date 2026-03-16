DELIMITER $$

CREATE TABLE IF NOT EXISTS `bansystem_schema_meta` (
    `component` varchar(64) NOT NULL,
    `version_num` int NOT NULL,
    `installed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`component`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 $$

CREATE TABLE IF NOT EXISTS `bansystem_access_bans` (
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
    UNIQUE KEY `uq_bansystem_access_bans_accountid` (`accountid`),
    KEY `idx_bansystem_access_bans_steamid64` (`steamid64`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 $$

CREATE TABLE IF NOT EXISTS `bansystem_access_attempts` (
    `id` int NOT NULL AUTO_INCREMENT,
    `accountid` int NOT NULL,
    `steamid64` char(17) NOT NULL DEFAULT '',
    `player_name` varchar(128) NOT NULL DEFAULT 'UNKNOWN',
    `ip_address` varchar(64) NOT NULL DEFAULT '0.0.0.0',
    `date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_bansystem_access_attempts_accountid` (`accountid`),
    KEY `idx_bansystem_access_attempts_steamid64` (`steamid64`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 $$

DROP TRIGGER IF EXISTS `trg_bansystem_access_bans_before_insert` $$
CREATE TRIGGER `trg_bansystem_access_bans_before_insert`
BEFORE INSERT ON `bansystem_access_bans`
FOR EACH ROW
BEGIN
    IF NEW.ban_length > 0 THEN
        SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00');
    ELSE
        SET NEW.date_expire = NULL;
    END IF;
END $$

DROP TRIGGER IF EXISTS `trg_bansystem_access_bans_before_update` $$
CREATE TRIGGER `trg_bansystem_access_bans_before_update`
BEFORE UPDATE ON `bansystem_access_bans`
FOR EACH ROW
BEGIN
    IF NEW.ban_length > 0 THEN
        SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00');
    ELSE
        SET NEW.date_expire = NULL;
    END IF;
END $$

DROP PROCEDURE IF EXISTS `bansystem_access_attempt_record` $$
CREATE PROCEDURE `bansystem_access_attempt_record`(
    IN inAccountId INT,
    IN inSteamId64 VARCHAR(20),
    IN inPlayerName VARCHAR(128),
    IN inIpAddress VARCHAR(64)
)
BEGIN
    INSERT INTO `bansystem_access_attempts` (`accountid`, `steamid64`, `player_name`, `ip_address`)
    VALUES (inAccountId, inSteamId64, inPlayerName, inIpAddress);

    UPDATE `bansystem_access_bans`
    SET `steamid64` = inSteamId64, `player_name` = inPlayerName, `ip_address` = inIpAddress
    WHERE `accountid` = inAccountId;
END $$

INSERT INTO `bansystem_schema_meta` (`component`, `version_num`)
VALUES ('access', 1)
ON DUPLICATE KEY UPDATE `version_num` = VALUES(`version_num`) $$

DELIMITER ;

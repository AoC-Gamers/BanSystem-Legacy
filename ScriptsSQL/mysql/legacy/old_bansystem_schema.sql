DELIMITER $$

CREATE TABLE IF NOT EXISTS `bans_access` (
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
    UNIQUE KEY `uq_bans_access_accountid` (`accountid`),
    KEY `idx_bans_access_steamid64` (`steamid64`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 $$

CREATE TABLE IF NOT EXISTS `bans_communication` (
    `id` int NOT NULL AUTO_INCREMENT,
    `accountid` int NOT NULL,
    `steamid64` char(17) NOT NULL DEFAULT '',
    `player_name` varchar(128) NOT NULL DEFAULT 'UNKNOWN',
    `ip_address` varchar(64) NOT NULL DEFAULT '0.0.0.0',
    `ban_type` int NOT NULL DEFAULT 3,
    `ban_length` int NOT NULL DEFAULT 0,
    `ban_reason` varchar(250) NOT NULL DEFAULT 'NOREASON',
    `ban_context` varchar(512) NOT NULL DEFAULT '',
    `banned_by` int NOT NULL DEFAULT 0,
    `banned_by_name` varchar(128) NOT NULL DEFAULT 'Console',
    `banned_by_steamid64` char(17) NOT NULL DEFAULT '',
    `date_expire` DATETIME DEFAULT NULL,
    `date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_bans_communication_accountid` (`accountid`),
    KEY `idx_bans_communication_steamid64` (`steamid64`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 $$

CREATE TABLE IF NOT EXISTS `attempts_access` (
    `id` int NOT NULL AUTO_INCREMENT,
    `accountid` int NOT NULL,
    `steamid64` char(17) NOT NULL DEFAULT '',
    `player_name` varchar(128) NOT NULL DEFAULT 'UNKNOWN',
    `ip_address` varchar(64) NOT NULL DEFAULT '0.0.0.0',
    `date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_attempts_access_accountid` (`accountid`),
    KEY `idx_attempts_access_steamid64` (`steamid64`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 $$

CREATE TABLE IF NOT EXISTS `bansystem_schema_version` (
    `version_num` int NOT NULL,
    `applied_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`version_num`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 $$

DROP TRIGGER IF EXISTS `trg_bans_access_before_insert` $$
CREATE TRIGGER `trg_bans_access_before_insert`
BEFORE INSERT ON `bans_access`
FOR EACH ROW
BEGIN
    IF NEW.ban_length > 0 THEN
        SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00');
    ELSE
        SET NEW.date_expire = NULL;
    END IF;
END $$

DROP TRIGGER IF EXISTS `trg_bans_access_before_update` $$
CREATE TRIGGER `trg_bans_access_before_update`
BEFORE UPDATE ON `bans_access`
FOR EACH ROW
BEGIN
    IF NEW.ban_length > 0 THEN
        SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00');
    ELSE
        SET NEW.date_expire = NULL;
    END IF;
END $$

DROP TRIGGER IF EXISTS `trg_bans_communication_before_insert` $$
CREATE TRIGGER `trg_bans_communication_before_insert`
BEFORE INSERT ON `bans_communication`
FOR EACH ROW
BEGIN
    IF NEW.ban_length > 0 THEN
        SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00');
    ELSE
        SET NEW.date_expire = NULL;
    END IF;
END $$

DROP TRIGGER IF EXISTS `trg_bans_communication_before_update` $$
CREATE TRIGGER `trg_bans_communication_before_update`
BEFORE UPDATE ON `bans_communication`
FOR EACH ROW
BEGIN
    IF NEW.ban_length > 0 THEN
        SET NEW.date_expire = CONVERT_TZ(DATE_ADD(NOW(), INTERVAL NEW.ban_length MINUTE), @@session.time_zone, '+00:00');
    ELSE
        SET NEW.date_expire = NULL;
    END IF;
END $$

DROP PROCEDURE IF EXISTS `CheckAuthId` $$
CREATE PROCEDURE `CheckAuthId`(
    IN inAccountId INT,
    OUT result INT,
    OUT out_expire VARCHAR(64)
)
BEGIN
    DECLARE vBanLength INT;
    DECLARE vExpire DATETIME;
    DECLARE vBanType INT;
    DECLARE vNow DATETIME;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        SET result = -127;
        SET out_expire = NULL;
    END;

    SET vNow = UTC_TIMESTAMP();

    IF EXISTS (SELECT 1 FROM `bans_access` WHERE `accountid` = inAccountId) THEN
        SELECT `ban_length`, `date_expire`
        INTO vBanLength, vExpire
        FROM `bans_access`
        WHERE `accountid` = inAccountId;

        IF vBanLength = 0 THEN
            SET result = -1;
            SET out_expire = NULL;
        ELSEIF vExpire <= vNow THEN
            DELETE FROM `bans_access` WHERE `accountid` = inAccountId;
            SET result = 0;
            SET out_expire = NULL;
        ELSE
            SET result = 1;
            SET out_expire = DATE_FORMAT(vExpire, '%Y-%m-%d %H:%i:%s');
        END IF;
    ELSEIF EXISTS (SELECT 1 FROM `bans_communication` WHERE `accountid` = inAccountId) THEN
        SELECT `ban_type`, `ban_length`, `date_expire`
        INTO vBanType, vBanLength, vExpire
        FROM `bans_communication`
        WHERE `accountid` = inAccountId;

        IF vBanLength = 0 THEN
            SET result = (vBanType + 1) * -1;
            SET out_expire = NULL;
        ELSEIF vExpire <= vNow THEN
            DELETE FROM `bans_communication` WHERE `accountid` = inAccountId;
            SET result = 0;
            SET out_expire = NULL;
        ELSE
            SET result = (vBanType + 1);
            SET out_expire = DATE_FORMAT(vExpire, '%Y-%m-%d %H:%i:%s');
        END IF;
    ELSE
        SET result = 0;
        SET out_expire = NULL;
    END IF;
END $$

DROP PROCEDURE IF EXISTS `GetCheckAuthId` $$
CREATE PROCEDURE `GetCheckAuthId`(
    IN inAccountId INT
)
BEGIN
    DECLARE Result INT;
    DECLARE ExpireRes VARCHAR(64);

    CALL CheckAuthId(inAccountId, Result, ExpireRes);
    SELECT Result AS result, ExpireRes AS expire;
END $$

DROP PROCEDURE IF EXISTS `AttemptAccess` $$
CREATE PROCEDURE `AttemptAccess`(
    IN inAccountId INT,
    IN inSteamId64 VARCHAR(20),
    IN inPlayerName VARCHAR(64),
    IN inIpAddress VARCHAR(64)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    INSERT INTO `attempts_access` (`accountid`, `steamid64`, `player_name`, `ip_address`)
    VALUES (inAccountId, inSteamId64, inPlayerName, inIpAddress);

    UPDATE `bans_access`
    SET `steamid64` = inSteamId64, `player_name` = inPlayerName, `ip_address` = inIpAddress
    WHERE `accountid` = inAccountId;

    UPDATE `bans_communication`
    SET `steamid64` = inSteamId64, `player_name` = inPlayerName, `ip_address` = inIpAddress
    WHERE `accountid` = inAccountId;

    COMMIT;
END $$

INSERT IGNORE INTO `bansystem_schema_version` (`version_num`) VALUES (6) $$

DELIMITER ;

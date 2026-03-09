DELIMITER $$

CREATE TABLE IF NOT EXISTS `bans_access` (
    `id` int NOT NULL AUTO_INCREMENT,
    `steam_id` varchar(64) NOT NULL,
    `player_name` varchar(128) NOT NULL DEFAULT 'UNKNOWN',
    `ip_address` varchar(64) NOT NULL DEFAULT '0.0.0.0',
    `ban_length` int NOT NULL DEFAULT 0,
    `ban_reason` varchar(250) NOT NULL DEFAULT 'NOREASON',
    `banned_by` varchar(128) NOT NULL DEFAULT 'CONSOLE',
    `date_expire` DATETIME DEFAULT NULL,
    `date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY (`steam_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 $$

CREATE TABLE IF NOT EXISTS `bans_communication` (
    `id` int NOT NULL AUTO_INCREMENT,
    `steam_id` varchar(64) NOT NULL,
    `player_name` varchar(128) NOT NULL DEFAULT 'UNKNOWN',
    `ip_address` varchar(64) NOT NULL DEFAULT '0.0.0.0',
    `ban_type` int NOT NULL DEFAULT 3,
    `ban_length` int NOT NULL DEFAULT 0,
    `ban_reason` varchar(250) NOT NULL DEFAULT 'NOREASON',
    `banned_by` varchar(128) NOT NULL DEFAULT 'CONSOLE',
    `date_expire` DATETIME DEFAULT NULL,
    `date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY (`steam_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 AUTO_INCREMENT=1 $$

CREATE TABLE IF NOT EXISTS `attempts_access` (
    `id` int NOT NULL AUTO_INCREMENT,
    `steam_id` varchar(64) NOT NULL,
    `player_name` varchar(128) NOT NULL DEFAULT 'UNKNOWN',
    `ip_address` varchar(64) NOT NULL DEFAULT '0.0.0.0',
    `date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
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
    IN szAuthId VARCHAR(64),
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
        SET result = 0;
        SET out_expire = NULL;
    END;

    SET vNow = UTC_TIMESTAMP();

    IF EXISTS (SELECT 1 FROM `bans_access` WHERE `steam_id` = szAuthId) THEN
        SELECT `ban_length`, `date_expire` INTO vBanLength, vExpire
        FROM `bans_access` WHERE `steam_id` = szAuthId;

        IF vBanLength = 0 THEN
            SET result = -1;
            SET out_expire = NULL;
        ELSEIF vExpire <= vNow THEN
            DELETE FROM `bans_access` WHERE `steam_id` = szAuthId;
            SET result = 0;
            SET out_expire = NULL;
        ELSE
            SET result = 1;
            SET out_expire = DATE_FORMAT(vExpire, '%Y-%m-%d %H:%i:%s');
        END IF;
    ELSEIF EXISTS (SELECT 1 FROM `bans_communication` WHERE `steam_id` = szAuthId) THEN
        SELECT `ban_type`, `ban_length`, `date_expire` INTO vBanType, vBanLength, vExpire
        FROM `bans_communication` WHERE `steam_id` = szAuthId;

        IF vBanLength = 0 THEN
            SET result = (vBanType + 1) * -1;
            SET out_expire = NULL;
        ELSEIF vExpire <= vNow THEN
            DELETE FROM `bans_communication` WHERE `steam_id` = szAuthId;
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
    IN szAuthId VARCHAR(64)
)
BEGIN
    DECLARE Result INT;
    DECLARE ExpireRes VARCHAR(64);

    CALL CheckAuthId(szAuthId, Result, ExpireRes);
    SELECT Result AS result, ExpireRes AS expire;
END $$

DROP PROCEDURE IF EXISTS `AttemptAccess` $$
CREATE PROCEDURE `AttemptAccess`(
    IN szSteamId VARCHAR(64),
    IN szPlayerName VARCHAR(64),
    IN szIpAddress VARCHAR(64)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
    END;

    START TRANSACTION;

    INSERT INTO `attempts_access` (`steam_id`, `player_name`, `ip_address`)
    VALUES (szSteamId, szPlayerName, szIpAddress);

    UPDATE `bans_access`
    SET `player_name` = szPlayerName, `ip_address` = szIpAddress
    WHERE `steam_id` = szSteamId;

    COMMIT;
END $$

INSERT IGNORE INTO `bansystem_schema_version` (`version_num`) VALUES (1) $$

DELIMITER ;

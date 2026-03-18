DELIMITER $$

CREATE TABLE IF NOT EXISTS `bansystem_schema_meta` (
    `component` varchar(64) NOT NULL,
    `version_num` int NOT NULL,
    `installed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`component`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 $$

DROP VIEW IF EXISTS `view_bansystem_active_summary` $$
DROP VIEW IF EXISTS `view_bansystem_auth_summary` $$
DROP TRIGGER IF EXISTS `trg_bansystem_summary_before_insert` $$
DROP TRIGGER IF EXISTS `trg_bansystem_summary_before_update` $$
DROP TABLE IF EXISTS `bansystem_summary` $$

CREATE TABLE `bansystem_summary` (
    `accountid` int NOT NULL,
    `module_mask` int NOT NULL DEFAULT 0,
    `access_ban_id` int NOT NULL DEFAULT 0,
    `comm_ban_id` int NOT NULL DEFAULT 0,
    `spray_ban_id` int NOT NULL DEFAULT 0,
    `comm_type` int NOT NULL DEFAULT 0,
    `comm_length` int NOT NULL DEFAULT 0,
    `comm_reason` varchar(250) NOT NULL DEFAULT '',
    `comm_context` varchar(512) NOT NULL DEFAULT '',
    `comm_banned_by_name` varchar(128) NOT NULL DEFAULT '',
    `comm_expire_ts` int NOT NULL DEFAULT 0,
    `spray_length` int NOT NULL DEFAULT 0,
    `spray_reason` varchar(250) NOT NULL DEFAULT '',
    `spray_context` varchar(512) NOT NULL DEFAULT '',
    `spray_banned_by_name` varchar(128) NOT NULL DEFAULT '',
    `spray_expire_ts` int NOT NULL DEFAULT 0,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`accountid`),
    KEY `idx_bansystem_summary_module_mask` (`module_mask`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 $$

CREATE VIEW `view_bansystem_auth_summary` AS
SELECT
    `accountid`,
    `module_mask`,
    `access_ban_id`,
    `comm_ban_id`,
    `spray_ban_id`,
    `comm_type`,
    `comm_length`,
    `comm_reason`,
    `comm_context`,
    `comm_banned_by_name`,
    `comm_expire_ts`,
    `spray_length`,
    `spray_reason`,
    `spray_context`,
    `spray_banned_by_name`,
    `spray_expire_ts`,
    `updated_at`
FROM `bansystem_summary`
WHERE `module_mask` <> 0 $$

-- Requires the active module views from access, communication, and sprays schemas
-- to be created before this migration is applied.
CREATE VIEW `view_bansystem_active_summary` AS
SELECT
    src.`accountid`,
    ((CASE WHEN access_ban.`id` IS NOT NULL THEN 1 ELSE 0 END)
        | (CASE WHEN comm_ban.`id` IS NOT NULL THEN 2 ELSE 0 END)
        | (CASE WHEN spray_ban.`id` IS NOT NULL THEN 4 ELSE 0 END)) AS `module_mask`,
    IFNULL(access_ban.`id`, 0) AS `access_ban_id`,
    IFNULL(comm_ban.`id`, 0) AS `comm_ban_id`,
    IFNULL(spray_ban.`id`, 0) AS `spray_ban_id`,
    IFNULL(comm_ban.`ban_type`, 0) AS `comm_type`,
    IFNULL(comm_ban.`ban_length`, 0) AS `comm_length`,
    IFNULL(comm_ban.`ban_reason`, '') AS `comm_reason`,
    IFNULL(comm_ban.`ban_context`, '') AS `comm_context`,
    IFNULL(comm_ban.`banned_by_name`, '') AS `comm_banned_by_name`,
    IFNULL(comm_ban.`date_expire_ts`, 0) AS `comm_expire_ts`,
    IFNULL(spray_ban.`ban_length`, 0) AS `spray_length`,
    IFNULL(spray_ban.`ban_reason`, '') AS `spray_reason`,
    IFNULL(spray_ban.`ban_context`, '') AS `spray_context`,
    IFNULL(spray_ban.`banned_by_name`, '') AS `spray_banned_by_name`,
    IFNULL(spray_ban.`date_expire_ts`, 0) AS `spray_expire_ts`
FROM (
    SELECT `accountid` FROM `view_bansystem_access_bans_active`
    UNION
    SELECT `accountid` FROM `view_bansystem_comm_bans_active`
    UNION
    SELECT `accountid` FROM `view_bansystem_spray_bans_active`
) AS src
LEFT JOIN `view_bansystem_access_bans_active` AS access_ban ON access_ban.`accountid` = src.`accountid`
LEFT JOIN `view_bansystem_comm_bans_active` AS comm_ban ON comm_ban.`accountid` = src.`accountid`
LEFT JOIN `view_bansystem_spray_bans_active` AS spray_ban ON spray_ban.`accountid` = src.`accountid` $$

DROP TRIGGER IF EXISTS `trg_bansystem_summary_before_insert` $$
CREATE TRIGGER `trg_bansystem_summary_before_insert`
BEFORE INSERT ON `bansystem_summary`
FOR EACH ROW
BEGIN
    IF (NEW.module_mask & 1) = 0 THEN
        SET NEW.access_ban_id = 0;
    END IF;

    IF (NEW.module_mask & 2) = 0 THEN
        SET NEW.comm_ban_id = 0;
        SET NEW.comm_type = 0;
        SET NEW.comm_length = 0;
        SET NEW.comm_reason = '';
        SET NEW.comm_context = '';
        SET NEW.comm_banned_by_name = '';
        SET NEW.comm_expire_ts = 0;
    END IF;

    IF (NEW.module_mask & 4) = 0 THEN
        SET NEW.spray_ban_id = 0;
        SET NEW.spray_length = 0;
        SET NEW.spray_reason = '';
        SET NEW.spray_context = '';
        SET NEW.spray_banned_by_name = '';
        SET NEW.spray_expire_ts = 0;
    END IF;
END $$

DROP TRIGGER IF EXISTS `trg_bansystem_summary_before_update` $$
CREATE TRIGGER `trg_bansystem_summary_before_update`
BEFORE UPDATE ON `bansystem_summary`
FOR EACH ROW
BEGIN
    IF (NEW.module_mask & 1) = 0 THEN
        SET NEW.access_ban_id = 0;
    END IF;

    IF (NEW.module_mask & 2) = 0 THEN
        SET NEW.comm_ban_id = 0;
        SET NEW.comm_type = 0;
        SET NEW.comm_length = 0;
        SET NEW.comm_reason = '';
        SET NEW.comm_context = '';
        SET NEW.comm_banned_by_name = '';
        SET NEW.comm_expire_ts = 0;
    END IF;

    IF (NEW.module_mask & 4) = 0 THEN
        SET NEW.spray_ban_id = 0;
        SET NEW.spray_length = 0;
        SET NEW.spray_reason = '';
        SET NEW.spray_context = '';
        SET NEW.spray_banned_by_name = '';
        SET NEW.spray_expire_ts = 0;
    END IF;
END $$

DROP PROCEDURE IF EXISTS `bansystem_rebuild_summary_account` $$
DROP PROCEDURE IF EXISTS `bansystem_rebuild_summary_all` $$
DROP PROCEDURE IF EXISTS `bansystem_get_auth_summary` $$

INSERT INTO `bansystem_schema_meta` (`component`, `version_num`)
VALUES ('core', 3)
ON DUPLICATE KEY UPDATE `version_num` = VALUES(`version_num`) $$

DELIMITER ;

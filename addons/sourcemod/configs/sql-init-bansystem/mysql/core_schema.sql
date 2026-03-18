DELIMITER $$

CREATE TABLE IF NOT EXISTS `bansystem_schema_meta` (
    `component` varchar(64) NOT NULL,
    `version_num` int NOT NULL,
    `installed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`component`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 $$

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
VALUES ('core', 2)
ON DUPLICATE KEY UPDATE `version_num` = VALUES(`version_num`) $$

DELIMITER ;

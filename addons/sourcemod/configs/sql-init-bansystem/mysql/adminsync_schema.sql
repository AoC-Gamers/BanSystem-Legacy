DELIMITER $$

CREATE TABLE IF NOT EXISTS `bansystem_schema_meta` (
    `component` varchar(64) NOT NULL,
    `version_num` int NOT NULL,
    `installed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`component`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 $$

CREATE TABLE IF NOT EXISTS `adminsync_admins` (
    `id` int NOT NULL AUTO_INCREMENT,
    `accountid` int NOT NULL,
    `steamid64` char(17) NOT NULL DEFAULT '',
    `name` varchar(128) NOT NULL DEFAULT 'UNKNOWN',
    `flags` varchar(64) NOT NULL DEFAULT '',
    `immunity` int NOT NULL DEFAULT 0,
    `enabled` tinyint(1) NOT NULL DEFAULT 1,
    `date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_adminsync_admins_accountid` (`accountid`),
    KEY `idx_adminsync_admins_enabled` (`enabled`),
    KEY `idx_adminsync_admins_steamid64` (`steamid64`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 $$

CREATE TABLE IF NOT EXISTS `adminsync_groups` (
    `id` int NOT NULL AUTO_INCREMENT,
    `name` varchar(128) NOT NULL,
    `flags` varchar(64) NOT NULL DEFAULT '',
    `immunity_level` int NOT NULL DEFAULT 0,
    `enabled` tinyint(1) NOT NULL DEFAULT 1,
    `date_reg` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_adminsync_groups_name` (`name`),
    KEY `idx_adminsync_groups_enabled` (`enabled`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 $$

CREATE TABLE IF NOT EXISTS `adminsync_admins_groups` (
    `admin_id` int NOT NULL,
    `group_id` int NOT NULL,
    `inherit_order` int NOT NULL DEFAULT 0,
    PRIMARY KEY (`admin_id`, `group_id`),
    KEY `idx_adminsync_admins_groups_group_id` (`group_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 $$

CREATE TABLE IF NOT EXISTS `adminsync_meta` (
    `meta_key` varchar(64) NOT NULL,
    `meta_value` bigint NOT NULL DEFAULT 0,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`meta_key`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 $$

INSERT INTO `adminsync_meta` (`meta_key`, `meta_value`)
VALUES ('snapshot_version', 1)
ON DUPLICATE KEY UPDATE `meta_value` = `meta_value` $$

DROP TRIGGER IF EXISTS `trg_adminsync_admins_after_insert` $$
CREATE TRIGGER `trg_adminsync_admins_after_insert`
AFTER INSERT ON `adminsync_admins`
FOR EACH ROW
BEGIN
    UPDATE `adminsync_meta`
    SET `meta_value` = `meta_value` + 1
    WHERE `meta_key` = 'snapshot_version';
END $$

DROP TRIGGER IF EXISTS `trg_adminsync_admins_after_update` $$
CREATE TRIGGER `trg_adminsync_admins_after_update`
AFTER UPDATE ON `adminsync_admins`
FOR EACH ROW
BEGIN
    UPDATE `adminsync_meta`
    SET `meta_value` = `meta_value` + 1
    WHERE `meta_key` = 'snapshot_version';
END $$

DROP TRIGGER IF EXISTS `trg_adminsync_admins_after_delete` $$
CREATE TRIGGER `trg_adminsync_admins_after_delete`
AFTER DELETE ON `adminsync_admins`
FOR EACH ROW
BEGIN
    UPDATE `adminsync_meta`
    SET `meta_value` = `meta_value` + 1
    WHERE `meta_key` = 'snapshot_version';
END $$

DROP TRIGGER IF EXISTS `trg_adminsync_groups_after_insert` $$
CREATE TRIGGER `trg_adminsync_groups_after_insert`
AFTER INSERT ON `adminsync_groups`
FOR EACH ROW
BEGIN
    UPDATE `adminsync_meta`
    SET `meta_value` = `meta_value` + 1
    WHERE `meta_key` = 'snapshot_version';
END $$

DROP TRIGGER IF EXISTS `trg_adminsync_groups_after_update` $$
CREATE TRIGGER `trg_adminsync_groups_after_update`
AFTER UPDATE ON `adminsync_groups`
FOR EACH ROW
BEGIN
    UPDATE `adminsync_meta`
    SET `meta_value` = `meta_value` + 1
    WHERE `meta_key` = 'snapshot_version';
END $$

DROP TRIGGER IF EXISTS `trg_adminsync_groups_after_delete` $$
CREATE TRIGGER `trg_adminsync_groups_after_delete`
AFTER DELETE ON `adminsync_groups`
FOR EACH ROW
BEGIN
    UPDATE `adminsync_meta`
    SET `meta_value` = `meta_value` + 1
    WHERE `meta_key` = 'snapshot_version';
END $$

DROP TRIGGER IF EXISTS `trg_adminsync_admins_groups_after_insert` $$
CREATE TRIGGER `trg_adminsync_admins_groups_after_insert`
AFTER INSERT ON `adminsync_admins_groups`
FOR EACH ROW
BEGIN
    UPDATE `adminsync_meta`
    SET `meta_value` = `meta_value` + 1
    WHERE `meta_key` = 'snapshot_version';
END $$

DROP TRIGGER IF EXISTS `trg_adminsync_admins_groups_after_update` $$
CREATE TRIGGER `trg_adminsync_admins_groups_after_update`
AFTER UPDATE ON `adminsync_admins_groups`
FOR EACH ROW
BEGIN
    UPDATE `adminsync_meta`
    SET `meta_value` = `meta_value` + 1
    WHERE `meta_key` = 'snapshot_version';
END $$

DROP TRIGGER IF EXISTS `trg_adminsync_admins_groups_after_delete` $$
CREATE TRIGGER `trg_adminsync_admins_groups_after_delete`
AFTER DELETE ON `adminsync_admins_groups`
FOR EACH ROW
BEGIN
    UPDATE `adminsync_meta`
    SET `meta_value` = `meta_value` + 1
    WHERE `meta_key` = 'snapshot_version';
END $$

INSERT INTO `bansystem_schema_meta` (`component`, `version_num`)
VALUES ('adminsync', 1)
ON DUPLICATE KEY UPDATE `version_num` = VALUES(`version_num`) $$

DELIMITER ;

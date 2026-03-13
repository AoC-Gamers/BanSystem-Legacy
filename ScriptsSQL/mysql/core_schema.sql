DELIMITER $$

CREATE TABLE IF NOT EXISTS `bansystem_core_schema_version` (
    `version_num` int NOT NULL,
    `applied_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`version_num`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 $$

CREATE TABLE IF NOT EXISTS `bansystem_summary` (
    `accountid` int NOT NULL,
    `module_mask` int NOT NULL DEFAULT 0,
    `access_ban_id` int NOT NULL DEFAULT 0,
    `comm_ban_id` int NOT NULL DEFAULT 0,
    `spray_ban_id` int NOT NULL DEFAULT 0,
    `comm_type` int NOT NULL DEFAULT 0,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`accountid`),
    KEY `idx_bansystem_summary_module_mask` (`module_mask`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 $$

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
    END IF;

    IF (NEW.module_mask & 4) = 0 THEN
        SET NEW.spray_ban_id = 0;
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
    END IF;

    IF (NEW.module_mask & 4) = 0 THEN
        SET NEW.spray_ban_id = 0;
    END IF;
END $$

DROP PROCEDURE IF EXISTS `bansystem_get_auth_summary` $$
CREATE PROCEDURE `bansystem_get_auth_summary`(
    IN inAccountId INT
)
BEGIN
    SELECT
        `module_mask`,
        `access_ban_id`,
        `comm_ban_id`,
        `spray_ban_id`,
        `comm_type`
    FROM `bansystem_summary`
    WHERE `accountid` = inAccountId
    LIMIT 1;
END $$

INSERT IGNORE INTO `bansystem_core_schema_version` (`version_num`) VALUES (1) $$

DELIMITER ;

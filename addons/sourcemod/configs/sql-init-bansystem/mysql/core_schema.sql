DELIMITER $$

CREATE TABLE IF NOT EXISTS `bansystem_schema_meta` (
    `component` varchar(64) NOT NULL,
    `version_num` int NOT NULL,
    `installed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`component`)
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

DROP PROCEDURE IF EXISTS `bansystem_rebuild_summary_account` $$
CREATE PROCEDURE `bansystem_rebuild_summary_account`(
    IN inAccountId INT
)
BEGIN
    DECLARE vModuleMask INT DEFAULT 0;
    DECLARE vAccessBanId INT DEFAULT 0;
    DECLARE vCommBanId INT DEFAULT 0;
    DECLARE vSprayBanId INT DEFAULT 0;
    DECLARE vCommType INT DEFAULT 0;

        SET vAccessBanId = IFNULL((
                SELECT `id`
                FROM `view_bansystem_access_bans_active`
                WHERE `accountid` = inAccountId
                LIMIT 1
        ), 0);

    SET vCommBanId = IFNULL((
        SELECT `id`
                FROM `view_bansystem_comm_bans_active`
                WHERE `accountid` = inAccountId
        LIMIT 1
    ), 0);

    SET vSprayBanId = IFNULL((
        SELECT `id`
                FROM `view_bansystem_spray_bans_active`
                WHERE `accountid` = inAccountId
        LIMIT 1
    ), 0);

    SET vCommType = IFNULL((
        SELECT `ban_type`
                FROM `view_bansystem_comm_bans_active`
                WHERE `accountid` = inAccountId
        LIMIT 1
    ), 0);

    IF vAccessBanId > 0 THEN
        SET vModuleMask = vModuleMask | 1;
    END IF;

    IF vCommBanId > 0 THEN
        SET vModuleMask = vModuleMask | 2;
    END IF;

    IF vSprayBanId > 0 THEN
        SET vModuleMask = vModuleMask | 4;
    END IF;

    IF vModuleMask = 0 THEN
        DELETE FROM `bansystem_summary` WHERE `accountid` = inAccountId;
    ELSE
        INSERT INTO `bansystem_summary` (`accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`)
        VALUES (inAccountId, vModuleMask, vAccessBanId, vCommBanId, vSprayBanId, vCommType)
        ON DUPLICATE KEY UPDATE
            `module_mask` = VALUES(`module_mask`),
            `access_ban_id` = VALUES(`access_ban_id`),
            `comm_ban_id` = VALUES(`comm_ban_id`),
            `spray_ban_id` = VALUES(`spray_ban_id`),
            `comm_type` = VALUES(`comm_type`);
    END IF;
END $$

DROP PROCEDURE IF EXISTS `bansystem_rebuild_summary_all` $$
CREATE PROCEDURE `bansystem_rebuild_summary_all`()
BEGIN
    DELETE FROM `bansystem_summary`;

    INSERT INTO `bansystem_summary` (`accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`)
    SELECT
        src.`accountid`,
        (CASE WHEN access_ban.`id` IS NOT NULL THEN 1 ELSE 0 END)
        | (CASE WHEN comm_ban.`id` IS NOT NULL THEN 2 ELSE 0 END)
        | (CASE WHEN spray_ban.`id` IS NOT NULL THEN 4 ELSE 0 END) AS `module_mask`,
        IFNULL(access_ban.`id`, 0) AS `access_ban_id`,
        IFNULL(comm_ban.`id`, 0) AS `comm_ban_id`,
        IFNULL(spray_ban.`id`, 0) AS `spray_ban_id`,
        IFNULL(comm_ban.`ban_type`, 0) AS `comm_type`
    FROM (
        SELECT `accountid`
        FROM `view_bansystem_access_bans_active`
        UNION
        SELECT `accountid`
        FROM `view_bansystem_comm_bans_active`
        UNION
        SELECT `accountid`
        FROM `view_bansystem_spray_bans_active`
    ) AS src
    LEFT JOIN `view_bansystem_access_bans_active` AS access_ban
        ON access_ban.`accountid` = src.`accountid`
    LEFT JOIN `view_bansystem_comm_bans_active` AS comm_ban
        ON comm_ban.`accountid` = src.`accountid`
    LEFT JOIN `view_bansystem_spray_bans_active` AS spray_ban
        ON spray_ban.`accountid` = src.`accountid`;
END $$

DROP PROCEDURE IF EXISTS `bansystem_get_auth_summary` $$
CREATE PROCEDURE `bansystem_get_auth_summary`(
    IN inAccountId INT
)
BEGIN
    IF EXISTS(SELECT 1 FROM `bansystem_summary` WHERE `accountid` = inAccountId LIMIT 1) THEN
        SELECT
            `module_mask`,
            `access_ban_id`,
            `comm_ban_id`,
            `spray_ban_id`,
            `comm_type`
        FROM `bansystem_summary`
        WHERE `accountid` = inAccountId
        LIMIT 1;
    ELSE
        CALL `bansystem_rebuild_summary_account`(inAccountId);

        SELECT
            `module_mask`,
            `access_ban_id`,
            `comm_ban_id`,
            `spray_ban_id`,
            `comm_type`
        FROM `bansystem_summary`
        WHERE `accountid` = inAccountId
        LIMIT 1;
    END IF;
END $$

INSERT INTO `bansystem_schema_meta` (`component`, `version_num`)
VALUES ('core', 1)
ON DUPLICATE KEY UPDATE `version_num` = VALUES(`version_num`) $$

DELIMITER ;

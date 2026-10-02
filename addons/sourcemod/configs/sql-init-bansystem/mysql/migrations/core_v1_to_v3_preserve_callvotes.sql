-- BanSystem Legacy core schema v1 -> v3, preserving production callvote columns.
-- Target tested server family: MariaDB 10.11. Requires ALTER, CREATE VIEW,
-- DROP, TRIGGER, SELECT on referenced objects, UPDATE, and CREATE TEMPORARY TABLES.
--
-- SAFETY:
-- 1. Take and verify a full database backup before running this script.
-- 2. Stop BanSystem plugins while applying it; snapshot checks require a quiet DB.
-- 3. Run only after reviewing SHOW CREATE for the target schema. This script
--    expects the observed callvote extension and the four module active views.
-- 4. Deploy only with a Core binary whose summary writes preserve unknown
--    module bits and callvote columns. The old Legacy UpsertPrimarySummary
--    replaces module_mask with 1/2/4 and can erase callvote bit 8.
-- 5. This script never drops/recreates tables or deletes/rewrites ban rows.
-- 6. DDL commits implicitly. Rollback means restoring the verified backup;
--    do not roll back by changing only the schema version.
-- 7. Requires CREATE TEMPORARY TABLES. A private session snapshot checks that
--    all pre-existing summary rows and callvote fields are unchanged pre-meta.
-- 8. Do not run the client with --force. Failed CHECK gates stop the script;
--    the metadata update also requires both successful gates.
--
-- The two core views use CURRENT_USER as definer. The summary triggers use the
-- creator's default definer. SQL SECURITY DEFINER remains enabled for views.
-- Callvote bit 8 and its summary fields remain intact.

SET SESSION check_constraint_checks = ON;
CREATE TEMPORARY TABLE `bs_core_v1_to_v3_gate` (
    `phase` varchar(8) NOT NULL,
    `valid` tinyint NOT NULL,
    PRIMARY KEY (`phase`),
    CONSTRAINT `chk_bs_core_v1_to_v3_gate` CHECK (`valid` = 1)
);

-- A failed CHECK aborts the default MariaDB client before any persistent DDL.
INSERT INTO `bs_core_v1_to_v3_gate` (`phase`, `valid`)
SELECT 'pre',
    IF(
        COALESCE((SELECT `version_num` FROM `bansystem_schema_meta` WHERE `component` = 'core' LIMIT 1), -1) IN (1, 3)
        AND (SELECT COUNT(*) FROM information_schema.tables
             WHERE `table_schema` = DATABASE() AND `table_name` IN (
                 'bansystem_summary', 'bansystem_access_bans', 'bansystem_comm_bans',
                 'bansystem_spray_bans', 'bansystem_callvote_bans',
                 'view_bansystem_access_bans_active', 'view_bansystem_comm_bans_active',
                 'view_bansystem_spray_bans_active', 'view_bansystem_callvote_bans_active',
                 'view_bansystem_auth_summary', 'view_bansystem_active_summary'
             )) = 11
        AND (SELECT COUNT(*) FROM information_schema.columns
             WHERE `table_schema` = DATABASE() AND `table_name` = 'bansystem_summary'
               AND `column_name` IN (
                   'accountid', 'module_mask', 'access_ban_id', 'comm_ban_id', 'spray_ban_id',
                   'callvote_ban_id', 'comm_type', 'comm_expire_ts', 'spray_expire_ts',
                   'callvote_restriction_mask', 'callvote_expire_ts'
               )) = 11
        AND (SELECT COUNT(*) FROM information_schema.triggers
             WHERE `trigger_schema` = DATABASE()
               AND `trigger_name` IN ('trg_bansystem_summary_before_insert', 'trg_bansystem_summary_before_update')) = 2
        AND (SELECT COUNT(*) FROM information_schema.views
             WHERE `table_schema` = DATABASE()
               AND `table_name` IN ('view_bansystem_auth_summary', 'view_bansystem_active_summary')) = 2,
        1, 0
    );

DROP TEMPORARY TABLE IF EXISTS `bs_core_v1_to_v3_summary_snapshot`;
CREATE TEMPORARY TABLE `bs_core_v1_to_v3_summary_snapshot` AS
SELECT `accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`,
       `callvote_ban_id`, `callvote_restriction_mask`, `callvote_expire_ts`, `updated_at`
FROM `bansystem_summary`;
SET @bs_core_v1_to_v3_summary_rows_before = (SELECT COUNT(*) FROM `bs_core_v1_to_v3_summary_snapshot`);

-- Pre-migration read-only baseline. Record these counts with the change ticket.
SELECT `component`, `version_num`
FROM `bansystem_schema_meta`
WHERE `component` = 'core';
SELECT @bs_core_v1_to_v3_summary_rows_before AS `summary_rows_before`;
SELECT 'access' AS `module`, COUNT(*) AS `active_bans` FROM `view_bansystem_access_bans_active`
UNION ALL SELECT 'comm', COUNT(*) FROM `view_bansystem_comm_bans_active`
UNION ALL SELECT 'sprays', COUNT(*) FROM `view_bansystem_spray_bans_active`
UNION ALL SELECT 'callvotes', COUNT(*) FROM `view_bansystem_callvote_bans_active`;

-- Add only fields required by Legacy core v3. Existing columns, indexes, rows,
-- and the callvote extension remain in place. IF NOT EXISTS makes retries safe.
ALTER TABLE `bansystem_summary`
    ADD COLUMN IF NOT EXISTS `comm_length` int NOT NULL DEFAULT 0 AFTER `comm_type`,
    ADD COLUMN IF NOT EXISTS `comm_reason` varchar(250) NOT NULL DEFAULT '' AFTER `comm_length`,
    ADD COLUMN IF NOT EXISTS `comm_context` varchar(512) NOT NULL DEFAULT '' AFTER `comm_reason`,
    ADD COLUMN IF NOT EXISTS `comm_banned_by_name` varchar(128) NOT NULL DEFAULT '' AFTER `comm_context`,
    ADD COLUMN IF NOT EXISTS `spray_length` int NOT NULL DEFAULT 0 AFTER `comm_expire_ts`,
    ADD COLUMN IF NOT EXISTS `spray_reason` varchar(250) NOT NULL DEFAULT '' AFTER `spray_length`,
    ADD COLUMN IF NOT EXISTS `spray_context` varchar(512) NOT NULL DEFAULT '' AFTER `spray_reason`,
    ADD COLUMN IF NOT EXISTS `spray_banned_by_name` varchar(128) NOT NULL DEFAULT '' AFTER `spray_context`;

-- Use the current SQL user as view definer; keep SQL SECURITY DEFINER enabled.
SELECT SUBSTRING_INDEX(`definer`, '@', 1), SUBSTRING_INDEX(`definer`, '@', -1)
INTO @bs_auth_definer_user, @bs_auth_definer_host
FROM information_schema.views
WHERE `table_schema` = DATABASE() AND `table_name` = 'view_bansystem_auth_summary';

SET @bs_auth_view_sql = CONCAT(
    'CREATE OR REPLACE ALGORITHM=UNDEFINED DEFINER=CURRENT_USER SQL SECURITY DEFINER VIEW `view_bansystem_auth_summary` AS ',
    'SELECT `accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, ',
    '`comm_type`, `comm_length`, `comm_reason`, `comm_context`, `comm_banned_by_name`, `comm_expire_ts`, ',
    '`spray_length`, `spray_reason`, `spray_context`, `spray_banned_by_name`, `spray_expire_ts`, ',
    '`callvote_ban_id`, `callvote_restriction_mask`, `callvote_expire_ts`, `updated_at` ',
    'FROM `bansystem_summary` WHERE `module_mask` <> 0'
);
PREPARE `bs_auth_view_stmt` FROM @bs_auth_view_sql;
EXECUTE `bs_auth_view_stmt`;
DEALLOCATE PREPARE `bs_auth_view_stmt`;

SELECT SUBSTRING_INDEX(`definer`, '@', 1), SUBSTRING_INDEX(`definer`, '@', -1)
INTO @bs_active_definer_user, @bs_active_definer_host
FROM information_schema.views
WHERE `table_schema` = DATABASE() AND `table_name` = 'view_bansystem_active_summary';

SET @bs_active_view_sql = CONCAT(
    'CREATE OR REPLACE ALGORITHM=UNDEFINED DEFINER=CURRENT_USER SQL SECURITY DEFINER VIEW `view_bansystem_active_summary` AS ',
    'SELECT src.`accountid`, ',
    '((IF(access_ban.`id` IS NOT NULL, 1, 0)) | (IF(comm_ban.`id` IS NOT NULL, 2, 0)) | ',
    '(IF(spray_ban.`id` IS NOT NULL, 4, 0)) | (IF(callvote_ban.`id` IS NOT NULL, 8, 0))) AS `module_mask`, ',
    'IFNULL(access_ban.`id`, 0) AS `access_ban_id`, IFNULL(comm_ban.`id`, 0) AS `comm_ban_id`, ',
    'IFNULL(spray_ban.`id`, 0) AS `spray_ban_id`, IFNULL(comm_ban.`ban_type`, 0) AS `comm_type`, ',
    'IFNULL(comm_ban.`ban_length`, 0) AS `comm_length`, IFNULL(comm_ban.`ban_reason`, \'\') AS `comm_reason`, ',
    'IFNULL(comm_ban.`ban_context`, \'\') AS `comm_context`, IFNULL(comm_ban.`banned_by_name`, \'\') AS `comm_banned_by_name`, ',
    'IFNULL(comm_ban.`date_expire_ts`, 0) AS `comm_expire_ts`, IFNULL(spray_ban.`ban_length`, 0) AS `spray_length`, ',
    'IFNULL(spray_ban.`ban_reason`, \'\') AS `spray_reason`, IFNULL(spray_ban.`ban_context`, \'\') AS `spray_context`, ',
    'IFNULL(spray_ban.`banned_by_name`, \'\') AS `spray_banned_by_name`, IFNULL(spray_ban.`date_expire_ts`, 0) AS `spray_expire_ts`, ',
    'IFNULL(callvote_ban.`id`, 0) AS `callvote_ban_id`, IFNULL(callvote_ban.`restriction_mask`, 0) AS `callvote_restriction_mask`, ',
    'IFNULL(callvote_ban.`date_expire_ts`, 0) AS `callvote_expire_ts` ',
    'FROM (SELECT `accountid` FROM `view_bansystem_access_bans_active` ',
    'UNION SELECT `accountid` FROM `view_bansystem_comm_bans_active` ',
    'UNION SELECT `accountid` FROM `view_bansystem_spray_bans_active` ',
    'UNION SELECT `accountid` FROM `view_bansystem_callvote_bans_active`) AS src ',
    'LEFT JOIN `view_bansystem_access_bans_active` AS access_ban ON access_ban.`accountid` = src.`accountid` ',
    'LEFT JOIN `view_bansystem_comm_bans_active` AS comm_ban ON comm_ban.`accountid` = src.`accountid` ',
    'LEFT JOIN `view_bansystem_spray_bans_active` AS spray_ban ON spray_ban.`accountid` = src.`accountid` ',
    'LEFT JOIN `view_bansystem_callvote_bans_active` AS callvote_ban ON callvote_ban.`accountid` = src.`accountid`'
);
PREPARE `bs_active_view_stmt` FROM @bs_active_view_sql;
EXECUTE `bs_active_view_stmt`;
DEALLOCATE PREPARE `bs_active_view_stmt`;

-- Read existing trigger metadata; replacement triggers use the creator's default definer.
SELECT SUBSTRING_INDEX(`definer`, '@', 1), SUBSTRING_INDEX(`definer`, '@', -1)
INTO @bs_summary_insert_definer_user, @bs_summary_insert_definer_host
FROM information_schema.triggers
WHERE `trigger_schema` = DATABASE() AND `trigger_name` = 'trg_bansystem_summary_before_insert';
SELECT SUBSTRING_INDEX(`definer`, '@', 1), SUBSTRING_INDEX(`definer`, '@', -1)
INTO @bs_summary_update_definer_user, @bs_summary_update_definer_host
FROM information_schema.triggers
WHERE `trigger_schema` = DATABASE() AND `trigger_name` = 'trg_bansystem_summary_before_update';

DROP TRIGGER `trg_bansystem_summary_before_insert`;
DROP TRIGGER `trg_bansystem_summary_before_update`;

SET @bs_insert_trigger_sql = CONCAT(
    'CREATE TRIGGER `trg_bansystem_summary_before_insert` BEFORE INSERT ON `bansystem_summary` FOR EACH ROW BEGIN ',
    'IF (NEW.`module_mask` & 1) = 0 THEN SET NEW.`access_ban_id` = 0; END IF; ',
    'IF (NEW.`module_mask` & 2) = 0 THEN SET NEW.`comm_ban_id` = 0; SET NEW.`comm_type` = 0; ',
    'SET NEW.`comm_length` = 0; SET NEW.`comm_reason` = \'\'; SET NEW.`comm_context` = \'\'; ',
    'SET NEW.`comm_banned_by_name` = \'\'; SET NEW.`comm_expire_ts` = 0; END IF; ',
    'IF (NEW.`module_mask` & 4) = 0 THEN SET NEW.`spray_ban_id` = 0; SET NEW.`spray_length` = 0; ',
    'SET NEW.`spray_reason` = \'\'; SET NEW.`spray_context` = \'\'; SET NEW.`spray_banned_by_name` = \'\'; ',
    'SET NEW.`spray_expire_ts` = 0; END IF; ',
    'IF (NEW.`module_mask` & 8) = 0 THEN SET NEW.`callvote_ban_id` = 0; ',
    'SET NEW.`callvote_restriction_mask` = 0; SET NEW.`callvote_expire_ts` = 0; END IF; END'
);
PREPARE `bs_insert_trigger_stmt` FROM @bs_insert_trigger_sql;
EXECUTE `bs_insert_trigger_stmt`;
DEALLOCATE PREPARE `bs_insert_trigger_stmt`;

SET @bs_update_trigger_sql = REPLACE(
    @bs_insert_trigger_sql,
    'BEFORE INSERT ON',
    'BEFORE UPDATE ON'
);
SET @bs_update_trigger_sql = REPLACE(
    @bs_update_trigger_sql,
    '`trg_bansystem_summary_before_insert`',
    '`trg_bansystem_summary_before_update`'
);
SET @bs_update_trigger_sql = REPLACE(
    @bs_update_trigger_sql,
    CONCAT(QUOTE(@bs_summary_insert_definer_user), '@', QUOTE(@bs_summary_insert_definer_host)),
    CONCAT(QUOTE(@bs_summary_update_definer_user), '@', QUOTE(@bs_summary_update_definer_host))
);
PREPARE `bs_update_trigger_stmt` FROM @bs_update_trigger_sql;
EXECUTE `bs_update_trigger_stmt`;
DEALLOCATE PREPARE `bs_update_trigger_stmt`;

-- Verify the runtime contract and callvote extension before changing metadata.
SELECT `accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`,
       `comm_length`, `comm_reason`, `comm_context`, `comm_banned_by_name`, `comm_expire_ts`,
       `spray_length`, `spray_reason`, `spray_context`, `spray_banned_by_name`, `spray_expire_ts`,
       `callvote_ban_id`, `callvote_restriction_mask`, `callvote_expire_ts`, `updated_at`
FROM `view_bansystem_auth_summary` LIMIT 0;
SELECT `accountid`, `module_mask`, `access_ban_id`, `comm_ban_id`, `spray_ban_id`, `comm_type`,
       `comm_length`, `comm_reason`, `comm_context`, `comm_banned_by_name`, `comm_expire_ts`,
       `spray_length`, `spray_reason`, `spray_context`, `spray_banned_by_name`, `spray_expire_ts`,
       `callvote_ban_id`, `callvote_restriction_mask`, `callvote_expire_ts`
FROM `view_bansystem_active_summary` LIMIT 0;

-- A CHECK violation aborts before the metadata update and leaves no routine.
INSERT INTO `bs_core_v1_to_v3_gate` (`phase`, `valid`)
SELECT 'post',
    IF(
        EXISTS (SELECT 1 FROM `bs_core_v1_to_v3_gate` WHERE `phase` = 'pre' AND `valid` = 1)
        AND (SELECT COUNT(*) FROM information_schema.columns
             WHERE `table_schema` = DATABASE() AND `table_name` = 'bansystem_summary'
               AND `column_name` IN (
                   'comm_length', 'comm_reason', 'comm_context', 'comm_banned_by_name',
                   'spray_length', 'spray_reason', 'spray_context', 'spray_banned_by_name',
                   'callvote_ban_id', 'callvote_restriction_mask', 'callvote_expire_ts'
               )) = 11
        AND (SELECT COUNT(*) FROM information_schema.columns
             WHERE `table_schema` = DATABASE() AND `table_name` = 'view_bansystem_auth_summary'
               AND `column_name` IN (
                   'comm_length', 'comm_reason', 'comm_context', 'comm_banned_by_name',
                   'spray_length', 'spray_reason', 'spray_context', 'spray_banned_by_name',
                   'callvote_ban_id', 'callvote_restriction_mask', 'callvote_expire_ts'
               )) = 11
        AND (SELECT COUNT(*) FROM information_schema.columns
             WHERE `table_schema` = DATABASE() AND `table_name` = 'view_bansystem_active_summary'
               AND `column_name` IN (
                   'comm_length', 'comm_reason', 'comm_context', 'comm_banned_by_name',
                   'spray_length', 'spray_reason', 'spray_context', 'spray_banned_by_name',
                   'callvote_ban_id', 'callvote_restriction_mask', 'callvote_expire_ts'
               )) = 11
        AND (SELECT COUNT(*) FROM information_schema.triggers
             WHERE `trigger_schema` = DATABASE()
               AND `trigger_name` IN ('trg_bansystem_summary_before_insert', 'trg_bansystem_summary_before_update')) = 2
        AND (SELECT COUNT(*) FROM information_schema.views
             WHERE `table_schema` = DATABASE() AND `table_name` = 'view_bansystem_callvote_bans_active') = 1
        AND @bs_core_v1_to_v3_summary_rows_before = (SELECT COUNT(*) FROM `bansystem_summary`)
        AND @bs_core_v1_to_v3_summary_rows_before = (
            SELECT COUNT(*)
            FROM `bs_core_v1_to_v3_summary_snapshot` AS before_migration
            INNER JOIN `bansystem_summary` AS after_migration
                ON after_migration.`accountid` = before_migration.`accountid`
        )
        AND (SELECT COUNT(*)
             FROM `bs_core_v1_to_v3_summary_snapshot` AS before_migration
             INNER JOIN `bansystem_summary` AS after_migration
                 ON after_migration.`accountid` = before_migration.`accountid`
             WHERE NOT (after_migration.`module_mask` <=> before_migration.`module_mask`)
                OR NOT (after_migration.`access_ban_id` <=> before_migration.`access_ban_id`)
                OR NOT (after_migration.`comm_ban_id` <=> before_migration.`comm_ban_id`)
                OR NOT (after_migration.`spray_ban_id` <=> before_migration.`spray_ban_id`)
                OR NOT (after_migration.`callvote_ban_id` <=> before_migration.`callvote_ban_id`)
                OR NOT (after_migration.`callvote_restriction_mask` <=> before_migration.`callvote_restriction_mask`)
                OR NOT (after_migration.`callvote_expire_ts` <=> before_migration.`callvote_expire_ts`)
                OR NOT (after_migration.`updated_at` <=> before_migration.`updated_at`)
        ) = 0,
        1, 0
    );

-- The version changes only when both gates passed. This remains true even if a
-- caller mistakenly configures its SQL client to continue after errors.
UPDATE `bansystem_schema_meta`
SET `version_num` = 3
WHERE `component` = 'core' AND `version_num` IN (1, 3)
  AND EXISTS (SELECT 1 FROM `bs_core_v1_to_v3_gate` WHERE `phase` = 'pre' AND `valid` = 1)
  AND EXISTS (SELECT 1 FROM `bs_core_v1_to_v3_gate` WHERE `phase` = 'post' AND `valid` = 1);

INSERT INTO `bs_core_v1_to_v3_gate` (`phase`, `valid`)
SELECT 'meta', IF(COALESCE((SELECT `version_num` FROM `bansystem_schema_meta` WHERE `component` = 'core' LIMIT 1), -1) = 3, 1, 0);

SELECT @bs_core_v1_to_v3_summary_rows_before AS `summary_rows_before`,
       COUNT(*) AS `summary_rows_after`, 0 AS `changed_preserved_fields`
FROM `bansystem_summary`;

DROP TEMPORARY TABLE `bs_core_v1_to_v3_summary_snapshot`;
DROP TEMPORARY TABLE `bs_core_v1_to_v3_gate`;

-- Post-migration read-only verification.
SELECT `component`, `version_num`
FROM `bansystem_schema_meta`
WHERE `component` = 'core';
SELECT COUNT(*) AS `summary_rows_after` FROM `bansystem_summary`;
SELECT 'access' AS `module`, COUNT(*) AS `active_bans` FROM `view_bansystem_access_bans_active`
UNION ALL SELECT 'comm', COUNT(*) FROM `view_bansystem_comm_bans_active`
UNION ALL SELECT 'sprays', COUNT(*) FROM `view_bansystem_spray_bans_active`
UNION ALL SELECT 'callvotes', COUNT(*) FROM `view_bansystem_callvote_bans_active`;
SELECT `module_mask`, COUNT(*) AS `summary_rows`
FROM `bansystem_summary`
GROUP BY `module_mask`
ORDER BY `module_mask`;
